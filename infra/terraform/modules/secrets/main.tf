locals {
  secret_prefix = var.cluster_name
}

# ── <cluster_name>/db ─────────────────────────────────────────────────────── #
resource "aws_secretsmanager_secret" "db" {
  #checkov:skip=CKV_AWS_149: Lab — using AWS-managed key (encrypted at rest), CMK adds cost
  #checkov:skip=CKV2_AWS_57: Lab — auto rotation requires Lambda setup, out of scope
  name                    = "${local.secret_prefix}/db"
  recovery_window_in_days = var.recovery_window_in_days
  tags                    = merge(var.tags, { Name = "${local.secret_prefix}/db" })
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    host     = var.db_host
    port     = var.db_port
    username = var.db_username
    password = var.db_password
    dbname   = var.db_name
  })
}

# ── <cluster_name>/redis ──────────────────────────────────────────────────── #
resource "aws_secretsmanager_secret" "redis" {
  #checkov:skip=CKV_AWS_149: Lab — using AWS-managed key (encrypted at rest), CMK adds cost
  #checkov:skip=CKV2_AWS_57: Lab — auto rotation requires Lambda setup, out of scope
  name                    = "${local.secret_prefix}/redis"
  recovery_window_in_days = var.recovery_window_in_days
  tags                    = merge(var.tags, { Name = "${local.secret_prefix}/redis" })
}

resource "aws_secretsmanager_secret_version" "redis" {
  secret_id = aws_secretsmanager_secret.redis.id
  secret_string = jsonencode({
    url = "redis://${var.redis_endpoint}:${var.redis_port}"
  })
}

# ── <cluster_name>/api-keys ───────────────────────────────────────────────── #
# Placeholder values — fill in via AWS console or:
#   aws secretsmanager put-secret-value \
#     --secret-id insighthub/api-keys \
#     --secret-string '{"gemini_api_key":"<key>","anthropic_api_key":"<key>"}'
resource "aws_secretsmanager_secret" "api_keys" {
  #checkov:skip=CKV_AWS_149: Lab — using AWS-managed key (encrypted at rest), CMK adds cost
  #checkov:skip=CKV2_AWS_57: Lab — auto rotation requires Lambda setup, out of scope
  name                    = "${local.secret_prefix}/api-keys"
  recovery_window_in_days = var.recovery_window_in_days
  tags                    = merge(var.tags, { Name = "${local.secret_prefix}/api-keys" })
}

resource "aws_secretsmanager_secret_version" "api_keys" {
  secret_id = aws_secretsmanager_secret.api_keys.id
  secret_string = jsonencode({
    gemini_api_key    = "REPLACE_ME"
    anthropic_api_key = "REPLACE_ME"
    voyage_api_key    = "REPLACE_ME"
  })
}
