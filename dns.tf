# Create A record in our hosted zone
resource "aws_route53_record" "uptime_kuma" {
  zone_id = aws_route53_zone.status.zone_id  # Use our new zone, not the parent zone
  name    = var.domain_name
  type    = "A"
  ttl     = "300"
  records = [aws_instance.uptime_kuma.public_ip]
} 