terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "three-tier-app"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "db_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "min_instances" {
  description = "Minimum number of instances"
  type        = number
  default     = 2
}

variable "max_instances" {
  description = "Maximum number of instances"
  type        = number
  default     = 4
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.app_name}-vpc"
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.app_name}-igw"
    Environment = var.environment
  }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name        = "${var.app_name}-public-subnet-1"
    Environment = var.environment
  }
}

resource "aws_subnet" "public_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.6.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name        = "${var.app_name}-public-subnet-2"
    Environment = var.environment
  }
}

resource "aws_subnet" "private_app" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name        = "${var.app_name}-private-app-subnet"
    Environment = var.environment
  }
}

resource "aws_subnet" "private_nat" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name        = "${var.app_name}-private-nat-subnet"
    Environment = var.environment
  }
}

resource "aws_subnet" "private_db_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name        = "${var.app_name}-private-db-subnet-1"
    Environment = var.environment
  }
}

resource "aws_subnet" "private_db_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name        = "${var.app_name}-private-db-subnet-2"
    Environment = var.environment
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name        = "${var.app_name}-nat-eip"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name        = "${var.app_name}-nat-gateway"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block      = "0.0.0.0/0"
    gateway_id      = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.app_name}-public-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name        = "${var.app_name}-private-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "private_app" {
  subnet_id      = aws_subnet.private_app.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_nat" {
  subnet_id      = aws_subnet.private_nat.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.app_name}-private-db-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "private_db_1" {
  subnet_id      = aws_subnet.private_db_1.id
  route_table_id = aws_route_table.private_db.id
}

resource "aws_route_table_association" "private_db_2" {
  subnet_id      = aws_subnet.private_db_2.id
  route_table_id = aws_route_table.private_db.id
}

resource "aws_security_group" "alb" {
  name   = "${var.app_name}-alb-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.app_name}-alb-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "ec2" {
  name   = "${var.app_name}-ec2-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.app_name}-ec2-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "rds" {
  name   = "${var.app_name}-rds-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.app_name}-rds-sg"
    Environment = var.environment
  }
}

resource "aws_lb" "main" {
  name               = "${var.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public.id, aws_subnet.public_2.id]

  tags = {
    Name        = "${var.app_name}-alb"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "main" {
  name        = "${var.app_name}-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    path                = "/"
    matcher             = "200"
  }

  tags = {
    Name        = "${var.app_name}-tg"
    Environment = var.environment
  }
}

resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

resource "aws_wafv2_web_acl" "main" {
  provider = aws.us_east_1
  name     = "${var.app_name}-waf"
  scope    = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 0

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSetMetrics"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSetMetrics"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesAmazonIpReputationListMetrics"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "RateLimitRule"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRuleMetrics"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.app_name}-waf-metrics"
    sampled_requests_enabled   = true
  }

  tags = {
    Name        = "${var.app_name}-waf"
    Environment = var.environment
  }
}

resource "aws_wafv2_web_acl" "alb" {
  name  = "${var.app_name}-waf-alb"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 0

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSetMetricsALB"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.app_name}-waf-alb-metrics"
    sampled_requests_enabled   = true
  }

  tags = {
    Name        = "${var.app_name}-waf-alb"
    Environment = var.environment
  }
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.alb.arn
}

resource "aws_s3_bucket" "cloudfront_logs" {
  bucket = "${var.app_name}-cf-logs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "${var.app_name}-cf-logs"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_ownership_controls" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_policy" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontLogs"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudfront_logs.arn}/*"
      },
      {
        Sid    = "AllowCloudFrontGetBucketAcl"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudfront_logs.arn
      }
    ]
  })
}

resource "aws_s3_bucket_versioning" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_cloudfront_distribution" "main" {
  provider = aws.us_east_1
  origin {
    domain_name = aws_lb.main.dns_name
    origin_id   = "ALB"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled = true
  
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution for ${var.app_name}"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "ALB"

    forwarded_values {
      query_string = true

      cookies {
        forward = "all"
      }

      headers = ["*"]
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    compress               = true
  }

  ordered_cache_behavior {
    path_pattern     = "/health"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "ALB"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 300
    max_ttl                = 600
    compress               = true
  }

  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "ALB"

    forwarded_values {
      query_string = true

      cookies {
        forward = "all"
      }

      headers = [
        "Authorization",
        "Host",
        "User-Agent",
        "Cloudfront-Forwarded-Proto",
        "Content-Type"
      ]
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.cloudfront_logs.bucket_regional_domain_name
    prefix          = "cloudfront-logs"
  }

  web_acl_id = aws_wafv2_web_acl.main.arn

  depends_on = [aws_lb.main, aws_s3_bucket_policy.cloudfront_logs]

  tags = {
    Name        = "${var.app_name}-cloudfront"
    Environment = var.environment
  }
}

resource "aws_cloudfront_origin_access_identity" "app" {
  provider = aws.us_east_1
  comment  = "OAI for ${var.app_name}"
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "${var.app_name}-ec2-role"

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
    Name        = "${var.app_name}-ec2-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "ec2_s3_policy" {
  name = "${var.app_name}-ec2-s3-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.app.arn,
          "${aws_s3_bucket.app.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.app_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

locals {
  user_data_script = base64encode(<<-USERDATA
#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log)
exec 2>&1
echo "=== Starting deployment ==="
sleep 10
yum update -y
yum install -y curl wget git
export HOME=/root
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm install 16
nvm use 16
nvm alias default 16
node --version
npm --version
mkdir -p /opt/app
cd /opt/app
cat > package.json << 'EOF'
{
  "name": "three-tier-app",
  "version": "1.0.0",
  "main": "server.js",
  "dependencies": {
    "express": "^4.18.2",
    "mysql2": "^3.6.2",
    "aws-sdk": "^2.1500.0",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1"
  }
}
EOF
npm install --production
cat > .env << 'ENVEOF'
NODE_ENV=production
PORT=3000
DB_HOST=${aws_db_instance.main.address}
DB_PORT=3306
DB_NAME=${aws_db_instance.main.db_name}
DB_USER=${var.db_username}
DB_PASSWORD=${var.db_password}
S3_BUCKET=${aws_s3_bucket.app.id}
AWS_REGION=${var.aws_region}
ENVEOF
cat > start.sh << 'STARTEOF'
#!/bin/bash
set -x
exec 2>&1
export HOME=/root
export NVM_DIR="/root/.nvm"
echo "=== Starting Node.js application ==="
echo "Current user: $(whoami)"
echo "Working directory: $(pwd)"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  . "$NVM_DIR/nvm.sh"
  echo "NVM sourced successfully"
else
  echo "ERROR: NVM script not found"
  exit 1
fi
echo "Node version: $(node --version)"
echo "NPM version: $(npm --version)"
if [ -f /opt/app/.env ]; then
  echo ".env file found"
else
  echo "ERROR: .env file not found"
  exit 1
fi
if [ -d /opt/app/node_modules ]; then
  echo "node_modules directory found"
else
  echo "ERROR: node_modules not found"
  exit 1
fi
if [ -f /opt/app/server.js ]; then
  echo "server.js found"
else
  echo "ERROR: server.js not found"
  exit 1
fi
echo "=== All checks passed ==="
cd /opt/app
exec node server.js
STARTEOF
chmod +x start.sh
mkdir -p public
cat > server.js << 'SERVEREOF'
require('dotenv').config();
const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');
const path = require('path');
console.log('Starting server...');
console.log('DB_HOST:', process.env.DB_HOST);
console.log('DB_PORT:', process.env.DB_PORT);
const app = express();
app.use(cors());
app.use(express.json());
app.use(express.static('public'));
const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT||3306),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  connectionLimit: 5,
  waitForConnections: true,
  queueLimit: 0
});
let dbReady = false;
async function initDb() {
  console.log('Initializing database...');
  let retries = 0;
  while(retries < 30) {
    try {
      const conn = await pool.getConnection();
      await conn.execute('CREATE TABLE IF NOT EXISTS users(id INT AUTO_INCREMENT PRIMARY KEY,name VARCHAR(255) NOT NULL,email VARCHAR(255) UNIQUE,phone VARCHAR(20),address VARCHAR(500),created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)');
      conn.release();
      console.log('Database initialized successfully');
      dbReady = true;
      return;
    } catch(e) {
      retries++;
      console.log('Database connection attempt ' + retries + '/30 failed:', e.message);
      if(retries >= 30) throw e;
      await new Promise(r => setTimeout(r, 2000));
    }
  }
}
app.get('/health',(r,s)=>s.json({status:'healthy',db:dbReady}));
app.get('/api/users',async(r,s)=>{if(!dbReady)return s.status(503).json({error:'db not ready'});try{const c=await pool.getConnection();const[rows]=await c.execute('SELECT * FROM users');c.release();s.json(rows);}catch(e){console.error(e);s.status(500).json({error:e.message});}});
app.get('/api/users/:id',async(r,s)=>{if(!dbReady)return s.status(503).json({error:'db not ready'});try{const c=await pool.getConnection();const[rows]=await c.execute('SELECT * FROM users WHERE id=?',[r.params.id]);c.release();if(!rows.length)return s.status(404).json({error:'not found'});s.json(rows[0]);}catch(e){console.error(e);s.status(500).json({error:e.message});}});
app.post('/api/users',async(r,s)=>{if(!dbReady)return s.status(503).json({error:'db not ready'});const{name,email,phone,address}=r.body;if(!name||!email)return s.status(400).json({error:'required'});try{const c=await pool.getConnection();const[result]=await c.execute('INSERT INTO users(name,email,phone,address)VALUES(?,?,?,?)',[name,email,phone||null,address||null]);c.release();s.status(201).json({id:result.insertId,name,email,phone,address});}catch(e){console.error(e);s.status(500).json({error:e.message});}});
app.put('/api/users/:id',async(r,s)=>{if(!dbReady)return s.status(503).json({error:'db not ready'});const{name,email,phone,address}=r.body;try{const c=await pool.getConnection();await c.execute('UPDATE users SET name=?,email=?,phone=?,address=? WHERE id=?',[name,email,phone||null,address||null,r.params.id]);c.release();s.json({id:r.params.id,name,email,phone,address});}catch(e){console.error(e);s.status(500).json({error:e.message});}});
app.delete('/api/users/:id',async(r,s)=>{if(!dbReady)return s.status(503).json({error:'db not ready'});try{const c=await pool.getConnection();const[result]=await c.execute('DELETE FROM users WHERE id=?',[r.params.id]);c.release();if(!result.affectedRows)return s.status(404).json({error:'not found'});s.json({message:'deleted'});}catch(e){console.error(e);s.status(500).json({error:e.message});}});
app.get('/',(r,s)=>s.sendFile(path.join(__dirname,'public','index.html')));
const PORT=process.env.PORT||3000;
initDb().then(()=>{app.listen(PORT,()=>console.log('Server listening on port '+PORT));}).catch(e=>{console.error('Database init failed:',e);process.exit(1);});
SERVEREOF
cat > public/index.html << 'HTMLEOF'
<!DOCTYPE html><html><head><meta charset=UTF-8><meta name=viewport content="width=device-width"><title>Three-Tier App</title><style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:Arial;background:linear-gradient(135deg,#667eea,#764ba2);min-height:100vh;padding:20px}.container{max-width:1200px;margin:0 auto}header{text-align:center;color:#fff;margin-bottom:40px}h1{font-size:2.5em}h2{color:#667eea;margin:20px 0}form,#userList{background:#fff;padding:20px;border-radius:10px;margin:20px 0}input,textarea{width:100%;padding:10px;margin:5px 0;border:1px solid #ddd;border-radius:5px}button{background:#667eea;color:#fff;border:none;padding:10px 20px;border-radius:5px;cursor:pointer;width:100%}button:hover{background:#764ba2}.user-item{background:#f8f9fa;padding:15px;margin:10px 0;border-left:4px solid #667eea}.msg{padding:10px;margin:10px 0;border-radius:5px;display:none}.msg.success{background:#d4edda;color:#155724;display:block}.msg.error{background:#f8d7da;color:#721c24;display:block}.status{background:#fff;padding:20px;margin:20px 0;border-radius:10px}</style></head><body><div class=container><header><h1>AWS Three-Tier App</h1><p>User Management</p></header><h2>Add User</h2><div id=msg class=msg></div><form id=form><input type=text id=name placeholder=Name required><input type=email id=email placeholder=Email required><input type=tel id=phone placeholder=Phone><textarea id=address placeholder=Address rows=3></textarea><button type=submit>Add User</button></form><h2>Users</h2><div id=userList></div><div class=status><div>Status: <strong id=status>Loading...</strong></div><div>Total: <strong id=count>0</strong></div></div></div><script>const API='/api';function msg(t,type){const e=document.getElementById('msg');e.textContent=t;e.className='msg '+type;setTimeout(()=>{e.className='msg'},5000)}async function load(){try{const r=await fetch(API+'/users');const d=await r.json();const h=d.map(u=>'<div class="user-item"><strong>'+u.name+'</strong><br>'+u.email+(u.phone?'<br>'+u.phone:'')+'<br><button onclick=del('+u.id+')>Delete</button></div>').join('');document.getElementById('userList').innerHTML=h||'<p>No users</p>';document.getElementById('count').textContent=d.length;document.getElementById('status').textContent='Connected';}catch(e){document.getElementById('status').textContent='Error'}}async function del(id){if(!confirm('Delete?'))return;try{await fetch(API+'/users/'+id,{method:'DELETE'});msg('Deleted!','success');load();}catch(e){msg('Error','error')}}document.getElementById('form').addEventListener('submit',async e=>{e.preventDefault();try{const r=await fetch(API+'/users',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({name:document.getElementById('name').value,email:document.getElementById('email').value,phone:document.getElementById('phone').value,address:document.getElementById('address').value})});if(r.ok){msg('Added!','success');document.getElementById('form').reset();load();}else msg('Error','error');}catch(e){msg('Error','error')}});load();setInterval(load,30000);</script></body></html>
HTMLEOF
cat > /etc/systemd/system/app.service << 'SVCEOF'
[Unit]
Description=Three-Tier App
After=network.target
[Service]
Type=simple
User=root
WorkingDirectory=/opt/app
EnvironmentFile=/opt/app/.env
ExecStart=/opt/app/start.sh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=app
TimeoutStartSec=60
[Install]
WantedBy=multi-user.target
SVCEOF
systemctl daemon-reload
systemctl enable app
systemctl start app
sleep 10
systemctl status app
journalctl -u app -n 100 -e
echo "=== DEPLOYMENT COMPLETE ===" >> /var/log/user-data.log
  USERDATA
)
}

resource "aws_launch_template" "app" {
  name_prefix   = "${var.app_name}-lt-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  vpc_security_group_ids = [aws_security_group.ec2.id]

  user_data = local.user_data_script

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.app_name}-instance"
      Environment = var.environment
    }
  }
}

resource "aws_autoscaling_group" "app" {
  name                = "${var.app_name}-asg"
  vpc_zone_identifier = [aws_subnet.private_app.id, aws_subnet.private_nat.id]
  target_group_arns   = [aws_lb_target_group.main.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300

  min_size         = var.min_instances
  max_size         = var.max_instances
  desired_capacity = var.min_instances

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.app_name}-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.app_name}-db-subnet-group"
  subnet_ids = [aws_subnet.private_db_1.id, aws_subnet.private_db_2.id]

  tags = {
    Name        = "${var.app_name}-db-subnet-group"
    Environment = var.environment
  }
}

resource "aws_db_instance" "main" {
  identifier     = "${var.app_name}-db"
  engine         = "mariadb"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  storage_type          = "gp3"
  storage_encrypted     = true
  multi_az              = true

  db_name  = "appdb"
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.app_name}-db-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  tags = {
    Name        = "${var.app_name}-db"
    Environment = var.environment
  }
}

resource "aws_s3_bucket" "app" {
  bucket = "${var.app_name}-bucket-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "${var.app_name}-bucket"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "app" {
  bucket = aws_s3_bucket.app.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app" {
  bucket = aws_s3_bucket.app.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "app" {
  bucket = aws_s3_bucket.app.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.s3"

  route_table_ids = [
    aws_route_table.private.id,
    aws_route_table.private_db.id
  ]

  tags = {
    Name        = "${var.app_name}-s3-endpoint"
    Environment = var.environment
  }
}

data "aws_caller_identity" "current" {}

output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "DNS name of the load balancer"
}

output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.main.domain_name
  description = "CloudFront distribution domain name"
}

output "cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.main.id
  description = "CloudFront distribution ID"
}

output "waf_acl_arn" {
  value       = aws_wafv2_web_acl.main.arn
  description = "WAF Web ACL ARN"
}

output "rds_endpoint" {
  value       = aws_db_instance.main.endpoint
  description = "RDS database endpoint"
  sensitive   = true
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.app.id
  description = "S3 bucket name"
}

output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPC ID"
}

output "autoscaling_group_name" {
  value       = aws_autoscaling_group.app.name
  description = "Auto Scaling Group name"
}