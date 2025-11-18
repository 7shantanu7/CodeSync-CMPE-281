#!/bin/bash
set -e

# CodeSync Service Update Script
# Updates backend services with new Docker images

echo "🔄 CodeSync Service Update"
echo "================================"

AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)

# Select service to update
echo "Which service do you want to update?"
echo "  1) API Service"
echo "  2) WebSocket Service"
echo "  3) Both Services"
read -p "Enter choice (1-3): " choice

case $choice in
    1) SERVICES=("api");;
    2) SERVICES=("websocket");;
    3) SERVICES=("api" "websocket");;
    *) echo "Invalid choice"; exit 1;;
esac

# Login to ECR
echo "🔑 Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

for service in "${SERVICES[@]}"; do
    echo ""
    echo "📦 Updating $service service..."
    
    # Build new image
    cd "$PROJECT_ROOT/backend/$service"
    docker build -t codesync-$service .
    
    # Tag and push
    docker tag codesync-$service:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/codesync-$service:latest
    docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/codesync-$service:latest
    
    # Force new deployment
    echo "🚀 Deploying new version..."
    aws ecs update-service \
        --cluster codesync-dev-cluster \
        --service codesync-dev-$service \
        --force-new-deployment \
        --region $AWS_REGION \
        >/dev/null
    
    echo "✅ $service service updated!"
done

echo ""
echo "🎉 Service update complete!"
echo ""
echo "📊 Monitor deployment:"
echo "   aws ecs describe-services --cluster codesync-dev-cluster --services codesync-dev-api codesync-dev-websocket"
echo ""
echo "📝 View logs:"
echo "   aws logs tail /ecs/codesync-dev-api --follow"
echo "   aws logs tail /ecs/codesync-dev-websocket --follow"

