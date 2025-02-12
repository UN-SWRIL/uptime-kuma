variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "key_name" {
  description = "Name of the SSH key pair to use for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "volume_size" {
  description = "Size of the root volume in GB"
  type        = number
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
}

variable "container_cpu" {
  description = "CPU units for the container (1024 = 1 vCPU)"
  type        = number
  default     = 256
}

variable "container_memory" {
  description = "Memory for the container in MiB"
  type        = number
  default     = 512
}

variable "service_desired_count" {
  description = "Desired number of tasks running in the service"
  type        = number
  default     = 1
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "uptimekuma"
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "db_user" {
  description = "Database username"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432 # Default PostgreSQL port
}

variable "domain_name" {
  description = "Domain name for the Uptime Kuma instance"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID"
  type        = string
} 