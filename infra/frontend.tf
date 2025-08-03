# Frontend EC2 Infrastructure

# Data source to get the latest Amazon Linux 2023 AMI
#data "aws_ami" "amazon_linux_2023" {
#  most_recent = true
#  owners      = ["amazon"]
#
#  filter {
#    name   = "name"
#    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
#  }
#
#  #filter {
#  #  name   = "virtualization-type"
#  #  values = ["hvm"]
#  #}
#}

# Security Group for Frontend EC2 Instance
resource "aws_security_group" "frontend" {
  name        = "${var.project_name}-frontend-sg-${var.environment}"
  description = "Security group for frontend EC2 instance"
  vpc_id      = module.vpc.vpc_id

  # Inbound rule: Allow traffic on port 5000 from anywhere (for admin access)
  ingress {
    description = "Allow admin access on port 5000"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound rule: Allow traffic on port 22 from anywhere (for admin troubleshoot)
  ingress {
    description = "Allow admin access on port 22"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rule: Allow HTTPS traffic to AWS services
  egress {
    description = "Allow HTTPS to AWS services"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rule: Allow HTTP for package installations
  egress {
    description = "Allow HTTP for package installations"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-frontend-sg-${var.environment}"
  })
}

# Key Pair for EC2 access
# 1. Generate a new private key using tls_private_key
resource "tls_private_key" "mlops_key_front" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# 2. Create the AWS Key Pair using the public key from tls_private_key
resource "aws_key_pair" "mlops_key_front" {
  key_name   = "mlops_key_front"
  public_key = tls_private_key.mlops_key_front.public_key_openssh
  tags       = var.tags
}

# 3. Store the generated private key in a local file
resource "local_file" "mlops_key_front_private" {
  content  = tls_private_key.mlops_key_front.private_key_pem
  filename = "${path.module}/ssh/mlops_key_front.pem"
  # Make sure the permissions are set correctly for SSH
  file_permission = "0600"
}

# IAM Role for EC2 Instance
resource "aws_iam_role" "frontend_ec2" {
  name = "${var.project_name}-frontend-ec2-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Instance Profile for EC2
resource "aws_iam_instance_profile" "frontend" {
  name = "${var.project_name}-frontend-instance-profile-${var.environment}"
  role = aws_iam_role.frontend_ec2.name
}

# IAM Policy for Frontend EC2 to access necessary AWS services
resource "aws_iam_policy" "frontend_ec2_policy" {
  name        = "${var.project_name}-frontend-ec2-policy-${var.environment}"
  description = "IAM policy for frontend EC2 instance"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.mlflow_artifacts.arn,
          "${aws_s3_bucket.mlflow_artifacts.arn}/*",
          aws_s3_bucket.data_storage.arn,
          "${aws_s3_bucket.data_storage.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "frontend_ec2_policy" {
  role       = aws_iam_role.frontend_ec2.name
  policy_arn = aws_iam_policy.frontend_ec2_policy.arn
}

# Attach SSM policy for Session Manager access (optional but recommended)
resource "aws_iam_role_policy_attachment" "frontend_ssm" {
  role       = aws_iam_role.frontend_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# EC2 Instance for Frontend
resource "aws_instance" "frontend" {
  ami                    = "ami-0b6acaa45fec15278" #data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = module.vpc.public_subnet_ids[0] # Using first public subnet
  key_name               = aws_key_pair.mlops_key_front.key_name
  vpc_security_group_ids = [aws_security_group.frontend.id]
  iam_instance_profile   = aws_iam_instance_profile.frontend.name


  # Enable detailed monitoring for cost optimization insights
  monitoring = false # Set to false for cost efficiency

  # Use gp3 for better cost efficiency
  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    encrypted   = true

    tags = merge(var.tags, {
      Name = "${var.project_name}-frontend-root-volume-${var.environment}"
    })
  }

  user_data = templatefile("${path.module}/templates/ec2_setup.sh", {
    project_name = var.project_name
    environment  = var.environment
    region       = var.aws_region
  })

  # Provisioner to create folders and set permissions
  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /opt/mlops",
      "sudo chown -R ec2-user:ec2-user /opt/mlops",
      "cd /opt/mlops"
    ]
  }

  # Provisioner to copy the entire app directory
  provisioner "file" {
    source      = "${path.module}/../frontend/" # Copy the contents of the local 'frontend' directory
    destination = "/opt/mlops"                  # To the remote directory
  }

  # Provisioner to run docker after files are copied
  provisioner "remote-exec" {
    inline = [
      "cd /opt/mlops",
      "/usr/local/bin/docker build -t mlops-frontend .",
      "/usr/local/bin/docker run -d --restart=always -p 5000:5000 --name mlops-frontend mlops-frontend",
      "sudo cp /opt/mlops/mlops-docker-frontend.service /etc/systemd/system/mlops-docker-frontend.service",
      "sudo systemctl enable mlops-docker-frontend.service",
      "nohup python3 -m http.server 8081 --directory /opt/mlops > /dev/null 2>&1 &"
    ]
  }

  # Connection block tells Terraform how to SSH into the instance
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file(local_file.mlops_key_front_private.filename)
    host        = self.public_ip
  }


  tags = merge(var.tags, {
    Name = "${var.project_name}-frontend-${var.environment}"
    Type = "Frontend"
  })
}

# ALB resources removed - using direct EC2 access for simplified architecture

# Output the frontend instance details
output "frontend_instance_id" {
  description = "ID of the frontend EC2 instance"
  value       = aws_instance.frontend.id
}

output "frontend_instance_public_ip" {
  description = "Public IP of the frontend EC2 instance"
  value       = aws_instance.frontend.public_ip
}

output "frontend_instance_public_dns" {
  description = "Public DNS of the frontend EC2 instance"
  value       = aws_instance.frontend.public_dns
}

output "frontend_direct_url" {
  description = "Direct URL to access the frontend"
  value       = "http://${aws_instance.frontend.public_ip}:5000"
}
