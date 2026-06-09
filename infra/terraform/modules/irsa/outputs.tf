output "role_arn" {
  description = "ARN of the IAM role pods assume via IRSA"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.this.name
}

output "service_account_name" {
  description = "Name of the Kubernetes ServiceAccount created"
  value       = kubernetes_service_account.api.metadata[0].name
}
