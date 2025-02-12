# ECS Security Group
resource "aws_security_group" "uptime_kuma" {
  name        = "uptime-kuma-sg-${random_string.suffix.result}"
  description = "Security group for Uptime Kuma EC2 instance"
  vpc_id      = aws_vpc.main.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  # Uptime Kuma web interface
  ingress {
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Uptime Kuma web access"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "uptime-kuma-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
} 