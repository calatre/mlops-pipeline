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

# RDS Security Group
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-rds-${var.environment}-"
  vpc_id      = var.vpc_id
  description = "Security group for RDS database"

  # PostgreSQL access from ECS only
  ingress {
    description     = "PostgreSQL access from ECS"
    from_port       = var.postgres_port
    to_port         = var.postgres_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  # Optional: Database access from specific CIDR blocks (for management)
  dynamic "ingress" {
    for_each = var.db_admin_access_cidrs
    content {
      description = "Database admin access from ${ingress.value}"
      from_port   = var.postgres_port
      to_port     = var.postgres_port
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  # Outbound access (for updates and patches)
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-rds-sg-${var.environment}"
    Type = "Database"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# EFS Security Group
resource "aws_security_group" "efs" {
  name_prefix = "${var.project_name}-efs-${var.environment}-"
  vpc_id      = var.vpc_id
  description = "Security group for EFS file system"

  # NFS access from ECS
  ingress {
    description     = "NFS access from ECS"
    from_port       = var.nfs_port
    to_port         = var.nfs_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  # Optional: NFS access from specific CIDR blocks
  dynamic "ingress" {
    for_each = var.efs_admin_access_cidrs
    content {
      description = "NFS admin access from ${ingress.value}"
      from_port   = var.nfs_port
      to_port     = var.nfs_port
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
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
    Name = "${var.project_name}-efs-sg-${var.environment}"
    Type = "Storage"
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

# Redis/ElastiCache Security Group (optional)
resource "aws_security_group" "redis" {
  count = var.create_redis_sg ? 1 : 0

  name_prefix = "${var.project_name}-redis-${var.environment}-"
  vpc_id      = var.vpc_id
  description = "Security group for Redis/ElastiCache"

  # Redis access from ECS
  ingress {
    description     = "Redis access from ECS"
    from_port       = var.redis_port
    to_port         = var.redis_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
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
    Name = "${var.project_name}-redis-sg-${var.environment}"
    Type = "Cache"
  })

  lifecycle {
    create_before_destroy = true
  }
}
