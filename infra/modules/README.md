# Terraform Modules for MLOps Infrastructure

Simple, cost-optimized modules for the MLOps Taxi Prediction personal project.

## VPC Module (`./vpc`)

Creates a basic VPC with public/private subnets across 2 AZs.

**Key Features:**
- Public subnets for ALB
- Private subnets for ECS, RDS, EFS
- NAT gateways for internet access
- Cost optimization options

**Basic Usage:**
```hcl
module "vpc" {
  source = "./modules/vpc"
  
  project_name = var.project_name
  environment  = var.environment
  
  # Cost optimization for personal project
  single_nat_gateway = true  # Saves ~$45/month
  
  tags = var.tags
}
```

## Security Groups Module (`./security-groups`)

Creates security groups with least-privilege access for MLOps components.

**Security Groups Created:**
- ALB (HTTP/HTTPS from internet)
- ECS (ports 8080/5000 from ALB)
- RDS (port 5432 from ECS)
- EFS (port 2049 from ECS)

**Basic Usage:**
```hcl
module "security_groups" {
  source = "./modules/security-groups"
  
  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  vpc_cidr     = module.vpc.vpc_cidr_block
  
  tags = var.tags
}
```

## Cost Optimization Defaults

For personal projects, these settings save money:
- `single_nat_gateway = true` (saves $45/month)
- `enable_vpc_flow_logs = false` (saves $10-30/month)
- `enable_s3_endpoint = false` (minimal benefit for small projects)

## Network Layout

```
Internet
   │
   └── ALB (Public Subnets)
       │
       └── ECS Tasks (Private Subnets)
           ├── RDS Database
           └── EFS Storage
```

The modules handle all the routing and security group relationships automatically.
