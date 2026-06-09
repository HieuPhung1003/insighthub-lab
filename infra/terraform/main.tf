provider "aws" {
  region = var.aws_region
}

# --------------------------------------------------------------------------- #
# Data sources
# --------------------------------------------------------------------------- #
data "aws_availability_zones" "available" {
  state = "available"
}

# --------------------------------------------------------------------------- #
# VPC
# --------------------------------------------------------------------------- #
module "vpc" {
  # checkov:skip=CKV_TF_1: intentional — pinned to immutable commit hash (v5.8.1)
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-vpc.git?ref=25322b6b6be69db6cca7f167d7b0e5327156a595"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true # single NAT = tiết kiệm chi phí cho lab
  enable_dns_hostnames = true

  # Tags bắt buộc để EKS tự discover subnet
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = var.tags
}

# --------------------------------------------------------------------------- #
# EKS Cluster
# --------------------------------------------------------------------------- #
module "eks" {
  # checkov:skip=CKV_TF_1: intentional — pinned to immutable commit hash (v20.14.0)
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-eks.git?ref=73b752a1e365808a7214f064845e958e65c548bd"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Cho phép kubectl từ máy local truy cập cluster
  cluster_endpoint_public_access = true

  # Tắt KMS encryption — IAM user lab không có kms:TagResource
  create_kms_key            = false
  cluster_encryption_config = {}

  # Cấp quyền admin cho IAM entity tạo cluster (cần để Terraform tạo namespace)
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    default = {
      instance_types = [var.node_instance_type]
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size

      labels = {
        role = "worker"
      }
    }
  }

  tags = var.tags
}

# --------------------------------------------------------------------------- #
# Kubernetes provider — kết nối vào cluster vừa tạo
# --------------------------------------------------------------------------- #
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region]
  }
}

# --------------------------------------------------------------------------- #
# Namespaces
# --------------------------------------------------------------------------- #
resource "kubernetes_namespace" "insighthub" {
  # Namespace cho RBAC objects (ServiceAccount mcp-readonly)
  metadata {
    name = "insighthub"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      purpose                        = "rbac"
    }
  }

  depends_on = [module.eks]
}

resource "kubernetes_namespace" "insighthub_dev" {
  # Namespace cho workload thật (api, worker, web, redis, postgres)
  metadata {
    name = "insighthub-dev"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      purpose                        = "workload"
    }
  }

  depends_on = [module.eks]
}

# --------------------------------------------------------------------------- #
# DB password — generated once, stored in Secrets Manager, never hardcoded
# --------------------------------------------------------------------------- #
resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# --------------------------------------------------------------------------- #
# RDS PostgreSQL 16 — private, encrypted, single-AZ (lab)
# --------------------------------------------------------------------------- #
module "rds" {
  source = "./modules/rds"

  cluster_name           = var.cluster_name
  vpc_id                 = module.vpc.vpc_id
  subnet_ids             = module.vpc.private_subnets
  node_security_group_id = module.eks.node_security_group_id
  db_name                = var.db_name
  db_username            = var.db_username
  db_password            = random_password.db.result
  instance_class         = var.rds_instance_class
  tags                   = var.tags
}

# --------------------------------------------------------------------------- #
# Secrets Manager — DB credentials + Redis URL + API key placeholders
# --------------------------------------------------------------------------- #
# Redis runs in-cluster (see infra/k8s/redis.yaml) — no managed ElastiCache
# needed; this avoids the elasticache:CreateCacheSubnetGroup IAM permission.
module "secrets" {
  source = "./modules/secrets"

  cluster_name   = var.cluster_name
  db_host        = module.rds.db_endpoint
  db_port        = module.rds.db_port
  db_name        = var.db_name
  db_username    = var.db_username
  db_password    = random_password.db.result
  redis_endpoint = "redis.insighthub-dev.svc.cluster.local"
  redis_port     = 6379
  tags           = var.tags
}

# --------------------------------------------------------------------------- #
# IRSA — IAM Role for ServiceAccount api/insighthub (no IAM user)
# --------------------------------------------------------------------------- #
module "irsa" {
  source = "./modules/irsa"

  cluster_name         = var.cluster_name
  oidc_provider_arn    = module.eks.oidc_provider_arn
  oidc_provider        = module.eks.oidc_provider
  namespace            = var.k8s_namespace
  service_account_name = "api"
  secret_arns = [
    module.secrets.db_secret_arn,
    module.secrets.redis_secret_arn,
    module.secrets.api_keys_secret_arn,
  ]
  tags = var.tags

  depends_on = [kubernetes_namespace.insighthub]
}
