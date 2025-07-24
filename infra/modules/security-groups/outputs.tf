# Security Groups Module Outputs

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "alb_security_group_arn" {
  description = "ARN of the ALB security group"
  value       = aws_security_group.alb.arn
}

output "ecs_security_group_id" {
  description = "ID of the ECS security group"
  value       = aws_security_group.ecs.id
}

output "ecs_security_group_arn" {
  description = "ARN of the ECS security group"
  value       = aws_security_group.ecs.arn
}

output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = aws_security_group.rds.id
}

output "rds_security_group_arn" {
  description = "ARN of the RDS security group"
  value       = aws_security_group.rds.arn
}

output "efs_security_group_id" {
  description = "ID of the EFS security group"
  value       = aws_security_group.efs.id
}

output "efs_security_group_arn" {
  description = "ARN of the EFS security group"
  value       = aws_security_group.efs.arn
}

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

output "redis_security_group_id" {
  description = "ID of the Redis security group"
  value       = var.create_redis_sg ? aws_security_group.redis[0].id : null
}

output "redis_security_group_arn" {
  description = "ARN of the Redis security group"
  value       = var.create_redis_sg ? aws_security_group.redis[0].arn : null
}

# Security Groups Summary
output "security_groups_summary" {
  description = "Summary of all created security groups"
  value = {
    alb_sg_id                   = aws_security_group.alb.id
    ecs_sg_id                   = aws_security_group.ecs.id
    rds_sg_id                   = aws_security_group.rds.id
    efs_sg_id                   = aws_security_group.efs.id
    lambda_sg_id                = var.create_lambda_sg ? aws_security_group.lambda[0].id : null
    vpc_endpoints_sg_id         = var.create_vpc_endpoints_sg ? aws_security_group.vpc_endpoints[0].id : null
    redis_sg_id                 = var.create_redis_sg ? aws_security_group.redis[0].id : null
    total_security_groups       = 4 + (var.create_lambda_sg ? 1 : 0) + (var.create_vpc_endpoints_sg ? 1 : 0) + (var.create_redis_sg ? 1 : 0)
    ssh_access_enabled          = var.enable_ssh_access
  }
}
