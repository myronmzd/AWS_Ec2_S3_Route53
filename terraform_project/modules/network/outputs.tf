output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "private_subnet_id" {
  description = "Private Subnet ID"
  value       = aws_subnet.private_subnet.id
}

output "public_subnet_id" {
  description = "Public Subnet ID"
  value       = aws_subnet.public_subnet.id
}

output "igw" {
  description = "igw ID"
  value       = aws_internet_gateway.igw.id
}

output "security_group_id" {
  value = aws_security_group.ec2_sg.id
}
