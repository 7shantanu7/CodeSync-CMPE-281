# Quick Start Guide

This guide will get you from zero to deployed in ~30 minutes.

## Prerequisites Checklist

- [ ] AWS Account
- [ ] AWS CLI installed (`aws --version`)
- [ ] AWS CLI configured (`aws configure`)
- [ ] Terraform installed (`terraform --version`)
- [ ] Docker installed (`docker --version`)

## Step-by-Step Deployment

### 1. Create JWT Secret (2 minutes)

```bash
# Generate and store secret
JWT_SECRET=$(openssl rand -base64 32)
aws secretsmanager create-secret \
  --name codesync/jwt-secret \
  --secret-string "$JWT_SECRET" \
  --region us-east-1

# Copy the ARN from output!
```

### 2. Build and Push Docker Images (5 minutes)

```bash
# Set variables
export AWS_REGION="us-east-1"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create ECR repositories
aws ecr create-repository --repository-name codesync-api --region $AWS_REGION
aws ecr create-repository --repository-name codesync-websocket --region $AWS_REGION

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build and push API
cd backend/api
docker build -t codesync-api .
docker tag codesync-api:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/codesync-api:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/codesync-api:latest
cd ../..

# Build and push WebSocket
cd backend/websocket
docker build -t codesync-websocket .
docker tag codesync-websocket:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/codesync-websocket:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/codesync-websocket:latest
cd ../..
```

### 3. Configure Terraform (2 minutes)

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars - REQUIRED changes:
# 1. jwt_secret_arn = "YOUR_ARN_FROM_STEP_1"
# 2. alert_email = "your-email@example.com"

nano terraform.tfvars  # or vim, code, etc.
```

### 4. Deploy Infrastructure (20 minutes)

```bash
# Still in terraform/
terraform init
terraform apply

# Type 'yes' when prompted
# Go get coffee ☕ - this takes 15-20 minutes
```

### 5. Deploy Frontend (3 minutes)

```bash
cd ../frontend

# Get outputs from Terraform
export ALB_DNS=$(cd ../terraform && terraform output -raw alb_dns_name)
export FRONTEND_BUCKET=$(cd ../terraform && terraform output -raw frontend_bucket_name)
export CLOUDFRONT_ID=$(cd ../terraform && terraform output -raw cloudfront_id)

# Build frontend
npm install
VITE_API_URL="http://$ALB_DNS" VITE_WS_URL="http://$ALB_DNS" npm run build

# Upload to S3
aws s3 sync dist/ s3://$FRONTEND_BUCKET/ --delete

# Invalidate CloudFront
aws cloudfront create-invalidation --distribution-id $CLOUDFRONT_ID --paths "/*"
```

### 6. Access Your Application

```bash
# Get CloudFront URL
cd ../terraform
terraform output cloudfront_url

# Open in browser!
```

## First Use

1. Click "Register" and create an account
2. Create a new document
3. Start coding!

## Cleanup (When Done)

```bash
cd terraform
terraform destroy
# Type 'yes' to confirm
```

## Troubleshooting

### "Error: creating ECS Service"
- Wait a few minutes, ECS tasks might still be starting
- Check logs: `aws logs tail /ecs/codesync-dev-api --follow`

### "Cannot connect to WebSocket"
- Ensure both API and WebSocket services are healthy
- Check ALB target groups in AWS Console

### "Database connection failed"
- RDS takes the longest to provision (~10 min)
- Check RDS status: `aws rds describe-db-instances`

### High AWS Charges
For development, use smallest instances:
```hcl
db_instance_class = "db.t3.micro"
redis_node_type   = "cache.t3.micro"
api_min_capacity  = 1  # Instead of 2
websocket_min_capacity = 1
```

## Cost Estimate

**Development Setup** (~$50-80/month):
- RDS db.t3.micro Multi-AZ: ~$30
- ElastiCache (2x cache.t3.micro): ~$25
- ECS Fargate (4 tasks): ~$15
- ALB: ~$20
- S3 + CloudFront: ~$5
- Data Transfer: ~$5

**Cost Saving Tips:**
1. Stop services when not in use (destroy infrastructure)
2. Use single AZ for dev (set `multi_az = false`)
3. Reduce min_capacity to 1 for both services
4. Use RDS dev/test pricing tier

## Need Help?

Check the full [README.md](README.md) for detailed instructions and troubleshooting.

