```markdown
# AWS Three-Tier Architecture (Terraform + Shell)

A compact, opinionated reference implementation of a three‑tier architecture on AWS using Terraform (HCL) and small supporting shell scripts. This repo sets up a VPC with public and private subnets, an application tier (EC2 or ASG behind a load balancer), and a data tier (RDS). Use this as a starting template for learning, demos, or as the basis for production hardening.

![three-tier-app](https://github.com/user-attachments/assets/41b901b3-0f22-4f43-b7a6-a5d4b9b44127)

---

Table of contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Repository layout](#repository-layout)
- [Quick start](#quick-start)
- [Variables and secrets](#variables-and-secrets)
- [Common commands](#common-commands)
- [Testing and validation](#testing-and-validation)
- [Cleanup / destroy](#cleanup--destroy)
- [Cost & security notes](#cost--security-notes)
- [Contributing](#contributing)
- [License & contact](#license--contact)

Overview
This repository codifies the classic three‑tier pattern:
- Presentation: Internet-facing Load Balancer in public subnets
- Application: EC2 instances or Auto Scaling Group in private subnets
- Data: RDS instance(s) in isolated private DB subnets

Optionally include a bastion/jump host in public subnets for SSH into private instances.

Architecture (logical)
Internet
  ↓
[ALB / ELB]  — public subnets
  ↓
[App servers (EC2/ASG)] — private subnets
  ↓
[RDS / DB] — private DB subnets

Security groups are scoped so only the ALB can reach app servers and only app servers can reach RDS.

Prerequisites
- AWS account with permissions to create VPC, EC2, ELB/ALB, RDS, IAM, S3 (if using remote state), etc.
- Terraform v1.x (check provider blocks for specific versions)
- AWS CLI (optional, for convenience)
- An SSH key pair in the target AWS region (for EC2 access)
- Optional: jq, curl (used by helper scripts)
- Optional: S3 + DynamoDB for remote state and lock

Repository layout
- main.tf, variables.tf, outputs.tf — top-level Terraform that wires modules together
- modules/
  - network/ — VPC, subnets, routing, NAT, IGW
  - app/ — EC2 / ASG, launch templates, user-data
  - db/ — RDS instance(s) and subnet group
- scripts/ — helper shell scripts (bootstrap, tests, etc.)
- examples/ — environment examples or opinionated deploy folders
- README.md — this file

Quick start (local test)
1. Clone:
   git clone https://github.com/muralikrishna-sunkara/aws-three-tier-architecture.git
   cd aws-three-tier-architecture

2. Configure AWS credentials:
   export AWS_ACCESS_KEY_ID=...
   export AWS_SECRET_ACCESS_KEY=...
   export AWS_DEFAULT_REGION=us-east-1

   Or use aws configure and an AWS profile. If you use profiles with Terraform, set TF_VAR_aws_profile or provider config accordingly.

3. Set variables:
   - Create terraform.tfvars (gitignored) or pass -var/-var-file on the CLI.
   - Typical values: region, vpc_cidr, public_subnets, private_subnets, db_username, db_password, instance_type, key_pair_name.

   Example terraform.tfvars (do NOT commit this file):
   ```hcl
   region = "us-east-1"
   vpc_cidr = "10.0.0.0/16"
   public_subnets = ["10.0.1.0/24","10.0.2.0/24"]
   private_subnets = ["10.0.11.0/24","10.0.12.0/24"]
   db_username = "dbadmin"
   db_password = "REPLACE_WITH_SECRET"
   instance_type = "t3.micro"
   key_pair_name = "my-ssh-key"
   ```

4. Initialize and apply:
   terraform init
   terraform plan -out=tfplan
   terraform apply "tfplan"

5. After apply:
   - Use terraform output to find ALB DNS, DB endpoint, and other values.
   - Access the application via the ALB DNS (if app health checks are healthy).

Variables and secrets
- Never commit secret values. Use one of:
  - gitignored terraform.tfvars
  - environment variables (TF_VAR_*)
  - AWS Secrets Manager or SSM Parameter Store
- For team usage, enable remote state in S3 and DynamoDB locking.

Common commands
- terraform init
- terraform validate
- terraform plan -out=tfplan
- terraform apply tfplan
- terraform destroy -var-file="terraform.tfvars"
- ./scripts/bootstrap.sh (check scripts/ for exact helpers)

Testing & validation
- terraform validate
- Check ALB target group health in the AWS Console
- Use curl to test the ALB:
  curl http://<alb-dns>
- Test DB connectivity from app instances or a bastion using psql/mysql client (do not expose DB publicly)

Cleanup / destroy
- terraform destroy -var-file="terraform.tfvars"
- Remove any manually created resources (e.g., S3 buckets with objects) before final deletion to avoid failures.

Cost & security notes
- Resources (EC2, ALB, RDS) incur cost. Use small instance types for dev/test and destroy when done.
- Follow these security best practices:
  - Least-privilege IAM roles for automation
  - TLS on ALB listeners and between layers where possible
  - Secrets stored in Secrets Manager / SSM, not plaintext in code
  - Enable CloudTrail, GuardDuty, Config for production environments

Contributing
- Issues and PRs welcome. If you change module interfaces, update docs and examples.
- Use feature branches and include testing notes in PR descriptions.

License & contact
- See the repository license file (if present). If no LICENSE is included, contact the repo owner: muralikrishna-sunkara.

Acknowledgements
- Based on common cloud patterns and Terraform best practices.

```
