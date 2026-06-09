variable "aws_region" {
  description = "AWS region to deploy the EKS cluster"
  type        = string
  default     = "ap-southeast-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "insighthub"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.30"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "insighthub"
    Environment = "lab"
    ManagedBy   = "terraform"
  }
}

# ── RDS ──────────────────────────────────────────────────────────────────── #
variable "db_name" {
  description = "Initial PostgreSQL database name"
  type        = string
  default     = "insighthub"
}

variable "db_username" {
  description = "PostgreSQL master username"
  type        = string
  default     = "insighthub"
}

variable "rds_instance_class" {
  description = "RDS instance class (lab: db.t3.micro)"
  type        = string
  default     = "db.t3.micro"
}

# ── IRSA ──────────────────────────────────────────────────────────────────── #
variable "k8s_namespace" {
  description = "Kubernetes namespace for the IRSA ServiceAccount"
  type        = string
  default     = "insighthub"
}
