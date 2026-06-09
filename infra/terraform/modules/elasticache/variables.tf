variable "cluster_name" {
  description = "Cluster name prefix for resource naming"
  type        = string
  default     = "insighthub"
}

variable "vpc_id" {
  description = "VPC ID for ElastiCache security group"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for ElastiCache subnet group"
  type        = list(string)
}

variable "node_security_group_id" {
  description = "EKS node security group ID — sole inbound source for port 6379"
  type        = string
}

variable "cluster_id" {
  description = "ElastiCache cluster identifier (lowercase, max 20 chars)"
  type        = string
  default     = "insighthub-redis"
}

variable "node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "tags" {
  description = "Tags applied to all ElastiCache resources"
  type        = map(string)
  default     = {}
}
