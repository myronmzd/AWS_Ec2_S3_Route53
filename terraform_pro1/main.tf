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

# ------------------------------
# Subnets
# ------------------------------

resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = false
}


# resource "aws_subnet" "public_subnet" {
#   vpc_id     = aws_vpc.main.id
#   cidr_block = "10.0.2.0/24"
#   availability_zone = "ap-south-1a"
#   map_public_ip_on_launch = true # This will ensure instances launched in this subnet automatically get public IPs.
#   tags = {
#     Name = "Main"
#   }
# }

# ------------------------------
# Internet Gatewat
# ------------------------------

# resource "aws_internet_gateway" "IGW_main" {
#   vpc_id = aws_vpc.main.id
#   tags = {
#     Name = "Main"
#   } 
# }


# ---------------------------------
# Route Table public and private 
# ---------------------------------

# resource "aws_route_table" "main" {
#   vpc_id = aws_vpc.main.id
#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.IGW_main.id
#   }
#   tags = {
#     Name = "IGW_route_table"
#   }
# }

# resource "aws_route_table_association" "a" {
#   subnet_id      = aws_subnet.main.id
#   route_table_id = aws_route_table.main.id
# } 


# Private Route Table (for EC2 in private subnet)
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main.id
}

# Associate private subnet with this route table
resource "aws_route_table_association" "private_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

# --------------------------------------------------------------------
# generate key pair manually in console and provide the key name here
# --------------------------------------------------------------------


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


resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id           = aws_vpc.main.id
  service_name     = "com.amazonaws.ap-south-1a.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [aws_route_table.private_route_table.id]  # <--- Adds the route!
}
# Route 53 Resolver Endpoint (Costs $$)
resource "aws_vpc_endpoint" "route53_endpoint" {
  vpc_id          = aws_vpc.main.id
  service_name    = "com.amazonaws.ap-south-1a.route53-recurser"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [aws_subnet.private_subnet.id]  # ✅ Needs a subnet
  security_group_ids = [aws_security_group.ec2_route53_sg.id]
}

# ------------------------------
# Security Group for Route 53 Interface Endpoint
# ------------------------------
resource "aws_security_group" "ec2_route53_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/16"]  # Allow DNS resolution within VPC
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ------------------------------
# Security Group for EC2 (Allow DNS & S3)
# ------------------------------
resource "aws_security_group" "ec2_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" 
    cidr_blocks = ["0.0.0.0/0"]
    }
  
}


resource "aws_instance" "main_ap_south_1" {
  ami           = "ami-00bb6a80f01f03502"
  instance_type = "t2.micro"
  key_name      = "Mykey"
  availability_zone = "ap-south-1a"
  iam_instance_profile = aws_iam_instance_profile.ec2_s3_profile.name  # Attach the IAM instance profile
  vpc_security_group_ids = [aws_security_group.allow_all.id]
  subnet_id     = aws_subnet.main.id
    tags = {
        Name = "main_instance"
    }
}

resource "aws_s3_bucket" "mybucketmain1212" {
  bucket = "mybucketmain1212"  # Replace with a unique bucket name
}

resource "aws_s3_object" "files" {
  for_each = fileset("${path.module}/S3_files/", "**")  # Read all files in the folder

  bucket = aws_s3_bucket.mybucketmain1212.id
  key    = each.value  # Use the file path as the S3 object key
  source = "${path.module}/S3_files/${each.value}"
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
resource "aws_iam_instance_profile" "ec2_s3_profile" {
  name = "ec2_s3_profile"
  role = aws_iam_role.ec2_s3_access_role.name
}

resource "null_resource" "setup_web_server" {
  depends_on = [aws_instance.main_ap_south_1]

 

  provisioner "remote-exec" {
      connection {
        type        = "ssh"
        user        = "ubuntu"
        private_key = file("${path.module}/Mykey.pem")
        host        = aws_instance.main_ap_south_1.public_ip
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

# Route53 DNS Zone
data "aws_route53_zone" "my_domain" {
  name         = "myronmzd.com"  # Your domain name
  private_zone = false
}

# # Route53 A Record pointing to EC2 instance
# resource "aws_route53_record" "www" {
#   zone_id = data.aws_route53_zone.my_domain.zone_id
#   name    = "www.myronmzd.com"  # Your subdomain
#   type    = "A"
#   ttl     = "300"
#   records = [aws_instance.main_ap_south_1.public_ip]
# }


# Route53 A Record for root domain
resource "aws_route53_record" "root" {
  zone_id = data.aws_route53_zone.my_domain.zone_id
  name    = "home.myronmzd.com"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.main_ap_south_1.public_ip]
}