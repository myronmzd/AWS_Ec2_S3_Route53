output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.main_instance.id
}

output "public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.main_instance.public_ip
}