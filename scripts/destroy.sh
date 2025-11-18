#!/bin/bash
set -e

# CodeSync Cleanup Script
# This script destroys all AWS resources

echo "🧹 CodeSync Cleanup Script"
echo "================================"
echo ""
echo "⚠️  WARNING: This will DELETE all resources and data!"
echo "   - All databases and data will be lost"
echo "   - All S3 files will be deleted"
echo "   - All logs will be removed"
echo ""
read -p "Are you sure you want to continue? (type 'yes'): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Cleanup cancelled"
    exit 0
fi

PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$PROJECT_ROOT/terraform"

# Ask about backups
echo ""
read -p "Do you want to create final backups? (y/n): " backup

if [ "$backup" = "y" ]; then
    echo "💾 Creating backups..."
    
    # Get resource names
    DB_INSTANCE=$(terraform output -raw db_instance_id 2>/dev/null || echo "")
    FRONTEND_BUCKET=$(terraform output -raw frontend_bucket_name 2>/dev/null || echo "")
    DOCS_BUCKET=$(terraform output -raw documents_bucket_name 2>/dev/null || echo "")
    
    # Backup database
    if [ -n "$DB_INSTANCE" ]; then
        echo "📦 Creating database snapshot..."
        aws rds create-db-snapshot \
            --db-instance-identifier $DB_INSTANCE \
            --db-snapshot-identifier codesync-final-$(date +%Y%m%d-%H%M%S) \
            2>/dev/null || echo "⚠️  Could not create database snapshot"
    fi
    
    # Backup S3 files
    mkdir -p "$PROJECT_ROOT/backups"
    
    if [ -n "$FRONTEND_BUCKET" ]; then
        echo "📦 Backing up frontend files..."
        aws s3 sync s3://$FRONTEND_BUCKET/ "$PROJECT_ROOT/backups/frontend/" --quiet || true
    fi
    
    if [ -n "$DOCS_BUCKET" ]; then
        echo "📦 Backing up documents..."
        aws s3 sync s3://$DOCS_BUCKET/ "$PROJECT_ROOT/backups/documents/" --quiet || true
    fi
    
    echo "✅ Backups saved to: $PROJECT_ROOT/backups/"
fi

# Empty S3 buckets (required before deletion)
echo ""
echo "🗑️  Emptying S3 buckets..."
FRONTEND_BUCKET=$(terraform output -raw frontend_bucket_name 2>/dev/null || echo "")
DOCS_BUCKET=$(terraform output -raw documents_bucket_name 2>/dev/null || echo "")
BACKUPS_BUCKET=$(terraform output -raw backups_bucket_name 2>/dev/null || echo "")

for bucket in $FRONTEND_BUCKET $DOCS_BUCKET $BACKUPS_BUCKET; do
    if [ -n "$bucket" ]; then
        echo "   Emptying $bucket..."
        aws s3 rm s3://$bucket/ --recursive --quiet 2>/dev/null || true
    fi
done

# Destroy infrastructure
echo ""
echo "💥 Destroying infrastructure..."
terraform destroy -auto-approve

echo ""
echo "✅ All resources destroyed!"
echo ""
echo "🧹 Optional cleanup:"
echo "   - ECR repositories (contain Docker images)"
echo "   - JWT secret in Secrets Manager"
echo "   - CloudWatch log groups (contain logs)"
echo "   - RDS snapshots (if created)"
echo ""
read -p "Do you want to delete these as well? (y/n): " cleanup_extra

if [ "$cleanup_extra" = "y" ]; then
    AWS_REGION="${AWS_REGION:-us-east-1}"
    
    echo "🗑️  Deleting ECR repositories..."
    aws ecr delete-repository --repository-name codesync-api --force --region $AWS_REGION 2>/dev/null || true
    aws ecr delete-repository --repository-name codesync-websocket --force --region $AWS_REGION 2>/dev/null || true
    
    echo "🗑️  Deleting JWT secret..."
    aws secretsmanager delete-secret --secret-id codesync/jwt-secret --force-delete-without-recovery --region $AWS_REGION 2>/dev/null || true
    
    echo "🗑️  Deleting log groups..."
    aws logs delete-log-group --log-group-name /ecs/codesync-dev-api --region $AWS_REGION 2>/dev/null || true
    aws logs delete-log-group --log-group-name /ecs/codesync-dev-websocket --region $AWS_REGION 2>/dev/null || true
    
    echo "✅ Extra cleanup complete!"
fi

echo ""
echo "🎉 Cleanup finished!"
echo ""
echo "💡 Note: Some resources may take a few minutes to fully delete."
echo "   Check AWS Console to verify everything is removed."

