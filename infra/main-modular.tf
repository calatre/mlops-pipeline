# MLOps Taxi Prediction Infrastructure - Simplified EC2-based Configuration
# This version uses a single EC2 instance with Docker Compose for simplicity

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket         = "mlops-taxi-prediction-terraform-state"
    key            = "terraform.tfstate"
    region         = "eu-north-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"
  
  project_name            = var.project_name
  environment            = var.environment
  vpc_cidr               = var.vpc_cidr
  public_subnet_cidrs    = var.public_subnet_cidrs
  private_subnet_cidrs   = var.private_subnet_cidrs
  enable_nat_gateway     = var.enable_nat_gateway
  single_nat_gateway     = var.single_nat_gateway
  enable_vpc_flow_logs   = var.enable_vpc_flow_logs
  enable_s3_endpoint     = var.enable_s3_endpoint
  
  tags = var.tags
}

# Security Groups Module
module "security_groups" {
  source = "./modules/security-groups"
  
  project_name               = var.project_name
  environment               = var.environment
  vpc_id                    = module.vpc.vpc_id
  vpc_cidr                  = module.vpc.vpc_cidr_block
  
  # Enable EC2 security group
  create_ec2_sg             = true
  
  # Production security configurations
  alb_allowed_cidrs         = var.environment == "prod" ? var.production_allowed_cidrs : ["0.0.0.0/0"]
  enable_ssh_access         = var.environment != "prod"  # Disable SSH in production
  
  tags = var.tags
}

# ECR Module
module "ecr" {
  source = "./modules/ecr"
  
  project_name             = var.project_name
  environment             = var.environment
  enable_image_scanning   = var.ecr_enable_image_scanning
  max_image_count         = var.ecr_max_image_count
  untagged_expiry_days    = var.ecr_untagged_expiry_days
  
  tags = var.tags
}

# S3 Buckets
resource "aws_s3_bucket" "mlflow_artifacts" {
  bucket = "${var.project_name}-mlflow-artifacts-${var.environment}"
  tags   = var.tags
}

resource "aws_s3_bucket" "data_storage" {
  bucket = "${var.project_name}-data-storage-${var.environment}"
  tags   = var.tags
}

resource "aws_s3_bucket" "monitoring_reports" {
  bucket = "${var.project_name}-monitoring-reports-${var.environment}"
  tags   = var.tags
}

# S3 Bucket versioning
resource "aws_s3_bucket_versioning" "mlflow_artifacts_versioning" {
  bucket = aws_s3_bucket.mlflow_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "data_storage_versioning" {
  bucket = aws_s3_bucket.data_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "monitoring_reports_versioning" {
  bucket = aws_s3_bucket.monitoring_reports.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "mlflow_artifacts_encryption" {
  bucket = aws_s3_bucket.mlflow_artifacts.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data_storage_encryption" {
  bucket = aws_s3_bucket.data_storage.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "monitoring_reports_encryption" {
  bucket = aws_s3_bucket.monitoring_reports.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket public access block
resource "aws_s3_bucket_public_access_block" "mlflow_artifacts_pab" {
  bucket = aws_s3_bucket.mlflow_artifacts.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "data_storage_pab" {
  bucket = aws_s3_bucket.data_storage.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "monitoring_reports_pab" {
  bucket = aws_s3_bucket.monitoring_reports.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Kinesis Data Stream
resource "aws_kinesis_stream" "taxi_predictions" {
  name             = "taxi-ride-predictions-stream"
  shard_count      = 1
  retention_period = 24
  
  stream_mode_details {
    stream_mode = "PROVISIONED"
  }
  
  tags = var.tags
}

# Lambda Function Role (for future use)
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role-${var.environment}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = var.tags
}

# Lambda Policy
resource "aws_iam_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy-${var.environment}"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "${aws_s3_bucket.mlflow_artifacts.arn}/*",
          "${aws_s3_bucket.data_storage.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kinesis:GetRecords",
          "kinesis:GetShardIterator",
          "kinesis:DescribeStream",
          "kinesis:ListStreams"
        ]
        Resource = aws_kinesis_stream.taxi_predictions.arn
      }
    ]
  })
  
  tags = var.tags
}

# Attach Lambda policy
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# EC2 Instance for MLOps Orchestration Services (Airflow + MLflow)
resource "aws_instance" "mlops_orchestration" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.medium"
  key_name               = aws_key_pair.mlops_key.key_name
  vpc_security_group_ids = [module.security_groups.ec2_security_group_id]
  subnet_id              = module.vpc.public_subnet_ids[0]
  
  iam_instance_profile = aws_iam_instance_profile.mlops_profile.name
  
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }
  
  user_data = base64encode(templatefile("${path.module}/templates/user_data.sh", {
    project_name = var.project_name
    environment  = var.environment
    region       = var.aws_region
  }))
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-mlops-orchestration-${var.environment}"
  })
}

# Key Pair for EC2 access
resource "aws_key_pair" "mlops_key" {
  key_name   = "${var.project_name}-mlops-key-${var.environment}"
  public_key = file("${path.module}/ssh/mlops-key.pub")
  
  tags = var.tags
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

