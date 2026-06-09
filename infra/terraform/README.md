# InsightHub — Terraform

Quản lý toàn bộ hạ tầng AWS cho InsightHub trên EKS.

## Kiến trúc

```
VPC (10.0.0.0/16)
├── Private subnets (10.0.1.0/24, 10.0.2.0/24)
│   ├── EKS worker nodes (t3.medium)
│   ├── RDS PostgreSQL 16 — db.t3.micro, encrypted, single-AZ
│   └── ElastiCache Redis 7  — cache.t3.micro, single node
└── Public subnets (10.0.101.0/24, 10.0.102.0/24)
    └── NAT Gateway (single, cost-aware lab)

IAM
└── IRSA role insighthub-api-irsa
    └── K8s SA api/insighthub → secretsmanager:GetSecretValue insighthub/*

Secrets Manager
├── insighthub/db       — {host, port, username, password, dbname}
├── insighthub/redis    — {url}
└── insighthub/api-keys — {gemini_api_key, anthropic_api_key, voyage_api_key}
```

## Modules

| Module | Mô tả |
|---|---|
| `modules/rds` | RDS PostgreSQL 16, single-AZ, encrypted, SG chỉ cho EKS nodes |
| `modules/elasticache` | ElastiCache Redis 7, single node, SG chỉ cho EKS nodes |
| `modules/secrets` | Secrets Manager: DB, Redis, API keys |
| `modules/irsa` | IAM Role + OIDC trust + K8s ServiceAccount annotation |

## Yêu cầu

- Terraform >= 1.6
- AWS CLI đã `aws configure` hoặc biến môi trường `AWS_*`
- `kubectl` + quyền tạo ServiceAccount trên EKS cluster

## Sử dụng

```bash
# 1. Lần đầu hoặc khi thêm provider
terraform init -upgrade

# 2. Kiểm tra format và lint
terraform fmt -recursive
tflint --recursive

# 3. Xem kế hoạch thay đổi
terraform plan -out=tfplan

# 4. Áp dụng (~10 phút — RDS mất lâu nhất)
terraform apply tfplan
```

## Biến đầu vào

| Tên | Default | Mô tả |
|---|---|---|
| `aws_region` | `ap-southeast-1` | AWS region |
| `cluster_name` | `insighthub` | Tên EKS cluster và prefix tài nguyên |
| `node_instance_type` | `t3.medium` | EC2 type cho EKS workers |
| `db_name` | `insighthub` | Tên PostgreSQL database |
| `db_username` | `insighthub` | Master username |
| `rds_instance_class` | `db.t3.micro` | RDS instance type |
| `redis_node_type` | `cache.t3.micro` | ElastiCache node type |
| `k8s_namespace` | `insighthub` | K8s namespace cho IRSA ServiceAccount |

## Outputs

| Tên | Mô tả |
|---|---|
| `rds_endpoint` | RDS hostname |
| `redis_endpoint` | ElastiCache hostname |
| `irsa_role_arn` | IAM role ARN annotated trên SA api/insighthub |
| `db_secret_arn` | ARN của secret insighthub/db |
| `redis_secret_arn` | ARN của secret insighthub/redis |
| `api_keys_secret_arn` | ARN của secret insighthub/api-keys |
| `configure_kubectl` | Lệnh cập nhật kubeconfig |

## Sau khi apply

### 1. Kích hoạt pgvector trên RDS

```bash
DB_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id insighthub/db --query SecretString --output text)
DB_HOST=$(echo $DB_SECRET | python3 -c "import json,sys; print(json.load(sys.stdin)['host'])")
DB_PASS=$(echo $DB_SECRET | python3 -c "import json,sys; print(json.load(sys.stdin)['password'])")

psql "postgresql://insighthub:${DB_PASS}@${DB_HOST}:5432/insighthub" \
  -c "CREATE EXTENSION IF NOT EXISTS vector;"
```

### 2. Điền API keys vào Secrets Manager

```bash
aws secretsmanager put-secret-value \
  --secret-id insighthub/api-keys \
  --secret-string '{
    "gemini_api_key":    "<YOUR_GEMINI_KEY>",
    "anthropic_api_key": "<YOUR_ANTHROPIC_KEY>",
    "voyage_api_key":    "<YOUR_VOYAGE_KEY>"
  }'
```

### 3. Kiểm tra IRSA

```bash
kubectl run irsa-test --rm -it \
  --image=amazon/aws-cli \
  --serviceaccount=api \
  --namespace=insighthub \
  --restart=Never \
  -- secretsmanager get-secret-value \
     --secret-id insighthub/db \
     --region ap-southeast-1
```

## Ghi chú lab

- **`deletion_protection = false`** và **`skip_final_snapshot = true`** — tiện cho lab, không dùng production.
- **`recovery_window_in_days = 0`** — Secrets Manager xóa ngay thay vì chờ 30 ngày.
- **Single-AZ** cho RDS và ElastiCache — giảm chi phí ~2x so với Multi-AZ.
- DB password được tạo tự động bởi `random_password`, không bao giờ xuất hiện trong code.
