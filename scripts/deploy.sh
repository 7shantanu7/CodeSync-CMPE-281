#!/bin/bash
set -e

# CodeSync Deployment Script
# This script automates the entire deployment process

echo "🚀 CodeSync Deployment Script"
echo "================================"

# Check prerequisites
echo "📋 Checking prerequisites..."
command -v aws >/dev/null 2>&1 || { echo "❌ AWS CLI not found. Install it first."; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo "❌ Terraform not found. Install it first."; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "❌ Docker not found. Install it first."; exit 1; }
command -v node >/dev/null 2>&1 || { echo "❌ Node.js not found. Install it first."; exit 1; }
echo "✅ All prerequisites satisfied"

# Set variables
export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)

echo ""
echo "📝 Configuration:"
echo "  AWS Region: $AWS_REGION"
echo "  AWS Account: $AWS_ACCOUNT_ID"
echo "  Project Root: $PROJECT_ROOT"
echo ""

# Step 1: Create JWT Secret
echo "🔐 Step 1: Creating JWT Secret..."
if aws secretsmanager describe-secret --secret-id codesync/jwt-secret --region $AWS_REGION >/dev/null 2>&1; then
    echo "⚠️  JWT secret already exists, skipping creation"
    JWT_SECRET_ARN=$(aws secretsmanager describe-secret --secret-id codesync/jwt-secret --region $AWS_REGION --query ARN --output text)
else
    JWT_SECRET=$(openssl rand -base64 32)
    JWT_SECRET_ARN=$(aws secretsmanager create-secret \
        --name codesync/jwt-secret \
        --secret-string "$JWT_SECRET" \
        --region $AWS_REGION \
        --query ARN --output text)
    echo "✅ JWT secret created: $JWT_SECRET_ARN"
fi

# Step 2: Create ECR repositories and push images
echo ""
echo "🐳 Step 2: Building and pushing Docker images..."

# Create ECR repositories
for repo in codesync-api codesync-websocket; do
    if aws ecr describe-repositories --repository-names $repo --region $AWS_REGION >/dev/null 2>&1; then
        echo "⚠️  ECR repository $repo already exists"
    else
        aws ecr create-repository --repository-name $repo --region $AWS_REGION >/dev/null
        echo "✅ Created ECR repository: $repo"
    fi
done

# Login to ECR
echo "🔑 Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build and push API
echo "📦 Building API service..."
cd "$PROJECT_ROOT/backend/api"
docker build -t codesync-api . -q
docker tag codesync-api:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/codesync-api:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/codesync-api:latest
echo "✅ API image pushed"

# Build and push WebSocket
echo "📦 Building WebSocket service..."
cd "$PROJECT_ROOT/backend/websocket"
docker build -t codesync-websocket . -q
docker tag codesync-websocket:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/codesync-websocket:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/codesync-websocket:latest
echo "✅ WebSocket image pushed"

# Step 3: Configure Terraform
echo ""
echo "⚙️  Step 3: Configuring Terraform..."
cd "$PROJECT_ROOT/terraform"

if [ ! -f terraform.tfvars ]; then
    echo "📝 Creating terraform.tfvars from example..."
    cp terraform.tfvars.example terraform.tfvars
    
    # Update JWT secret ARN
    sed -i.bak "s|jwt_secret_arn = \".*\"|jwt_secret_arn = \"$JWT_SECRET_ARN\"|g" terraform.tfvars
    rm terraform.tfvars.bak
    
    echo "⚠️  Please update terraform.tfvars with your email address!"
    echo "   Edit: $PROJECT_ROOT/terraform/terraform.tfvars"
    echo "   Set: alert_email = \"your-email@example.com\""
    read -p "Press Enter when ready to continue..."
fi

# Step 4: Deploy infrastructure
echo ""
echo "🏗️  Step 4: Deploying infrastructure with Terraform..."
terraform init -upgrade
terraform apply -auto-approve

echo "✅ Infrastructure deployed!"

# Save outputs
terraform output > "$PROJECT_ROOT/infrastructure-outputs.txt"
echo "📄 Outputs saved to infrastructure-outputs.txt"

# Step 5: Deploy frontend
echo ""
echo "🎨 Step 5: Deploying frontend..."

cd "$PROJECT_ROOT/frontend"

# Get outputs
export ALB_DNS=$(cd "$PROJECT_ROOT/terraform" && terraform output -raw alb_dns_name)
export FRONTEND_BUCKET=$(cd "$PROJECT_ROOT/terraform" && terraform output -raw frontend_bucket_name)
export CLOUDFRONT_ID=$(cd "$PROJECT_ROOT/terraform" && terraform output -raw cloudfront_id)

echo "📦 Installing frontend dependencies..."
npm install

echo "🔨 Building frontend..."
VITE_API_URL="http://$ALB_DNS" VITE_WS_URL="http://$ALB_DNS" npm run build

echo "☁️  Uploading to S3..."
aws s3 sync dist/ s3://$FRONTEND_BUCKET/ --delete --quiet

echo "♻️  Invalidating CloudFront cache..."
aws cloudfront create-invalidation --distribution-id $CLOUDFRONT_ID --paths "/*" >/dev/null

echo "✅ Frontend deployed!"

# Step 6: Display access information
echo ""
echo "🎉 Deployment Complete!"
echo "================================"
echo ""
echo "📱 Application URL:"
cd "$PROJECT_ROOT/terraform"
echo "   $(terraform output -raw cloudfront_url)"
echo ""
echo "🔧 API Endpoint:"
echo "   http://$(terraform output -raw alb_dns_name)"
echo ""
echo "📊 CloudWatch Dashboard:"
echo "   https://console.aws.amazon.com/cloudwatch/home?region=$AWS_REGION#dashboards:name=$(terraform output -raw dashboard_name)"
echo ""
echo "📧 Don't forget to confirm your SNS email subscription!"
echo ""
echo "🧪 To test the application:"
echo "   1. Visit the Application URL above"
echo "   2. Register a new account"
echo "   3. Create a document"
echo "   4. Start collaborating!"
echo ""
echo "📄 Full outputs saved to: $PROJECT_ROOT/infrastructure-outputs.txt"

