output "cloudfront_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.frontend.id
}

output "cloudfront_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.frontend.arn
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "cloudfront_hosted_zone_id" {
  description = "CloudFront hosted zone ID"
  value       = aws_cloudfront_distribution.frontend.hosted_zone_id
}

