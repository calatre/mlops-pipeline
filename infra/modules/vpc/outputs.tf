# VPC Module Outputs

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "vpc_arn" {
  description = "ARN of the VPC"
  value       = aws_vpc.main.arn
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets"
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets"
  value       = aws_subnet.private[*].cidr_block
}

output "public_subnet_arns" {
  description = "ARNs of the public subnets"
  value       = aws_subnet.public[*].arn
}

output "private_subnet_arns" {
  description = "ARNs of the private subnets"
  value       = aws_subnet.private[*].arn
}

output "availability_zones" {
  description = "Availability zones used for subnets"
  value       = data.aws_availability_zones.available.names
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}

output "nat_gateway_ips" {
  description = "Public IPs of the NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "IDs of the private route tables"
  value       = aws_route_table.private[*].id
}

output "s3_vpc_endpoint_id" {
  description = "ID of the S3 VPC endpoint"
  value       = var.enable_s3_endpoint ? aws_vpc_endpoint.s3[0].id : null
}

output "vpc_flow_log_id" {
  description = "ID of the VPC Flow Log"
  value       = var.enable_vpc_flow_logs ? aws_flow_log.vpc_flow_log[0].id : null
}

output "vpc_flow_log_cloudwatch_log_group" {
  description = "CloudWatch Log Group for VPC Flow Logs"
  value       = var.enable_vpc_flow_logs ? aws_cloudwatch_log_group.vpc_flow_log[0].name : null
}

# Network Summary
output "network_summary" {
  description = "Summary of network configuration"
  value = {
    vpc_id             = aws_vpc.main.id
    vpc_cidr           = aws_vpc.main.cidr_block
    public_subnets     = length(aws_subnet.public)
    private_subnets    = length(aws_subnet.private)
    nat_gateways       = length(aws_nat_gateway.main)
    availability_zones = length(data.aws_availability_zones.available.names)
    single_nat_gateway = var.single_nat_gateway
    vpc_flow_logs      = var.enable_vpc_flow_logs
    s3_endpoint        = var.enable_s3_endpoint
  }
}
