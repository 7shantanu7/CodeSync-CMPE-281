output "frontend_bucket_id" {
  description = "Frontend bucket ID"
  value       = aws_s3_bucket.frontend.id
}

output "frontend_bucket_name" {
  description = "Frontend bucket name"
  value       = aws_s3_bucket.frontend.bucket
}

output "frontend_bucket_arn" {
  description = "Frontend bucket ARN"
  value       = aws_s3_bucket.frontend.arn
}

output "frontend_bucket_domain" {
  description = "Frontend bucket domain name"
  value       = aws_s3_bucket.frontend.bucket_regional_domain_name
}

output "documents_bucket_id" {
  description = "Documents bucket ID"
  value       = aws_s3_bucket.documents.id
}

output "documents_bucket_name" {
  description = "Documents bucket name"
  value       = aws_s3_bucket.documents.bucket
}

# Secure Design Iteration: Output bucket ARNs for least privilege IAM policies
# Needed to pass specific bucket ARNs instead of using wildcards
output "documents_bucket_arn" {
  description = "Documents bucket ARN"
  value       = aws_s3_bucket.documents.arn
}

output "backups_bucket_name" {
  description = "Backups bucket name"
  value       = aws_s3_bucket.backups.bucket
}

output "backups_bucket_arn" {
  description = "Backups bucket ARN"
  value       = aws_s3_bucket.backups.arn
}



