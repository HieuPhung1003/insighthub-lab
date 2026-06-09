output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "configure_kubectl" {
  description = "Command to configure kubectl for this cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}"
}

output "namespaces" {
  description = "Kubernetes namespaces created"
  value = {
    rbac     = kubernetes_namespace.insighthub.metadata[0].name
    workload = kubernetes_namespace.insighthub_dev.metadata[0].name
  }
}

# ── RDS ──────────────────────────────────────────────────────────────────── #
output "rds_endpoint" {
  description = "RDS PostgreSQL hostname"
  value       = module.rds.db_endpoint
}

output "rds_port" {
  description = "RDS PostgreSQL port"
  value       = module.rds.db_port
}

# ── Redis (in-cluster) ────────────────────────────────────────────────────── #
output "redis_endpoint" {
  description = "In-cluster Redis DNS (see infra/k8s/redis.yaml)"
  value       = "redis.insighthub-dev.svc.cluster.local"
}

output "redis_port" {
  description = "In-cluster Redis port"
  value       = 6379
}

# ── IRSA ──────────────────────────────────────────────────────────────────── #
output "irsa_role_arn" {
  description = "IAM role ARN annotated on the api ServiceAccount"
  value       = module.irsa.role_arn
}

# ── Secrets Manager ───────────────────────────────────────────────────────── #
output "db_secret_arn" {
  description = "ARN of insighthub/db secret"
  value       = module.secrets.db_secret_arn
}

output "redis_secret_arn" {
  description = "ARN of insighthub/redis secret"
  value       = module.secrets.redis_secret_arn
}

output "api_keys_secret_arn" {
  description = "ARN of insighthub/api-keys secret (fill in keys via console)"
  value       = module.secrets.api_keys_secret_arn
}
