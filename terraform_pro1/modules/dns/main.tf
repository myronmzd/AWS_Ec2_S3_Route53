data "aws_route53_zone" "zone" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "root" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "home.${var.domain_name}"
  type    = "A"
  ttl     = "300"
  records = [var.public_ip]
}