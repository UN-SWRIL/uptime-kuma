provider "aws" {
  region = var.aws_region
}

# EC2 instance
resource "aws_instance" "uptime_kuma" {
  ami           = "ami-0c7217cdde317cfec"  # Ubuntu 22.04 LTS in us-east-1
  instance_type = var.instance_type
  subnet_id     = aws_subnet.main.id

  vpc_security_group_ids = [aws_security_group.uptime_kuma.id]
  key_name              = var.key_name
  iam_instance_profile  = aws_iam_instance_profile.ec2_backup_profile.name

  root_block_device {
    volume_size = var.volume_size
    volume_type = "gp3"
  }

  user_data = <<-EOF
              #!/bin/bash
              # Update and install Docker
              apt-get update
              apt-get install -y apt-transport-https ca-certificates curl software-properties-common
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
              add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
              apt-get update
              apt-get install -y docker-ce docker-ce-cli containerd.io

              # Start Docker service
              systemctl start docker
              systemctl enable docker

              # Create Docker volume and run Uptime Kuma
              docker volume create uptime-kuma
              docker run -d \
                --restart=always \
                -p 3001:3001 \
                -v uptime-kuma:/app/data \
                --name uptime-kuma \
                louislam/uptime-kuma:1

              # Wait for container to be ready
              sleep 30

              # Verify container is running
              docker ps | grep uptime-kuma
              EOF

  tags = {
    Name        = "uptime-kuma"
    Environment = var.environment
  }
}

# Create a hosted zone for the subdomain in the current account
resource "aws_route53_zone" "status" {
  name = var.domain_name
  
  tags = {
    Name        = "status-qolimpact-zone"
    Environment = var.environment
  }
} 