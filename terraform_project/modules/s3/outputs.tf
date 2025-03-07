output "aws_iam_instance_profile" {
  description = "aws_iam_instance_profile of the EC2 instance"
  value = aws_iam_instance_profile.ec2_profile.name
}


