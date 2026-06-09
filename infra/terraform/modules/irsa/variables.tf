variable "cluster_name" {
  description = "EKS cluster name — used to namespace IAM role names"
  type        = string
  default     = "insighthub"
}

variable "oidc_provider_arn" {
  description = "Full ARN of the EKS OIDC provider (module.eks.oidc_provider_arn)"
  type        = string
}

variable "oidc_provider" {
  description = "OIDC issuer URL without https:// prefix (module.eks.oidc_provider)"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace where the ServiceAccount lives"
  type        = string
  default     = "insighthub"
}

variable "service_account_name" {
  description = "Kubernetes ServiceAccount name to bind to the IAM role"
  type        = string
  default     = "api"
}

variable "secret_arns" {
  description = "Secrets Manager ARNs the pod is permitted to read"
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to all IAM resources"
  type        = map(string)
  default     = {}
}
