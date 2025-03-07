resource "aws_s3_bucket" "mybucketmain1212" {
  bucket = "mybucketmain1212"
}

resource "aws_s3_object" "files" {
  for_each = fileset("${path.module}/S3_files/", "**")

  bucket = aws_s3_bucket.mybucketmain1212.id
  key    = each.value
  source = "${path.module}/S3_files/${each.value}"
}

# Add bucket policy for additional security
resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.mybucketmain1212.id
fdasfdsa
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
            "aws:SourceVpc": var.vpc_id
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