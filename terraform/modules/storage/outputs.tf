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

output "backups_bucket_name" {
  description = "Backups bucket name"
  value       = aws_s3_bucket.backups.bucket
}

