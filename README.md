# Terraform AWS Infrastructure

## Overview
This Terraform configuration file (`main.tf`) provisions an AWS infrastructure that includes a Virtual Private Cloud (VPC), subnets, an EC2 instance, security groups, an S3 bucket, IAM roles, and networking resources such as an Internet Gateway and a Route 53 record. The infrastructure is designed for a web server running on an EC2 instance with access to an S3 bucket via a VPC endpoint.

## Resources Created

### 1. **AWS Provider**
- Sets the AWS region to `ap-south-1` (Mumbai).

### 2. **VPC**
- A VPC (`aws_vpc.main`) with CIDR block `10.0.0.0/16` is created.

### 3. **Subnets**
- **Public Subnet:** `10.0.1.0/24` in `ap-south-1a`, connected to the Internet Gateway.
- **Private Subnet:** `10.0.2.0/24` in `ap-south-1a`, used for internal resources.

### 4. **Internet Gateway and Routing**
- Internet Gateway (`aws_internet_gateway.igw`) for public subnet.
- **Public Route Table:** Routes public traffic through the Internet Gateway.
- **Private Route Table:** Used for private subnet, does not allow direct internet access.

### 5. **S3 VPC Endpoint**
- A Gateway VPC Endpoint (`aws_vpc_endpoint.s3_endpoint`) allows private subnet instances to communicate with S3 without using the internet.

### 6. **EC2 Instance**
- A single EC2 instance (`aws_instance.main_ap_south_1`) with:
  - `t2.micro` instance type.
  - AMI: `ami-00bb6a80f01f03502`.
  - Public and private network interfaces.
  - IAM role for S3 access.

### 7. **Elastic IP (EIP)**
- An Elastic IP (`aws_eip.public_ip`) is assigned to the public-facing ENI.

### 8. **Network Interfaces**
- **Public ENI:** Allows the EC2 instance to connect to the internet.
- **Private ENI:** Used for internal communication, including the S3 VPC endpoint.

### 9. **Security Group**
- `aws_security_group.ec2_sg` allowing:
  - SSH (`22/tcp`) from anywhere.
  - HTTP (`80/tcp`) and HTTPS (`443/tcp`) from anywhere.
  - All outbound traffic is allowed.

### 10. **S3 Bucket and Objects**
- S3 bucket (`aws_s3_bucket.mybucketmain1212`) for storing web files.
- Files are uploaded from `S3_files/` directory.
- Bucket policy restricts access to the VPC.

### 11. **IAM Roles and Policies**
- IAM Role (`aws_iam_role.ec2_s3_access_role`) for EC2 instance.
- IAM Policy (`aws_iam_role_policy.s3_access_policy`) granting S3 read/write permissions.
- IAM Instance Profile (`aws_iam_instance_profile.ec2_profile`).

### 12. **Web Server Setup with Remote Provisioner**
- Installs and configures Nginx on the EC2 instance.
- Downloads the website's home page (`home.html`) from S3.
- Ensures Nginx is started and enabled.

### 13. **Route 53 DNS Configuration**
- A Route 53 record (`aws_route53_record.root`) maps `home.myronmzd.com` to the EC2 instance’s Elastic IP.

## Usage

### 1. **Initialize Terraform**
```sh
terraform init
```

### 2. **Plan the Deployment**
```sh
terraform plan
```

### 3. **Apply the Configuration**
```sh
terraform apply -auto-approve
```

### 4. **Destroy the Infrastructure** (if needed)
```sh
terraform destroy -auto-approve
```

## Notes
- Ensure you have an SSH key pair (`Mykey.pem`) in the Terraform directory.
- Update the AMI ID and domain name (`myronmzd.com`) as per your requirements.
- The S3 bucket name must be unique globally.

## Author
This Terraform configuration was written to automate AWS infrastructure provisioning for a web server setup.

