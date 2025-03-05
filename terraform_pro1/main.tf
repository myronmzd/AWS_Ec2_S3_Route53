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
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = false
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = true
}


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
  service_name     = "com.amazonaws.ap-south-1.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [aws_route_table.private_route_table.id]  # <--- Adds the route!
}

# SSM Endpoint
resource "aws_vpc_endpoint" "ssm" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.ap-south-1.ssm"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [aws_subnet.private_subnet.id]
  security_group_ids = [aws_security_group.ssm_sg.id]
}

# ------------------------------
# Security Group for EC2 (Allow DNS & S3)
# ------------------------------
resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "alb_sg" }
}

resource "aws_security_group" "ec2_sg" {
  vpc_id = aws_vpc.main.id

  # Allow only ALB to communicate with EC2 on port 80
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # Allow SSM and S3 access within VPC
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ec2_sg" }
}


resource "aws_security_group" "ssm_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ------------------------------    
# EC2 Instance
# ----------------------------------------------------------
resource "aws_instance" "main_ap_south_1" {
  ami           = "ami-00bb6a80f01f03502"
  instance_type = "t2.micro"
  key_name      = "Mykey"
  availability_zone = "ap-south-1a"
  iam_instance_profile = aws_iam_instance_profile.ec2_s3_profile.name  # Attach the IAM instance profile
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  subnet_id     = aws_subnet.private_subnet.id
  user_data = <<-EOF
    #!/bin/bash
    sudo apt update -y
    sudo snap install amazon-ssm-agent
    sudo systemctl enable amazon-ssm-agent
    sudo systemctl start amazon-ssm-agent
  EOF

  tags = {
      Name = "main_instance"
  }
}


resource "aws_ssm_association" "run_on_startup" {
  name = aws_ssm_document.run_script.name
  targets {
    key    = "InstanceIds"
    values = [aws_instance.main_ap_south_1.id]
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


# ------------------------------

# IAM Role for EC2 with S3 and SSM Access
resource "aws_iam_role" "ec2_role" {
  name = "ec2_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# IAM Policy for EC2 (Combining S3 and SSM permissions)
resource "aws_iam_policy" "ec2_policy" {
  name        = "ec2_policy"
  description = "Policy for EC2 to access S3 and SSM"
  
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
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:DescribeInstanceInformation",
          "ssm:GetCommandInvocation",
          "ssm:ListCommands",
          "ssm:ListCommandInvocations",
          "ssm:SendCommand"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2messages:GetMessages",
          "ec2messages:SendReply",
          "ec2messages:DeleteMessage",
          "ec2messages:FailMessage",
          "ssm:UpdateInstanceInformation"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach IAM Policy to IAM Role
resource "aws_iam_role_policy_attachment" "ec2_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_policy.arn
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role = aws_iam_role.ec2_role.name
}


resource "aws_ssm_document" "run_script" {
  name          = "RunScriptOnEC2"
  document_type = "Command"

  content = <<DOC
  {
    "schemaVersion": "2.2",
    "description": "Run a script on EC2",
    "mainSteps": [{
      "action": "aws:runShellScript",
      "name": "runScript",
      "inputs": {
        "runCommand": [
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
    }]
  }
  DOC
}



# Update EC2 security group to allow traffic from ALB
resource "aws_security_group_rule" "allow_alb" {
  type                     = "ingress"
  from_port               = 80
  to_port                 = 80
  protocol                = "tcp"
  source_security_group_id = aws_security_group.alb_sg.id
  security_group_id       = aws_security_group.ec2_sg.id
}



# Create ALB
resource "aws_lb" "main_lb" {
  name               = "main-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.private_subnet.id, aws_subnet.public_subnet.id]
}

# Create target group
resource "aws_lb_target_group" "main_lb_tg" {
  name     = "main-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 10
  }
}

# Attach EC2 to target group
resource "aws_lb_target_group_attachment" "main" {
  target_group_arn = aws_lb_target_group.main_lb_tg.arn
  target_id        = aws_instance.main_ap_south_1.id
  port             = 80
}

# Create ALB listener
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.main_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_lb_tg.arn
  }
}

# Route53 DNS Zone
data "aws_route53_zone" "my_domain" {
  name         = "myronmzd.com"  # Your domain name
  private_zone = false
}

# Update Route53 record to point to ALB
resource "aws_route53_record" "root" {
  zone_id = data.aws_route53_zone.my_domain.zone_id
  name    = "home.myronmzd.com"
  type    = "A"

  alias {
    name                   = aws_lb.main_lb.dns_name
    zone_id                = aws_lb.main_lb.zone_id
    evaluate_target_health = true
  }
}