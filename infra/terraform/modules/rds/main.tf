resource "aws_db_subnet_group" "this" {
  name       = "${var.cluster_name}-rds"
  subnet_ids = var.subnet_ids
  tags       = merge(var.tags, { Name = "${var.cluster_name}-rds" })
}

resource "aws_security_group" "rds" {
  name        = "${var.cluster_name}-rds"
  description = "Allow PostgreSQL inbound from EKS nodes only"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.node_security_group_id]
    description     = "PostgreSQL from EKS worker nodes"
  }

  # CKV_AWS_382: no egress rules — RDS does not initiate outbound connections

  tags = merge(var.tags, { Name = "${var.cluster_name}-rds" })
}

resource "aws_db_parameter_group" "pg16" {
  name   = "${var.cluster_name}-pg16"
  family = "postgres16"

  # pgvector pre-installed on RDS PostgreSQL 16, activate with:
  # CREATE EXTENSION IF NOT EXISTS vector;

  # CKV2_AWS_69: enforce SSL/TLS for all client connections
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  tags = var.tags
}

resource "aws_db_instance" "this" {
  #checkov:skip=CKV_AWS_293: Lab — deletion_protection=false for easy teardown
  #checkov:skip=CKV_AWS_133: Lab — backup_retention_period=0 to avoid storage cost
  #checkov:skip=CKV_AWS_157: Lab — single-AZ intentional, saves ~2x cost vs Multi-AZ
  #checkov:skip=CKV_AWS_118: Lab — enhanced monitoring requires a separate IAM role, out of scope
  #checkov:skip=CKV_AWS_354: Lab — Performance Insights KMS CMK adds cost, AWS-managed key sufficient

  identifier     = "${var.cluster_name}-postgres"
  engine         = "postgres"
  engine_version = "16"
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp2"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  parameter_group_name   = aws_db_parameter_group.pg16.name
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible                 = false
  multi_az                            = false
  availability_zone                   = "ap-southeast-1a"
  auto_minor_version_upgrade          = true
  iam_database_authentication_enabled = true

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  performance_insights_enabled    = true
  copy_tags_to_snapshot           = true

  backup_retention_period = 0
  deletion_protection     = false
  skip_final_snapshot     = true

  tags = merge(var.tags, { Name = "${var.cluster_name}-postgres" })
}
