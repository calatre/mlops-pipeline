# Frontend EC2 Infrastructure

# EC2 Instance for Frontend
resource "aws_instance" "frontend" {
  ami                    = "ami-0b6acaa45fec15278" #data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = module.vpc.public_subnet_ids[0] # Using first public subnet
  key_name               = aws_key_pair.main_key.key_name
  vpc_security_group_ids = [aws_security_group.main.id]
  iam_instance_profile   = aws_iam_instance_profile.main_instance_profile.name

  # Ensure orchestration instance is created first
  depends_on = [aws_instance.mlops_orchestration]


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

  # Provisioner to create .env file with orchestration outputs
  # This demonstrates passing orchestration outputs as variables to frontend
  provisioner "remote-exec" {
    inline = [
      "cd /opt/mlops",
      # Pass orchestration outputs as environment variables
      "echo 'ORCHESTRATION_IP=${aws_instance.mlops_orchestration.public_ip}' >> .env",
      "echo 'MLFLOW_URL=http://${aws_instance.mlops_orchestration.public_ip}:5000' >> .env",
      "echo 'AIRFLOW_URL=http://${aws_instance.mlops_orchestration.public_ip}:8080' >> .env",
      "echo 'PROJECT_NAME=${var.project_name}' >> .env",
      "echo 'ENVIRONMENT=${var.environment}' >> .env",
      "echo 'AWS_DEFAULT_REGION=${var.aws_region}' >> .env",
      # Pass S3 bucket names from main configuration
      "echo 'MLFLOW_ARTIFACTS_BUCKET=${aws_s3_bucket.mlflow_artifacts.bucket}' >> .env",
      "echo 'DATA_STORAGE_BUCKET=${aws_s3_bucket.data_storage.bucket}' >> .env"
    ]
  }

  # Provisioner to run docker after files are copied with readiness check
  provisioner "remote-exec" {
    inline = [
      "cd /opt/mlops",
      "# ==========================================================================================",
      "# DOCKER READINESS CHECK: Dynamic waiting with intelligent retry logic",
      "# This replaces static sleep commands with active Docker daemon status checking",
      "# Benefits: Eliminates race conditions, handles varying startup times, provides clear logging",
      "# ==========================================================================================",
      "MAX_ATTEMPTS=30    # Maximum retry attempts (prevents infinite loops)",
      "ATTEMPT=0          # Current attempt counter",
      "# Polling loop: Uses 'docker info' to actively check Docker daemon status",
      "# This is more reliable than fixed sleep delays which don't account for actual readiness",
      "while ! sudo docker info >/dev/null 2>&1; do",
      "  ATTEMPT=$((ATTEMPT+1))",
      "  # Fail-safe: Exit with error if maximum attempts reached",
      "  if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then",
      "    echo 'ERROR: Docker daemon failed to start after $MAX_ATTEMPTS attempts'",
      "    exit 1",
      "  fi",
      "  # Progress logging: Shows current attempt for monitoring/debugging",
      "  echo 'Waiting for Docker daemon... (attempt $ATTEMPT/$MAX_ATTEMPTS)'",
      "  # Fixed 2-second delay (simpler than exponential backoff for this use case)",
      "  sleep 2",
      "done",
      "echo 'SUCCESS: Docker daemon is ready - proceeding with container build'",
      "# ==========================================================================================",
      "# DOCKER BUILD: Now that daemon is confirmed ready, build the application container",
      "# ==========================================================================================",
      "sudo /usr/bin/docker build -t mlops-frontend .",
      #"docker run -d --restart=always -p 5000:5000 --name mlops-frontend mlops-frontend",
      "# Install and start systemd service for container management",
      "sudo cp /opt/mlops/mlops-docker-frontend.service /etc/systemd/system/mlops-docker-frontend.service",
      "sudo systemctl enable mlops-docker-frontend.service",
      "sudo systemctl start mlops-docker-frontend.service",
      "# Start file server for debugging/monitoring (port 8081)",
      "nohup python3 -m http.server 8081 --directory /opt/mlops > /dev/null 2>&1 &"
    ]
  }

  # Connection block tells Terraform how to SSH into the instance
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = tls_private_key.main_key.private_key_pem
    host        = self.public_ip
  }


  tags = merge(var.tags, {
    Name = "${var.project_name}-frontend-${var.environment}"
    Type = "Frontend"
  })
}

# Output the frontend instance details
output "frontend_instance_id" {
  description = "ID of the frontend EC2 instance"
  value       = aws_instance.frontend.id
}

output "frontend_instance_public_ip" {
  description = "Public IP of the frontend EC2 instance"
  value       = aws_instance.frontend.public_ip
}

output "frontend_direct_url" {
  description = "Direct URL to access the frontend"
  value       = "http://${aws_instance.frontend.public_ip}:5000"
}

# Output orchestration information for reference
output "orchestration_ips_available" {
  description = "Available orchestration IPs for reference"
  value       = [aws_instance.mlops_orchestration.public_ip]
}

output "lambda_role_arn_available" {
  description = "Available Lambda role ARN for reference"
  value       = aws_iam_role.lambda_role.arn
}

output "kinesis_stream_available" {
  description = "Available Kinesis stream information"
  value = {
    name = aws_kinesis_stream.taxi_predictions.name
    arn  = aws_kinesis_stream.taxi_predictions.arn
  }
}
