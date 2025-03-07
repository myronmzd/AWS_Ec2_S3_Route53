variable "vpc_id" {
  description = "The VPC id"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}
DCSGFD
variable "ami_id" {
  description = "AMI ID for the instance"
  type        = string
}

variable "subnet_public_id" {
   type        = string
}
variable "subnet_private_id" {
   type        = string
}

variable "security_group_id" {
  type        = string
}
variable "aws_iam_instance_profile" {
  description = "The IAM instance profile for EC2 instances"
  type        = string
}