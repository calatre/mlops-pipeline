# Security Groups Module for MLOps Taxi Prediction Infrastructure
# This module creates security groups with least-privilege access patterns

# EC2 Security Group
resource "aws_security_group" "ec2" {
  count       = var.create_ec2_sg ? 1 : 0
  name_prefix = "${var.project_name}-ec2-${var.environment}-"
  vpc_id      = var.vpc_id
  description = "Security group for EC2 instance"

  # SSH access (if enabled)
  dynamic "ingress" {
    for_each = var.enable_ssh_access ? [1] : []
    content {
      description = "SSH access"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_allowed_cidrs
    }
  }

  # Airflow web UI access
  ingress {
    description = "Airflow web UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # MLflow UI access
  ingress {
    description = "MLflow UI"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Status page access
  ingress {
    description = "Status page"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # PostgreSQL access (for internal communication)
  ingress {
    description = "PostgreSQL"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Redis access (for internal communication)
  ingress {
    description = "Redis"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Custom application ports
  dynamic "ingress" {
    for_each = var.ec2_custom_ports
    content {
      description = "Custom port ${ingress.value.port} access"
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # Outbound access to anywhere
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-ec2-sg-${var.environment}"
    Type = "EC2"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Lambda Security Group (optional, for VPC-enabled Lambda functions)
resource "aws_security_group" "lambda" {
  count = var.create_lambda_sg ? 1 : 0

  name_prefix = "${var.project_name}-lambda-${var.environment}-"
  vpc_id      = var.vpc_id
  description = "Security group for Lambda functions"

  # Outbound access to anywhere (Lambda needs internet access)
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-lambda-sg-${var.environment}"
    Type = "Lambda"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# VPC Endpoints Security Group (optional)
resource "aws_security_group" "vpc_endpoints" {
  count = var.create_vpc_endpoints_sg ? 1 : 0

  name_prefix = "${var.project_name}-vpc-endpoints-${var.environment}-"
  vpc_id      = var.vpc_id
  description = "Security group for VPC endpoints"

  # HTTPS access from VPC CIDR
  ingress {
    description = "HTTPS access from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Outbound access
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-vpc-endpoints-sg-${var.environment}"
    Type = "VPC-Endpoints"
  })

  lifecycle {
    create_before_destroy = true
  }
}
