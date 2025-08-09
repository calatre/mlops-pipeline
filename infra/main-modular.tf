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

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = []
  enable_nat_gateway   = false
  single_nat_gateway   = false
  enable_vpc_flow_logs = false
  enable_s3_endpoint   = false

  tags = var.tags
}

# Security Group Module
module "security_group" {
  source = "./modules/security-groups"

  project_name            = var.project_name
  environment             = var.environment
  vpc_id                  = module.vpc.vpc_id
  vpc_cidr                = var.vpc_cidr
  create_ec2_sg           = true
  create_lambda_sg        = false
  create_vpc_endpoints_sg = false
  enable_ssh_access       = true
  ssh_allowed_cidrs       = ["0.0.0.0/0"]

  tags = var.tags
}

# Consolidated Security Group for all EC2 Instances
resource "aws_security_group" "main" {
  name        = "${var.project_name}-main-sg-${var.environment}"
  description = "Main security group for all EC2 instances"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow app access on port 5000"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow Airflow access on port 8080"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow status page on port 8081"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-main-sg-${var.environment}"
  })
}

# Consolidated IAM Role for EC2 Instances
resource "aws_iam_role" "main_ec2_role" {
  name = "${var.project_name}-main-ec2-role-${var.environment}"

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

# Consolidated IAM Policy
resource "aws_iam_policy" "main_ec2_policy" {
  name = "${var.project_name}-main-ec2-policy-${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = "s3:*",
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
        Effect   = "Allow",
        Action   = "kinesis:*",
        Resource = aws_kinesis_stream.taxi_predictions.arn
      },
      {
        Effect   = "Allow",
        Action   = "logs:*",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "main_ec2_policy_attachment" {
  role       = aws_iam_role.main_ec2_role.name
  policy_arn = aws_iam_policy.main_ec2_policy.arn
}

# Attach SSM policy for Session Manager access (optional but recommended)
resource "aws_iam_role_policy_attachment" "main_ssm" {
  role       = aws_iam_role.main_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "main_instance_profile" {
  name = "${var.project_name}-main-instance-profile-${var.environment}"
  role = aws_iam_role.main_ec2_role.name
}


# Single SSH Key for all instances
resource "tls_private_key" "main_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "main_key" {
  key_name   = "mlops-main-key"
  public_key = tls_private_key.main_key.public_key_openssh
}

resource "local_file" "main_key_private" {
  content         = tls_private_key.main_key.private_key_pem
  filename        = "${path.module}/ssh/mlops_main_key.pem"
  file_permission = "0600"
}

# ECR Module
module "ecr" {
  source = "./modules/ecr"

  project_name          = var.project_name
  environment           = var.environment
  enable_image_scanning = var.ecr_enable_image_scanning
  max_image_count       = var.ecr_max_image_count
  untagged_expiry_days  = var.ecr_untagged_expiry_days

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

# S3 Bucket encryption - skipping for simplicity
# Uncomment if you want to enable encryption
#resource "aws_s3_bucket_server_side_encryption_configuration" "mlflow_artifacts_encryption" {
#  bucket = aws_s3_bucket.mlflow_artifacts.id
#
#  rule {
#    apply_server_side_encryption_by_default {
#      sse_algorithm = "AES256"
#    }
#  }
#}
#
#resource "aws_s3_bucket_server_side_encryption_configuration" "data_storage_encryption" {
#  bucket = aws_s3_bucket.data_storage.id
#
#  rule {
#    apply_server_side_encryption_by_default {
#      sse_algorithm = "AES256"
#    }
#  }
#}
#
#resource "aws_s3_bucket_server_side_encryption_configuration" "monitoring_reports_encryption" {
#  bucket = aws_s3_bucket.monitoring_reports.id
#
#  rule {
#    apply_server_side_encryption_by_default {
#      sse_algorithm = "AES256"
#    }
#  }
#}

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
  shard_count      = var.kinesis_shard_count
  retention_period = 24

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }

  tags = var.tags
}

# Lambda Function Role
resource "null_resource" "build_lambda_container" {
  # Triggers rebuild when Lambda source code or build script changes
  triggers = {
    lambda_source_hash = filemd5("${path.module}/../lambda_function/lambda_function.py")
    dockerfile_hash    = filemd5("${path.module}/../lambda_function/Dockerfile")
    requirements_hash  = filemd5("${path.module}/../lambda_function/requirements.txt")
    build_script_hash  = filemd5("${path.module}/../scripts/build_lambda.sh")
  }

  provisioner "local-exec" {
    command     = "./scripts/build_lambda.sh"
    working_dir = "${path.module}/.."
  }

  depends_on = [
    module.ecr
  ]
}

# Lambda Function Role
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
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
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

# Lambda Function using container image from ECR
resource "aws_lambda_function" "taxi_prediction" {
  function_name = "${var.project_name}-taxi-prediction-${var.environment}"
  role          = aws_iam_role.lambda_role.arn
  package_type  = "Image"
  image_uri     = "${module.ecr.lambda_repository_url}:latest"
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size
  architectures = ["x86_64"]

  environment {
    variables = {
      MLFLOW_TRACKING_URI = "http://${aws_instance.mlops_orchestration.private_ip}:5000"
      DATA_BUCKET         = aws_s3_bucket.data_storage.bucket
      ARTIFACTS_BUCKET    = aws_s3_bucket.mlflow_artifacts.bucket
      KINESIS_STREAM      = aws_kinesis_stream.taxi_predictions.name
      PROJECT_NAME        = var.project_name
      ENVIRONMENT         = var.environment
    }
  }

  # Ensure container is built and pushed before Lambda deployment
  depends_on = [
    null_resource.build_lambda_container,
    aws_iam_role_policy_attachment.lambda_policy_attachment
  ]

  tags = var.tags
}
