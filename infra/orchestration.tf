# EC2 Instance for MLOps Orchestration Services (Airflow + MLflow)

# EC2 Instance for MLOps Orchestration Services (Airflow + MLflow)
resource "aws_instance" "mlops_orchestration" {
  ami                    = "ami-0b6acaa45fec15278" #data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.large"              #t3.large or xlarge probably needed
  key_name               = aws_key_pair.main_key.key_name
  vpc_security_group_ids = [aws_security_group.main.id]
  subnet_id              = module.vpc.public_subnet_ids[0]

  iam_instance_profile = aws_iam_instance_profile.main_instance_profile.name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
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
      "cd /opt/mlops",
      "mkdir -p ./dags ./logs ./plugins ./config",
      "echo -e \"AIRFLOW_UID=$(id -u)\" > .env"
    ]
  }

  #On Linux, the quick-start needs to know your host user id and needs to have group id set to 0. 
  #Otherwise the files created in dags, logs, config and plugins will be created with root user ownership. 
  #You have to make sure to configure them for the docker-compose:
  #mkdir -p ./dags ./logs ./plugins ./config
  #echo -e "AIRFLOW_UID=$(id -u)" > .env


  # Provisioner to copy the entire app directory
  provisioner "file" {
    source      = "${path.module}/../orchestration/" # Copy the contents of the local 'orchestration' directory
    destination = "/opt/mlops"                       # To the remote directory
  }

  # Provisioner to run docker-compose and status page
  provisioner "remote-exec" {
    inline = [
      "cd /opt/mlops",
      "sudo /usr/local/bin/docker-compose up airflow-init",
      "sudo /usr/local/bin/docker-compose up -d",
      "sudo cp /opt/mlops/mlops-docker-compose.service /etc/systemd/system/mlops-docker-compose.service",
      "sudo systemctl enable mlops-docker-compose.service",
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
    Name = "${var.project_name}-mlops-orchestration-${var.environment}"
  })
}



# Output the orchestration instance details
output "orchestration_instance_id" {
  description = "ID of the orchestration EC2 instance"
  value       = aws_instance.mlops_orchestration.id
}

output "orchestration_instance_public_ip" {
  value       = aws_instance.mlops_orchestration.public_ip
  description = "Public IP address of the orchestration EC2 instance."
}

output "mlflow_direct_url" {
  description = "Direct URL to access the mlflow UI"
  value       = "http://${aws_instance.mlops_orchestration.public_ip}:5000"
}

output "airflow_direct_url" {
  description = "Direct URL to access the Airflow UI"
  value       = "http://${aws_instance.mlops_orchestration.public_ip}:8080"
}
