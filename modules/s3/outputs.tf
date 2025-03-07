output "aws_iam_instance_profile" {
  value = aws_iam_instance_profile.example.name
  // Ensure this references the correct resource in your s3 module
}
