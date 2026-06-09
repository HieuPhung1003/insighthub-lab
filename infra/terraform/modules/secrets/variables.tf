variable "cluster_name" {
  description = "Cluster name prefix (used in secret name paths)"
  type        = string
  default     = "insighthub"
}

variable "db_host" {
  description = "RDS endpoint hostname (from module.rds.db_endpoint)"
  type        = string
}

variable "db_port" {
  description = "RDS port"
  type        = number
  default     = 5432
}

variable "db_name" {
  description = "Database name to embed in the DB secret"
  type        = string
  default     = "insighthub"
}

variable "db_username" {
  description = "Database master username to embed in the DB secret"
  type        = string
  default     = "insighthub"
}

variable "db_password" {
  description = "Database master password (generated at root, passed in)"
  type        = string
  sensitive   = true
}

variable "redis_endpoint" {
  description = "ElastiCache node address (from module.elasticache.redis_endpoint)"
  type        = string
}

variable "redis_port" {
  description = "Redis port"
  type        = number
  default     = 6379
}

variable "recovery_window_in_days" {
  description = "Secrets Manager deletion recovery window. 0 = immediate deletion (lab convenience)."
  type        = number
  default     = 0
}

variable "tags" {
  description = "Tags applied to all secrets"
  type        = map(string)
  default     = {}
}
