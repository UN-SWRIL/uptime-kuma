output "public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.uptime_kuma.public_ip
}

output "uptime_kuma_url" {
  description = "URL for Uptime Kuma web interface"
  value       = "http://${var.domain_name}:3001"
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ${var.key_name}.pem ubuntu@${aws_instance.uptime_kuma.public_ip}"
}

output "nameservers" {
  description = "Nameservers for the subdomain. Add these as NS records in the parent zone."
  value       = aws_route53_zone.status.name_servers
} 