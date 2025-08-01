# MLOps Taxi Prediction Infrastructure

## Overview
Simplified AWS infrastructure for MLOps pipeline using EC2 instances with Docker Compose instead of managed services for cost optimization and learning purposes.

## Architecture

### Components
- **Frontend EC2**: t3.micro instance running Flask admin GUI (port 5000)
- **Orchestration EC2**: t3.medium instance running Docker Compose with:
  - Airflow (port 8080)
  - MLflow (port 5000)
  - PostgreSQL (port 5432)
  - Redis (port 6379)
  - Status page (port 8081)
- **S3 Buckets**: MLflow artifacts, data storage, monitoring reports
- **Kinesis Stream**: Real-time data streaming
- **Lambda Function**: Model inference (containerized)
- **VPC**: Isolated network with public/private subnets


### Cost Optimization
- **EC2 instances** instead of ECS Fargate (~$60-80/month savings)
- **Containerized PostgreSQL** instead of RDS (~$30-40/month savings)
- **Direct EC2 access** instead of ALB (~$20-30/month savings)
- **Local Docker volumes** instead of EFS (~$15-20/month savings)
- **Single NAT Gateway** for cost efficiency

## Deployment

### Prerequisites
- AWS CLI configured
- Terraform installed
- SSH key pair for EC2 access

### Quick Start
```bash
# Navigate to infrastructure directory
cd mlops-pipeline/infra

# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Deploy infrastructure
terraform apply

# Get outputs
terraform output
```

### Access URLs
After deployment, access services via:
- **Frontend**: http://[frontend-public-ip]:5000
- **Airflow**: http://[orchestration-public-ip]:8080
- **MLflow**: http://[orchestration-public-ip]:5000
- **Status**: http://[orchestration-public-ip]:8081

## File Structure
```
infra/
├── main-modular.tf          # Main infrastructure configuration
├── frontend.tf              # Frontend EC2 instance
├── variables.tf             # Input variables
├── outputs-modular.tf       # Output values
├── modules/
│   ├── vpc/                # VPC and networking
│   ├── security-groups/    # Security group rules
│   # └── ecr/             # (now only for Lambda function image)
├── templates/
│   └── user_data.sh       # EC2 user data script
└── ssh/
    └── mlops-key.pub      # SSH public key
```

## Security
- **VPC isolation** with public/private subnets
- **Security groups** with least-privilege access
- **IAM roles** for EC2 instances
- **Encrypted storage** for S3 and EBS volumes

## Monitoring
- **CloudWatch logs** for application monitoring
- **S3 access logs** for storage monitoring
- **EC2 instance metrics** for resource monitoring

## Cost Estimation
- **Total monthly cost**: ~$30-50
- **EC2 instances**: ~$15-25
- **S3 storage**: ~$5-10
- **Kinesis stream**: ~$5-10
- **Other services**: ~$5-10

## Learning Focus
This infrastructure prioritizes:
- **Simplicity** over enterprise complexity
- **Cost efficiency** over managed services
- **Educational value** over production readiness
- **Docker Compose** familiarity over cloud-native patterns

## Troubleshooting
- Check EC2 instance status in AWS Console
- Verify security group rules allow required ports
- Review CloudWatch logs for application errors
- Ensure SSH key is properly configured
