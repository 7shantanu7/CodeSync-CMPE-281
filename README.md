# CodeSync - Real-Time Collaborative Code Editor

A production-ready, real-time collaborative code editor built with modern web technologies and deployed on AWS with a resilient, scalable infrastructure.

## 🏗️ Architecture Overview

**Tech Stack:**
- **Frontend**: React + TypeScript + Monaco Editor
- **Backend API**: Node.js + Express + PostgreSQL
- **WebSocket Service**: Node.js + Socket.io + Redis
- **Infrastructure**: AWS (ECS Fargate, RDS, ElastiCache, S3, CloudFront, ALB)
- **IaC**: Terraform

**Key Features:**
- ✅ Auto-scaling ECS services based on CPU and memory
- ✅ Health checks, automatic failover, and self-healing
- ✅ Multi-AZ deployment with eliminated SPOFs
- ✅ CloudFront CDN, Redis caching, connection pooling

![Infrastructure Architecture Diagram](images/Infrastructure%20Architecture%20Diagram.png)

## 📋 Prerequisites

- AWS Account with appropriate permissions
- AWS CLI configured (`aws configure`)
- Terraform >= 1.0
- Docker
- Node.js >= 18

## 🚀 Quick Deployment

### 1. Create JWT Secret

```bash
JWT_SECRET=$(openssl rand -base64 32)
aws secretsmanager create-secret \
  --name codesync/jwt-secret \
  --secret-string "$JWT_SECRET" \
  --region us-east-1
```

### 2. Build and Push Docker Images

```bash
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

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

# Build and push WebSocket
cd ../websocket
docker build -t codesync-websocket .
docker tag codesync-websocket:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/codesync-websocket:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/codesync-websocket:latest
cd ../..
```

### 3. Configure and Deploy Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

terraform init
terraform plan
terraform apply
```

Key variables in `terraform.tfvars`:

```hcl
aws_region   = "us-east-1"
project_name = "codesync"
environment  = "dev"

jwt_secret_arn = "arn:aws:secretsmanager:us-east-1:ACCOUNT_ID:secret:codesync/jwt-secret-XXXXX"
alert_email    = "your-email@example.com"
```

### 4. Deploy Frontend

```bash
cd ../frontend
npm install

# Set API URLs from Terraform outputs
export VITE_API_URL="http://YOUR_ALB_DNS"
export VITE_WS_URL="http://YOUR_ALB_DNS"

npm run build

# Upload to S3
FRONTEND_BUCKET=$(cd ../terraform && terraform output -raw frontend_bucket_name)
aws s3 sync dist/ s3://$FRONTEND_BUCKET/ --delete

# Invalidate CloudFront cache
CLOUDFRONT_ID=$(cd ../terraform && terraform output -raw cloudfront_id)
aws cloudfront create-invalidation --distribution-id $CLOUDFRONT_ID --paths "/*"
```

### 5. Verify Deployment

```bash
# Get CloudFront URL
CLOUDFRONT_URL=$(cd terraform && terraform output -raw cloudfront_url)
echo "Application available at: $CLOUDFRONT_URL"

# Test health endpoints
ALB_DNS=$(cd terraform && terraform output -raw alb_dns_name)
curl http://$ALB_DNS/api/health
curl http://$ALB_DNS/socket/health
```

## 📊 Monitoring

**CloudWatch Dashboard:** AWS Console → CloudWatch → Dashboards → `codesync-dev-dashboard`

**Configured Alarms:**
- ALB high response time, 5XX errors, unhealthy hosts
- ECS CPU/Memory high
- RDS CPU high, storage low
- Redis CPU/Memory high

**View Logs:**

```bash
aws logs tail /ecs/codesync-dev-api --follow
aws logs tail /ecs/codesync-dev-websocket --follow
```

## 🧪 Application Usage

### User Registration & Login

![User Registration & Login Flow](images/User%20Registration%20%26%20Login%20Flow.png)

### Create & Join Documents

![Create & Join Collaborative Document](images/Create%20%26%20Join%20Collaborative%20Document.png)

### Real-Time Collaboration

![Real-Time Collaborative Editing](images/Real-Time%20Collaborative%20Editing.png)

## 🔄 Updates

**Update Backend Services:**

```bash
cd backend/api  # or backend/websocket
docker build -t codesync-api .
docker tag codesync-api:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/codesync-api:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/codesync-api:latest

aws ecs update-service \
  --cluster codesync-dev-cluster \
  --service codesync-dev-api \
  --force-new-deployment \
  --region us-east-1
```

**Update Frontend:**

```bash
cd frontend
npm run build
aws s3 sync dist/ s3://$FRONTEND_BUCKET/ --delete
aws cloudfront create-invalidation --distribution-id $CLOUDFRONT_ID --paths "/*"
```

## 🧹 Cleanup

```bash
cd terraform
terraform destroy
```

**Warning:** This deletes all data. Consider backing up first:

```bash
aws rds create-db-snapshot \
  --db-instance-identifier codesync-dev-db \
  --db-snapshot-identifier codesync-dev-final-snapshot
```

## 📈 Scaling

**Current Dev Setup:**
- API/WebSocket: 2-10 tasks (512 CPU, 1GB RAM)
- Database: db.t3.micro (Multi-AZ)
- Cache: cache.t3.micro (2 nodes)

**Production Recommendations:**

```hcl
db_instance_class = "db.t3.medium"
redis_node_type   = "cache.t3.medium"

api_desired_count = 4
api_min_capacity  = 4
api_max_capacity  = 50

api_cpu    = 1024
api_memory = 2048
```

## 📝 Local Development

```bash
# Start PostgreSQL and Redis
docker run -d -p 5432:5432 -e POSTGRES_PASSWORD=postgres postgres:15
docker run -d -p 6379:6379 redis:7-alpine

# API Service
cd backend/api
npm install
npm run dev

# WebSocket Service
cd backend/websocket
npm install
npm run dev

# Frontend
cd frontend
npm install
npm run dev  # Available at http://localhost:3000
```

## 👤 Author

Created by Shantanu Zadbuke for CMPE 281 - San Jose State University
