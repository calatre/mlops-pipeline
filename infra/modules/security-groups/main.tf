# Security Groups Module for MLOps Taxi Prediction Infrastructure
# This module creates security groups with least-privilege access patterns

# ALB Security Group
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-${var.environment}-"
  vpc_id      = var.vpc_id
  description = "Security group for Application Load Balancer"

  # HTTP access from anywhere
  ingress {
    description = "HTTP access from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.alb_allowed_cidrs
  }

  # HTTPS access from anywhere
  ingress {
    description = "HTTPS access from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.alb_allowed_cidrs
  }

  # Custom port access (optional)
  dynamic "ingress" {
    for_each = var.alb_custom_ports
    content {
      description = "Custom port ${ingress.value.port} access"
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
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
    Name = "${var.project_name}-alb-sg-${var.environment}"
    Type = "ALB"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ECS Security Group
resource "aws_security_group" "ecs" {
  count       = var.create_ecs_sg ? 1 : 0
  name_prefix = "${var.project_name}-ecs-${var.environment}-"
  vpc_id      = var.vpc_id
  description = "Security group for ECS tasks"

  # Airflow web UI access from ALB
  ingress {
    description     = "Airflow web UI from ALB"
    from_port       = var.airflow_port
    to_port         = var.airflow_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Allow intra-service communication between ECS tasks
  ingress {
    description = "All traffic from same security group"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  # MLflow UI access from ALB
  ingress {
    description     = "MLflow UI from ALB"
    from_port       = var.mlflow_port
    to_port         = var.mlflow_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Custom application ports
  dynamic "ingress" {
    for_each = var.ecs_custom_ports
    content {
      description     = "Custom port ${ingress.value.port} from ALB"
      from_port       = ingress.value.port
      to_port         = ingress.value.port
      protocol        = ingress.value.protocol
      security_groups = [aws_security_group.alb.id]
    }
  }

  # Allow ECS tasks to communicate with each other
  ingress {
    description = "Inter-ECS communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  # SSH access (optional, for debugging)
  dynamic "ingress" {
    for_each = var.enable_ssh_access ? [1] : []
    content {
      description = "SSH access for debugging"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_allowed_cidrs
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
    Name = "${var.project_name}-ecs-sg-${var.environment}"
    Type = "ECS"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# RDS Security Group - Removed (RDS no longer used in simplified architecture)

# EFS Security Group - Removed (EFS no longer used in simplified architecture)

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

# Redis/ElastiCache Security Group - Removed (Redis no longer used in simplified architecture)
