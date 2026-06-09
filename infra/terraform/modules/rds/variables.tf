variable "cluster_name" {
  description = "Cluster name prefix for resource naming"
  type        = string
  default     = "insighthub"
}

variable "vpc_id" {
  description = "VPC ID for RDS security group"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for DB subnet group"
  type        = list(string)
}

variable "node_security_group_id" {
  description = "EKS node security group ID — sole inbound source for port 5432"
  type        = string
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "insighthub"
}

variable "db_username" {
  description = "Master database username"
  type        = string
  default     = "insighthub"
}

variable "db_password" {
  description = "Master database password (sensitive, generated at root)"
  type        = string
  sensitive   = true
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "tags" {
  description = "Tags applied to all RDS resources"
  type        = map(string)
  default     = {}
}
