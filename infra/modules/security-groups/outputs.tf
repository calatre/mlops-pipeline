# Security Groups Module Outputs

# EC2 Security Group Outputs
output "ec2_security_group_id" {
  description = "ID of the EC2 security group"
  value       = var.create_ec2_sg ? aws_security_group.ec2[0].id : null
}

output "ec2_security_group_arn" {
  description = "ARN of the EC2 security group"
  value       = var.create_ec2_sg ? aws_security_group.ec2[0].arn : null
}

output "ec2_security_group_name" {
  description = "Name of the EC2 security group"
  value       = var.create_ec2_sg ? aws_security_group.ec2[0].name : null
}

# Lambda Security Group Outputs
output "lambda_security_group_id" {
  description = "ID of the Lambda security group"
  value       = var.create_lambda_sg ? aws_security_group.lambda[0].id : null
}

output "lambda_security_group_arn" {
  description = "ARN of the Lambda security group"
  value       = var.create_lambda_sg ? aws_security_group.lambda[0].arn : null
}

# VPC Endpoints Security Group Outputs
output "vpc_endpoints_security_group_id" {
  description = "ID of the VPC endpoints security group"
  value       = var.create_vpc_endpoints_sg ? aws_security_group.vpc_endpoints[0].id : null
}

output "vpc_endpoints_security_group_arn" {
  description = "ARN of the VPC endpoints security group"
  value       = var.create_vpc_endpoints_sg ? aws_security_group.vpc_endpoints[0].arn : null
}

# Summary Outputs
output "security_groups_summary" {
  description = "Summary of all created security groups"
  value = {
    total_security_groups = (var.create_ec2_sg ? 1 : 0) + (var.create_lambda_sg ? 1 : 0) + (var.create_vpc_endpoints_sg ? 1 : 0)
    ec2_sg_id            = var.create_ec2_sg ? aws_security_group.ec2[0].id : null
    lambda_sg_id         = var.create_lambda_sg ? aws_security_group.lambda[0].id : null
    vpc_endpoints_sg_id  = var.create_vpc_endpoints_sg ? aws_security_group.vpc_endpoints[0].id : null
    ec2_enabled          = var.create_ec2_sg
    lambda_enabled       = var.create_lambda_sg
    vpc_endpoints_enabled = var.create_vpc_endpoints_sg
  }
}
