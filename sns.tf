# SNS Topic for backup notifications
resource "aws_sns_topic" "backup_notifications" {
  name = "un-swril-backup-notifications"
  
  tags = {
    Name        = "UN-SWRIL Backup Notifications"
    Environment = var.environment
  }
}

# SNS Topic Policy to allow EC2 instance to publish
resource "aws_sns_topic_policy" "backup_notifications" {
  arn = aws_sns_topic.backup_notifications.arn
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.ec2_backup_role.arn
        }
        Action = "SNS:Publish"
        Resource = aws_sns_topic.backup_notifications.arn
      }
    ]
  })
}

# Email subscriptions for backup notifications
resource "aws_sns_topic_subscription" "salman_email" {
  topic_arn = aws_sns_topic.backup_notifications.arn
  protocol  = "email"
  endpoint  = "salman.naqvi@gmail.com"
}

resource "aws_sns_topic_subscription" "dipto_email" {
  topic_arn = aws_sns_topic.backup_notifications.arn
  protocol  = "email"
  endpoint  = "diptobiswas0007@gmail.com"
}

# IAM role for EC2 instance to access SNS
resource "aws_iam_role" "ec2_backup_role" {
  name = "ec2-backup-role"
  
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
  
  tags = {
    Name        = "EC2 Backup Role"
    Environment = var.environment
  }
}

# IAM policy for SNS access
resource "aws_iam_role_policy" "ec2_sns_policy" {
  name = "ec2-sns-backup-policy"
  role = aws_iam_role.ec2_backup_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.backup_notifications.arn
      }
    ]
  })
}

# IAM instance profile for EC2
resource "aws_iam_instance_profile" "ec2_backup_profile" {
  name = "ec2-backup-profile"
  role = aws_iam_role.ec2_backup_role.name
}

# Output the SNS topic ARN for use in backup script
output "sns_topic_arn" {
  value = aws_sns_topic.backup_notifications.arn
  description = "ARN of the SNS topic for backup notifications"
}
