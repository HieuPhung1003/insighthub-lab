resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.cluster_name}-redis"
  subnet_ids = var.subnet_ids
  tags       = merge(var.tags, { Name = "${var.cluster_name}-redis" })
}

resource "aws_security_group" "redis" {
  name        = "${var.cluster_name}-redis"
  description = "Allow Redis inbound from EKS nodes only"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.node_security_group_id]
    description     = "Redis from EKS worker nodes"
  }

  # CKV_AWS_382: no egress rules — ElastiCache does not initiate outbound connections

  tags = merge(var.tags, { Name = "${var.cluster_name}-redis" })
}

resource "aws_elasticache_cluster" "this" {
  cluster_id           = var.cluster_id
  engine               = "redis"
  engine_version       = var.engine_version
  node_type            = var.node_type
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  subnet_group_name    = aws_elasticache_subnet_group.this.name
  security_group_ids   = [aws_security_group.redis.id]

  preferred_availability_zones = ["ap-southeast-1a"]
  snapshot_retention_limit     = 1

  tags = merge(var.tags, { Name = var.cluster_id })
}
