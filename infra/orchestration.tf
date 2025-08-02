# EC2 Instance for MLOps Orchestration Services (Airflow + MLflow)

# Key Pair for EC2 access
# 1. Generate a new private key using tls_private_key
resource "tls_private_key" "mlops_key_orch" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# 2. Create the AWS Key Pair using the public key from tls_private_key
resource "aws_key_pair" "mlops_key_orch" {
  key_name   = "mlops_key_orch"
  public_key = tls_private_key.mlops_key_orch.public_key_openssh
  tags       = var.tags
}

# 3. Store the generated private key in a local file
resource "local_file" "mlops_key_orch_private" {
  content  = tls_private_key.mlops_key_orch.private_key_pem
  filename = "${path.module}/ssh/mlops_key_orch.pem"
  # Make sure the permissions are set correctly for SSH
  file_permission = "0600"
}

resource "aws_instance" "mlops_orchestration" {
  ami                    = "ami-0b6acaa45fec15278" #data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.large"              #t3.large or xlarge probably needed
  key_name               = aws_key_pair.mlops_key_orch.key_name
  vpc_security_group_ids = [module.security_groups.ec2_security_group_id]
  subnet_id              = module.vpc.public_subnet_ids[0]

  iam_instance_profile = aws_iam_instance_profile.mlops_profile.name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("${path.module}/templates/orch_setup.sh", {
    project_name = var.project_name
    environment  = var.environment
    region       = var.aws_region
  })

  # Provisioner to create folders and set permissions
  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /opt/mlops",
      "sudo chown -R ec2-user:ec2-user /opt/mlops",
      "cd /opt/mlops",
      "mkdir -p ./dags ./logs ./plugins ./config",
      "echo -e \"AIRFLOW_UID=$(id -u)\" > .env"
    ]
  }

  # Provisioner to copy the entire app directory
  provisioner "file" {
    source      = "${path.module}/../orchestration/" # Copy the contents of the local 'orchestration' directory
    destination = "/opt/mlops"                       # To the remote directory
  }


  tags = merge(var.tags, {
    Name = "${var.project_name}-mlops-orchestration-${var.environment}"
  })

  # Provisioner to run docker-compose and status page after files are copied
  provisioner "remote-exec" {
    inline = [
      "cd /opt/mlops",
      "/usr/local/bin/docker-compose up airflow-init",
      "/usr/local/bin/docker-compose up -d",
      "sudo cp /opt/mlops/mlops-docker-compose.service /etc/systemd/system/mlops-docker-compose.service",
      "sudo systemctl enable mlops-docker-compose.service",
      "nohup python3 -m http.server 8081 --directory /opt/mlops > /dev/null 2>&1 &"
    ]
  }
  # Connection block tells Terraform how to SSH into the instance
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file(local_file.mlops_key_orch_private.filename)
    host        = self.public_ip
  }
}



output "instance_public_ip" {
  value       = aws_instance.mlops_orchestration.public_ip
  description = "Public IP address of the EC2 instance."
}

# IAM Role for EC2
resource "aws_iam_role" "mlops_ec2_role" {
  name = "${var.project_name}-mlops-ec2-role-${var.environment}"

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

# IAM Policy for EC2
resource "aws_iam_policy" "mlops_ec2_policy" {
  name = "${var.project_name}-mlops-ec2-policy-${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.mlflow_artifacts.arn,
          "${aws_s3_bucket.mlflow_artifacts.arn}/*",
          aws_s3_bucket.data_storage.arn,
          "${aws_s3_bucket.data_storage.arn}/*",
          aws_s3_bucket.monitoring_reports.arn,
          "${aws_s3_bucket.monitoring_reports.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kinesis:PutRecord",
          "kinesis:PutRecords"
        ]
        Resource = aws_kinesis_stream.taxi_predictions.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:*"
      }
    ]
  })

  tags = var.tags
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "mlops_profile" {
  name = "${var.project_name}-mlops-profile-${var.environment}"
  role = aws_iam_role.mlops_ec2_role.name

  tags = var.tags
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "mlops_ec2_policy_attachment" {
  role       = aws_iam_role.mlops_ec2_role.name
  policy_arn = aws_iam_policy.mlops_ec2_policy.arn
}

# Data source for Amazon Linux 2023 AMI is defined in frontend.tf