# Security Groups Module Outputs

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "alb_security_group_arn" {
  description = "ARN of the ALB security group"
  value       = aws_security_group.alb.arn
}

output "ec2_security_group_id" {
  description = "ID of the EC2 security group"
  value       = var.create_ec2_sg ? aws_security_group.ec2[0].id : null
}

output "ec2_security_group_arn" {
  description = "ARN of the EC2 security group"
  value       = var.create_ec2_sg ? aws_security_group.ec2[0].arn : null
}

output "ecs_security_group_id" {
  description = "ID of the ECS security group"
  value       = var.create_ecs_sg ? aws_security_group.ecs[0].id : null
}

output "ecs_security_group_arn" {
  description = "ARN of the ECS security group"
  value       = var.create_ecs_sg ? aws_security_group.ecs[0].arn : null
}



# RDS and EFS security groups removed (no longer used in simplified architecture)

output "lambda_security_group_id" {
  description = "ID of the Lambda security group"
  value       = var.create_lambda_sg ? aws_security_group.lambda[0].id : null
}

output "lambda_security_group_arn" {
  description = "ARN of the Lambda security group"
  value       = var.create_lambda_sg ? aws_security_group.lambda[0].arn : null
}

output "vpc_endpoints_security_group_id" {
  description = "ID of the VPC endpoints security group"
  value       = var.create_vpc_endpoints_sg ? aws_security_group.vpc_endpoints[0].id : null
}

output "vpc_endpoints_security_group_arn" {
  description = "ARN of the VPC endpoints security group"
  value       = var.create_vpc_endpoints_sg ? aws_security_group.vpc_endpoints[0].arn : null
}

# Redis security group removed (no longer used in simplified architecture)

# Security Groups Summary
output "security_groups_summary" {
  description = "Summary of all created security groups"
  value = {
    alb_sg_id                   = aws_security_group.alb.id
    ecs_sg_id                   = var.create_ecs_sg ? aws_security_group.ecs[0].id : null
    ec2_sg_id                   = var.create_ec2_sg ? aws_security_group.ec2[0].id : null
    lambda_sg_id                = var.create_lambda_sg ? aws_security_group.lambda[0].id : null
    vpc_endpoints_sg_id         = var.create_vpc_endpoints_sg ? aws_security_group.vpc_endpoints[0].id : null
    total_security_groups       = 2 + (var.create_ecs_sg ? 1 : 0) + (var.create_ec2_sg ? 1 : 0) + (var.create_lambda_sg ? 1 : 0) + (var.create_vpc_endpoints_sg ? 1 : 0)
    ssh_access_enabled          = var.enable_ssh_access
  }
}
