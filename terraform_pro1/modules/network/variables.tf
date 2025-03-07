variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
}

variable "private_subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
}