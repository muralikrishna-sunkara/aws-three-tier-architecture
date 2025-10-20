# output "alb_dns_name" {
#   value       = aws_lb.main.dns_name
#   description = "DNS name of the load balancer"
# }

# output "cloudfront_domain_name" {
#   value       = aws_cloudfront_distribution.main.domain_name
#   description = "CloudFront distribution domain name"
# }

# output "cloudfront_distribution_id" {
#   value       = aws_cloudfront_distribution.main.id
#   description = "CloudFront distribution ID"
# }

# output "waf_acl_arn" {
#   value       = aws_wafv2_web_acl.main.arn
#   description = "WAF Web ACL ARN"
# }

# output "rds_endpoint" {
#   value       = aws_db_instance.main.endpoint
#   description = "RDS database endpoint"
#   sensitive   = true
# }

# output "s3_bucket_name" {
#   value       = aws_s3_bucket.app.id
#   description = "S3 bucket name"
# }

# output "vpc_id" {
#   value       = aws_vpc.main.id
#   description = "VPC ID"
# }

# output "autoscaling_group_name" {
#   value       = aws_autoscaling_group.app.name
#   description = "Auto Scaling Group name"
# }