provider "aws" {
  region = "ap-south-1"
  
}

# ------------------------------
# VPC Creation
# ------------------------------

resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  tags = {
    Name = "main"
  }

}

# --------------------------------
# Public Subnet (Connected to IGW)
# --------------------------------
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-south-1a"
}

# --------------------------------
# Private Subnet (For S3 via VPC Endpoint)
# --------------------------------
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "ap-south-1a"
}

# --------------------------------
# Internet Gateway for Public Subnet
# --------------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
    tags = {
    Name = "main-igw"
  }
}

# --------------------------------
# Route Table for Public Subnet
# --------------------------------
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}
resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# --------------------------------
# Private Route Table (for EC2 in private subnet)
# --------------------------------
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main.id
}
resource "aws_route_table_association" "private_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

# --------------------------------------------------------------------
# generate key pair manually in console and provide the key name here
# --------------------------------------------------------------------

# --------------------------------
# S3 VPC Endpoint (Gateway) - Private Subnet
# --------------------------------
resource "aws_vpc_endpoint" "s3_endpoint" {
  depends_on = [aws_vpc.main]
  vpc_id           = aws_vpc.main.id
  service_name     = "com.amazonaws.ap-south-1.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [aws_route_table.private_route_table.id]
}

resource "aws_instance" "main_ap_south_1"{
  ami                    = "ami-00bb6a80f01f03502" # Update for your region
  instance_type          = "t2.micro"
  key_name      = "Mykey"
  availability_zone = "ap-south-1a"
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name


  network_interface {
    network_interface_id = aws_network_interface.public_eni.id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.private_eni.id
    device_index         = 1
  }

  tags = {
        Name = "main_instance"
  }
}


# --------------------------------
# Public ENI (For Route 53 and Internet)
# --------------------------------
resource "aws_network_interface" "public_eni" {
  subnet_id       = aws_subnet.public_subnet.id
  security_groups = [aws_security_group.ec2_sg.id]
  source_dest_check = true
    tags = {
    Name = "public_eni"
  }
}

# --------------------------------
# Private ENI (For S3 VPC Endpoint)
# --------------------------------
resource "aws_network_interface" "private_eni" {
  subnet_id       = aws_subnet.private_subnet.id
  security_groups = [aws_security_group.ec2_sg.id]
    tags = {
    Name = "private_eni"
  }
}

# --------------------------------
# Security Group for EC2
# --------------------------------
resource "aws_security_group" "ec2_sg" {
  name        = "ec2_security_group"
  description = "Security group for EC2 instance"
  vpc_id      = aws_vpc.main.id

  # SSH access
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2_security_group"
  }
}

# ----------------------------------------------------------
# S3 Bucket and Object
# ----------------------------------------------------------

resource "aws_s3_bucket" "mybucketmain1212" {
  bucket = "mybucketmain1212"  # Replace with a unique bucket name
}

resource "aws_s3_object" "files" {
  for_each = fileset("${path.module}/S3_files/", "**")  # Read all files in the folder

  bucket = aws_s3_bucket.mybucketmain1212.id
  key    = each.value  # Use the file path as the S3 object key
  source = "${path.module}/S3_files/${each.value}"
}
# Add bucket policy for additional security
resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.mybucketmain1212.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "VPCEndpointAccess"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject", "s3:ListBucket"]
        Resource  = [
          aws_s3_bucket.mybucketmain1212.arn,
          "${aws_s3_bucket.mybucketmain1212.arn}/*"
        ]
        Condition = {
          StringEquals = {
            "aws:SourceVpc": aws_vpc.main.id
          }
        }
      }
    ]
  })
}

# IAM Role for EC2
resource "aws_iam_role" "ec2_s3_access_role" {
  name = "ec2_s3_access_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for S3 access
resource "aws_iam_role_policy" "s3_access_policy" {
  name = "s3_access_policy"
  role = aws_iam_role.ec2_s3_access_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.mybucketmain1212.arn}",
          "${aws_s3_bucket.mybucketmain1212.arn}/*"
        ]
      }
    ]
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role = aws_iam_role.ec2_s3_access_role.name
}


resource "null_resource" "setup_web_server" {
  depends_on = [aws_instance.main_ap_south_1]
    triggers = {
    instance_id = aws_instance.main_ap_south_1.id
  }
  provisioner "remote-exec" {
      connection {
        type        = "ssh"
        user        = "ubuntu"
        private_key = file("${path.module}/Mykey.pem")
        host        = aws_eip.public_ip.public_ip
        timeout     = "4m"
      }

      inline = [
                # Update package list okey
              "sudo apt update -y",
              "sudo apt upgrade -y",

              # Install Nginx only if not installed okey
              "if ! command -v nginx &> /dev/null; then sudo apt install -y nginx; fi",

              # Install AWS CLIand unzip  only if not installed okey
              "if ! command -v aws &>/dev/null; then sudo apt update && sudo apt install -y unzip && curl -s 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip' && unzip -o awscliv2.zip && sudo ./aws/install --update && rm -rf aws awscliv2.zip; fi",

              
              # Start and enable Nginx if not already running
              "if ! systemctl is-active --quiet nginx; then sudo systemctl start nginx; fi",
              "if ! systemctl is-enabled --quiet nginx; then sudo systemctl enable nginx; fi",

              # Copy file from S3 if it doesn't already exist
              "if [ ! -f /var/www/html/index.html ]; then aws s3 cp s3://mybucketmain1212/home.html /tmp/home.html; fi",
              "if [ ! -f /var/www/html/index.html ]; then sudo mv /tmp/home.html /var/www/html/index.html; fi",

              "sudo rm -rf /var/www/html/index.nginx-debian.html",

              # Set correct permissions
              "sudo chmod 644 /var/www/html/index.html",
              "sudo chown www-data:www-data /var/www/html/index.html"
    ]
  }
}


resource "aws_eip" "public_ip" {
  domain            = "vpc"
  network_interface = aws_network_interface.public_eni.id
  depends_on        = [aws_internet_gateway.igw]
  tags = {
    Name = "public-eip"
  }
}


# Route53 DNS Zone
data "aws_route53_zone" "my_domain" {
  name         = "myronmzd.com"  # Your domain name
  private_zone = false
}

# Update Route53 record to point to ALB
resource "aws_route53_record" "root" {
  depends_on = [aws_eip.public_ip]

  zone_id = data.aws_route53_zone.my_domain.zone_id
  name    = "home.myronmzd.com"
  type    = "A"
  ttl = "300"
  records = [aws_eip.public_ip.public_ip]

}



# ----------------------------------------------------------
# S3 VPC Gateway Endpoint (FREE) - Add it to the route table
# ----------------------------------------------------------

# Gateway Endpoint (For S3 & DynamoDB)

# ✅ Free
# ✅ Needs to be added to the Route Table
# ❌ Does not need a subnet
# Interface Endpoint (For Route 53, SSM, CloudWatch, etc.)

# ❌ Not Free (Costs per hour + per query)
# ✅ Needs to be deployed in a Subnet
# ❌ Does not need a Route Table (Handled by AWS via private DNS)
