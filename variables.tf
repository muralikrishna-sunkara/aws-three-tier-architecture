# variable "aws_region" {
#   description = "AWS region"
#   type        = string
#   default     = "eu-central-1"
# }

# variable "environment" {
#   description = "Environment name"
#   type        = string
#   default     = "prod"
# }

# variable "app_name" {
#   description = "Application name"
#   type        = string
#   default     = "three-tier-app"
# }

# variable "vpc_cidr" {
#   description = "VPC CIDR block"
#   type        = string
#   default     = "10.0.0.0/16"
# }

# variable "db_username" {
#   description = "RDS master username"
#   type        = string
#   default     = "admin"
#   sensitive   = true
# }

# variable "db_password" {
#   description = "RDS master password"
#   type        = string
#   sensitive   = true
# }

# variable "instance_type" {
#   description = "EC2 instance type"
#   type        = string
#   default     = "t3.micro"
# }

# variable "min_instances" {
#   description = "Minimum number of instances"
#   type        = number
#   default     = 2
# }

# variable "max_instances" {
#   description = "Maximum number of instances"
#   type        = number
#   default     = 4
# }