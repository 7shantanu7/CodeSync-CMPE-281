# CodeSync - Real-Time Collaborative Code Editor

A production-ready, real-time collaborative code editor built with modern web technologies and deployed on AWS with a resilient, scalable infrastructure.

## 📚 Documentation

- **[Design Document](DESIGN.md)** - Comprehensive architecture and design decisions
- **[Deployment Guide](#deployment-instructions)** - Step-by-step deployment instructions

## 🏗️ Architecture Overview

CodeSync is built with:
- **Frontend**: React + TypeScript + Monaco Editor
- **Backend API**: Node.js + Express + PostgreSQL
- **WebSocket Service**: Node.js + Socket.io + Redis
- **Infrastructure**: AWS (ECS Fargate, RDS, ElastiCache, S3, CloudFront, ALB)
- **IaC**: Terraform

### Key Features

✅ **Elasticity**: Auto-scaling ECS services based on CPU and memory  
✅ **Auto Recovery**: Health checks, automatic failover, and self-healing  
✅ **Failure Isolation**: Multi-AZ deployment, eliminated 5 SPOFs  
✅ **Performance**: CloudFront CDN, Redis caching, connection pooling  

## 📋 Prerequisites

Before deploying, ensure you have:

- AWS Account with appropriate permissions
- AWS CLI installed and configured (`aws configure`)
- Terraform >= 1.0 installed
- Docker installed (for building images)
- Node.js >= 18 (for local development)

## 🚀 Deployment Instructions

### Step 1: Clone Repository and Setup

```bash
# Clone the repository
git clone <your-repo-url>
cd codesync

# Or if starting fresh
# Already in the /Users/shantanu/new directory
```

### Step 2: AWS Preparation

#### 2.1 Create JWT Secret in AWS Secrets Manager

```bash
# Generate a random JWT secret
JWT_SECRET=$(openssl rand -base64 32)

# Store in AWS Secrets Manager
aws secretsmanager create-secret \
  --name codesync/jwt-secret \
  --secret-string "$JWT_SECRET" \
  --region us-east-1

# Note the ARN from the output
```

#### 2.2 (Optional) Request SSL Certificate

If you have a custom domain:

```bash
# Request certificate in us-east-1 (for CloudFront)
aws acm request-certificate \
  --domain-name "yourdomain.com" \
  --validation-method DNS \
  --region us-east-1

# Request certificate in your deployment region (for ALB)
aws acm request-certificate \
  --domain-name "api.yourdomain.com" \
  --validation-method DNS \
  --region us-east-1

# Follow DNS validation instructions
```

### Step 3: Build and Push Docker Images

#### 3.1 Create ECR Repositories

```bash
# Set variables
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create ECR repositories
aws ecr create-repository --repository-name codesync-api --region $AWS_REGION
aws ecr create-repository --repository-name codesync-websocket --region $AWS_REGION

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
```

#### 3.2 Build and Push API Service

```bash
cd backend/api

# Build Docker image
docker build -t codesync-api .

# Tag and push
docker tag codesync-api:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/codesync-api:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/codesync-api:latest

cd ../..
```

#### 3.3 Build and Push WebSocket Service

```bash
cd backend/websocket

# Build Docker image
docker build -t codesync-websocket .

# Tag and push
docker tag codesync-websocket:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/codesync-websocket:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/codesync-websocket:latest

cd ../..
```

### Step 4: Configure Terraform

#### 4.1 Create terraform.tfvars

```bash
cd terraform

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
```

Example `terraform.tfvars`:

```hcl
# General
aws_region   = "us-east-1"
project_name = "codesync"
environment  = "dev"

# Network
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]

# Database
db_username          = "codesync_admin"
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20
multi_az             = true

# Cache
redis_node_type = "cache.t3.micro"
redis_num_nodes = 2

# Services
api_cpu           = 512
api_memory        = 1024
api_desired_count = 2
api_min_capacity  = 2
api_max_capacity  = 10

websocket_cpu           = 512
websocket_memory        = 1024
websocket_desired_count = 2
websocket_min_capacity  = 2
websocket_max_capacity  = 10

# Secrets (replace with your actual ARNs)
jwt_secret_arn = "arn:aws:secretsmanager:us-east-1:ACCOUNT_ID:secret:codesync/jwt-secret-XXXXX"

# Monitoring
alert_email = "your-email@example.com"

# Optional: SSL Certificates
# certificate_arn           = "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/CERT_ID"
# cloudfront_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/CERT_ID"
```

### Step 5: Deploy Infrastructure with Terraform

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the infrastructure
terraform apply

# Confirm with 'yes' when prompted
# This will take 15-20 minutes
```

**Important**: Save the outputs:

```bash
# Save outputs to a file
terraform output > ../infrastructure-outputs.txt
```

### Step 6: Deploy Frontend to S3/CloudFront

#### 6.1 Build Frontend

```bash
cd ../frontend

# Install dependencies
npm install

# Build production bundle
# Set API URLs from Terraform outputs
export VITE_API_URL="http://YOUR_ALB_DNS"
export VITE_WS_URL="http://YOUR_ALB_DNS"

npm run build
```

#### 6.2 Upload to S3

```bash
# Get bucket name from Terraform output
FRONTEND_BUCKET=$(cd ../terraform && terraform output -raw frontend_bucket_name)

# Upload to S3
aws s3 sync dist/ s3://$FRONTEND_BUCKET/ --delete

# Invalidate CloudFront cache
CLOUDFRONT_ID=$(cd ../terraform && terraform output -raw cloudfront_id)
aws cloudfront create-invalidation \
  --distribution-id $CLOUDFRONT_ID \
  --paths "/*"
```

### Step 7: Verify Deployment

#### 7.1 Check CloudWatch Logs

```bash
# API Service logs
aws logs tail /ecs/codesync-dev-api --follow

# WebSocket Service logs
aws logs tail /ecs/codesync-dev-websocket --follow
```

#### 7.2 Test Health Endpoints

```bash
# Get ALB DNS from Terraform output
ALB_DNS=$(cd terraform && terraform output -raw alb_dns_name)

# Test API health
curl http://$ALB_DNS/api/health

# Test WebSocket health
curl http://$ALB_DNS/socket/health
```

#### 7.3 Access Application

```bash
# Get CloudFront URL
CLOUDFRONT_URL=$(cd terraform && terraform output -raw cloudfront_url)

echo "Application available at: $CLOUDFRONT_URL"
```

### Step 8: Configure SNS Alert Subscription

After deployment, confirm your SNS email subscription:

1. Check your email for AWS SNS subscription confirmation
2. Click the confirmation link
3. You'll now receive CloudWatch alerts

## 🔧 Configuration

### Environment Variables

The application uses the following environment variables (set via Terraform):

**API Service:**
- `NODE_ENV` - Environment (dev/staging/prod)
- `DB_HOST` - RDS endpoint
- `DB_NAME` - Database name
- `DB_USERNAME` - Database user
- `DB_PASSWORD` - Database password (from Secrets Manager)
- `REDIS_HOST` - ElastiCache endpoint
- `REDIS_PORT` - Redis port (6379)
- `S3_BUCKET` - Documents bucket name
- `AWS_REGION` - AWS region
- `JWT_SECRET` - JWT secret (from Secrets Manager)

**WebSocket Service:**
- Same as API Service

## 📊 Monitoring

### CloudWatch Dashboard

Access your CloudWatch dashboard:

```bash
aws cloudwatch get-dashboard \
  --dashboard-name codesync-dev-dashboard \
  --region us-east-1
```

Or visit: AWS Console → CloudWatch → Dashboards → `codesync-dev-dashboard`

### Alarms

Configured alarms:
- ALB high response time (>1s)
- ALB 5XX errors (>10 per 5 min)
- ALB unhealthy hosts
- ECS CPU high (>85%)
- ECS Memory high (>85%)
- RDS CPU high (>80%)
- RDS storage low (<2GB)
- Redis CPU high (>75%)
- Redis memory high (>80%)

### Logs

View logs:

```bash
# API logs
aws logs tail /ecs/codesync-dev-api --follow --format short

# WebSocket logs
aws logs tail /ecs/codesync-dev-websocket --follow --format short
```

## 🧪 Testing the Application

### 1. Create an Account

1. Navigate to the CloudFront URL
2. Click "Register"
3. Create an account with email and password

### 2. Create a Document

1. Login to your account
2. Click "New Document"
3. Enter a title and create

### 3. Test Real-Time Collaboration

1. Open the document in two browser windows (or share link with a friend)
2. Login with different accounts
3. Edit simultaneously and see real-time updates
4. See active users in the top-right corner

## 🔄 Updating the Application

### Update Backend Services

```bash
# Build new image
cd backend/api  # or backend/websocket
docker build -t codesync-api .

# Push to ECR
docker tag codesync-api:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/codesync-api:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/codesync-api:latest

# Force new deployment
aws ecs update-service \
  --cluster codesync-dev-cluster \
  --service codesync-dev-api \
  --force-new-deployment \
  --region us-east-1
```

### Update Frontend

```bash
cd frontend
npm run build

# Upload to S3
aws s3 sync dist/ s3://$FRONTEND_BUCKET/ --delete

# Invalidate CloudFront
aws cloudfront create-invalidation \
  --distribution-id $CLOUDFRONT_ID \
  --paths "/*"
```

### Update Infrastructure

```bash
cd terraform

# Make changes to .tf files

# Plan changes
terraform plan

# Apply changes
terraform apply
```

## 🧹 Cleanup

To avoid AWS charges, destroy all resources:

```bash
cd terraform

# Destroy all resources
terraform destroy

# Confirm with 'yes'
```

**Warning**: This will delete:
- All databases and data
- All S3 buckets and files
- All logs
- All CloudWatch alarms and dashboards

Before destroying, you may want to:

```bash
# Backup database
aws rds create-db-snapshot \
  --db-instance-identifier codesync-dev-db \
  --db-snapshot-identifier codesync-dev-final-snapshot

# Download S3 files
aws s3 sync s3://$FRONTEND_BUCKET/ ./backups/frontend/
aws s3 sync s3://$DOCUMENTS_BUCKET/ ./backups/documents/
```

## 📈 Scaling Considerations

### Current Setup (Development)

- **API Service**: 2-10 tasks (512 CPU, 1GB RAM each)
- **WebSocket Service**: 2-10 tasks (512 CPU, 1GB RAM each)
- **Database**: db.t3.micro (Multi-AZ)
- **Cache**: cache.t3.micro (2 nodes)

### Production Recommendations

```hcl
# terraform.tfvars for production

# Increase instance sizes
db_instance_class = "db.t3.medium"
redis_node_type   = "cache.t3.medium"

# Increase capacity
api_desired_count = 4
api_min_capacity  = 4
api_max_capacity  = 50

websocket_desired_count = 4
websocket_min_capacity  = 4
websocket_max_capacity  = 50

# Increase compute
api_cpu       = 1024
api_memory    = 2048
websocket_cpu = 1024
websocket_memory = 2048
```

## 🐛 Troubleshooting

### ECS Tasks Not Starting

```bash
# Check task status
aws ecs describe-tasks \
  --cluster codesync-dev-cluster \
  --tasks $(aws ecs list-tasks --cluster codesync-dev-cluster --query 'taskArns[0]' --output text)

# Check logs
aws logs tail /ecs/codesync-dev-api --follow
```

### Database Connection Issues

```bash
# Verify RDS is running
aws rds describe-db-instances \
  --db-instance-identifier codesync-dev-db

# Check security groups allow connections from ECS
```

### WebSocket Connection Failing

1. Verify WebSocket service is healthy
2. Check ALB target group health
3. Ensure sticky sessions are enabled
4. Check client authentication token

### High Costs

```bash
# Check resource usage
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE
```

Consider:
- Reducing `min_capacity` for non-production
- Using Fargate Spot for background tasks
- Reducing RDS instance size for development
- Implementing S3 lifecycle policies

## 📝 Development

### Local Development

#### API Service

```bash
cd backend/api
npm install

# Create .env file
cat > .env << EOF
NODE_ENV=development
DB_HOST=localhost
DB_PORT=5432
DB_NAME=codesync
DB_USERNAME=postgres
DB_PASSWORD=postgres
REDIS_HOST=localhost
REDIS_PORT=6379
JWT_SECRET=your-local-secret
S3_BUCKET=codesync-dev-docs
AWS_REGION=us-east-1
EOF

# Run local PostgreSQL and Redis
docker run -d -p 5432:5432 -e POSTGRES_PASSWORD=postgres postgres:15
docker run -d -p 6379:6379 redis:7-alpine

# Start service
npm run dev
```

#### WebSocket Service

```bash
cd backend/websocket
npm install

# Use same .env as API
cp ../api/.env .

# Start service
npm run dev
```

#### Frontend

```bash
cd frontend
npm install

# Start dev server (with proxy to local backend)
npm run dev
```

Access at `http://localhost:3000`

## 🎓 Project Structure

```
.
├── DESIGN.md                 # Design document
├── README.md                 # This file
├── terraform/                # Infrastructure as Code
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
│       ├── vpc/
│       ├── security/
│       ├── database/
│       ├── cache/
│       ├── storage/
│       ├── alb/
│       ├── ecs-cluster/
│       ├── ecs-service/
│       ├── cloudfront/
│       └── monitoring/
├── backend/
│   ├── api/                  # REST API service
│   │   ├── src/
│   │   ├── Dockerfile
│   │   └── package.json
│   └── websocket/           # WebSocket service
│       ├── src/
│       ├── Dockerfile
│       └── package.json
└── frontend/                # React frontend
    ├── src/
    ├── Dockerfile
    └── package.json
```

## 📚 Additional Resources

- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Socket.io Documentation](https://socket.io/docs/v4/)
- [Monaco Editor](https://microsoft.github.io/monaco-editor/)

## 🤝 Contributing

This is a college project, but suggestions are welcome!

## 📄 License

MIT License - feel free to use this for learning purposes.

## 👤 Author

Created by [Your Name] for [Course Name] - [University]
Final Project - Fall 2025

