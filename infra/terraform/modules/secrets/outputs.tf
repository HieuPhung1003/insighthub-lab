output "db_secret_arn" {
  description = "ARN of the insighthub/db secret"
  value       = aws_secretsmanager_secret.db.arn
}

output "redis_secret_arn" {
  description = "ARN of the insighthub/redis secret"
  value       = aws_secretsmanager_secret.redis.arn
}

output "api_keys_secret_arn" {
  description = "ARN of the insighthub/api-keys secret"
  value       = aws_secretsmanager_secret.api_keys.arn
}
