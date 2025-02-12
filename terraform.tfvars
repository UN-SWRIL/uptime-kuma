# Required AWS configuration
aws_region = "us-east-1"
key_name   = "salman-dev"

# EC2 configuration
instance_type = "t2.micro"
volume_size   = 10
environment   = "production"

# Database configuration
db_user     = "uptimekuma"
db_password = "your_secure_password_here"
db_name     = "uptimekuma"
db_port     = 5432

# Domain configuration
domain_name    = "status.qolimpact.com"
hosted_zone_id = "Z0550029CQUE8GW3DPTH"  # Get this from Route 53