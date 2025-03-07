terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0" # Specify your desired version
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}
SDFA
module "network" {
  source = "./modules/network"
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
}

module "compute" {
  source             = "./modules/compute"
  instance_type      = "t2.micro"
  ami_id             = "ami-00bb6a80f01f03502"
  vpc_id             = module.network.vpc_id
  subnet_public_id   = module.network.public_subnet_id
  subnet_private_id  = module.network.private_subnet_id
  security_group_id  = module.network.security_group_id
  aws_iam_instance_profile = module.s3.aws_iam_instance_profile
}

module "s3" {
  source = "./modules/s3"
  vpc_id = module.network.vpc_id
}

module "dns" {
  source      = "./modules/dns"
  public_ip   = module.compute.public_ip
  domain_name = "myronmzd.com"
}