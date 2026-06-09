# Day 3 — HieuPhung1003 (Phung Minh Hieu)

✓ Repo:         https://github.com/HieuPhung1003/insighthub-lab
✓ Branch:       day3
✓ Terraform:    infra/terraform/ (modules: rds, elasticache→in-cluster, irsa, secrets)
✓ CI/CD:        .github/workflows/ci.yaml (build → test → scan → deploy)
✓ Prompt log:   ai-prompts/day3.md (7 prompts)

---

## Artifacts

### 1. Terraform Modules — checkov no HIGH/CRITICAL

```
infra/terraform/
├── main.tf                  # 4 module calls + random_password
├── variables.tf             # cluster, rds, k8s namespace vars
├── outputs.tf               # rds_endpoint, irsa_role_arn, secret ARNs
├── versions.tf              # provider pins: aws ~>5.0, kubernetes ~>2.0, random ~>3.6
├── README.md
├── terraform.tfvars.example
└── modules/
    ├── rds/        RDS PostgreSQL 16 + pgvector, private, encrypted, IRSA
    ├── irsa/       IAM Role for ServiceAccount api/ (no IAM user)
    └── secrets/    Secrets Manager: insighthub/db, /redis, /api-keys
```

**checkov kết quả:**
```
Passed checks: 58, Failed checks: 0, Skipped checks: 13
✅ No HIGH or CRITICAL findings
```

Skipped items: Lab cost constraints (no Multi-AZ, no CMK, no backup retention,
no deletion protection) — mỗi skip có comment giải thích rõ.

**Supply chain:** Module sources dùng git URL + immutable commit hash (CKV_TF_1):
```hcl
source = "git::https://github.com/terraform-aws-modules/terraform-aws-vpc.git?ref=25322b6b..."
```

**AWS resources đã apply:**
- RDS PostgreSQL 16 (`insighthub-postgres`): available, private, encrypted ✓
- IRSA IAM role (`insighthub-api-irsa`) + K8s ServiceAccount ✓
- Secrets Manager: `insighthub/db`, `insighthub/redis`, `insighthub/api-keys` ✓
- K8s namespaces: `insighthub`, `insighthub-dev` ✓
- Redis in-cluster: 1/1 Running ✓

### 2. CI/CD Pipeline — .github/workflows/ci.yaml

Stages:
```
push to main
  ↓
build (matrix: api, web, ingestion-worker) → ghcr.io, GHA layer cache
  ↓
test-python (ruff + pytest)    test-web (npm lint + tsc --noEmit)
  ↓                               ↓
scan-images (trivy, CRITICAL)  scan-infra (checkov terraform)
  ↓
deploy → EKS insighthub-dev (main push only)
  • AWS SM → K8s Secret  →  kubectl apply  →  rollout status  →  smoke test
```

Matrix build ví dụ (ingestion-worker dùng root context vì copy api/app):
```yaml
- name: ingestion-worker
  context: .
  dockerfile: ingestion-worker/Dockerfile
```

### 3. K8s Manifests

```
infra/k8s/
├── api/          deployment.yaml + service.yaml
├── web/          deployment.yaml + service.yaml
├── ingestion-worker/  deployment.yaml
└── redis.yaml    (in-cluster Redis, thay thế ElastiCache)
```

### 4. Tests

`api/tests/test_health.py` — 3 unit tests, không cần DB:
```
✓ test_liveness_returns_ok
✓ test_liveness_content_type_json
✓ test_unknown_route_returns_404
```

---

## Troubleshooting gặp phải trong Day 3

| # | Triệu chứng | Nguyên nhân | Xử lý |
|---|---|---|---|
| 1 | `An argument named "preferred_availability_zone" is not expected` | Typo — argument là plural `zones` (list) | Đổi thành `preferred_availability_zones = ["ap-southeast-1a"]` |
| 2 | `elasticache:CreateCacheSubnetGroup AccessDenied` | Lab IAM user `DE000176` thiếu ElastiCache permission | Deploy Redis in-cluster thay managed ElastiCache (chi phí thấp hơn, phù hợp lab) |
| 3 | tflint warning: `Missing version constraint for provider` (×10) | Child modules thiếu `versions.tf` với `required_providers` | Tạo `versions.tf` trong cả 4 modules |
| 4 | tflint: `variable "cluster_name" is declared but not used` | Biến khai báo nhưng chỉ dùng trong locals chưa tồn tại | Thêm `locals { secret_prefix = var.cluster_name }` rồi dùng trong resource names |
| 5 | checkov `CKV_TF_1`: module source không dùng commit hash | Module sources ban đầu dùng registry version tag | Đổi sang `git::https://...?ref=<immutable-commit-sha>` |
| 6 | `rds.force_ssl` parameter drift: `pending-reboot` vs `immediate` | AWS default apply_method khác với Terraform state | Thêm `apply_method = "immediate"` vào parameter block |
| 7 | `checkov CKV_AWS_354` sau khi bật Performance Insights | Performance Insights yêu cầu KMS CMK nếu bật | Thêm `#checkov:skip=CKV_AWS_354` với lý do lab — AWS-managed key đủ dùng |

---

## Verify Output

```bash
$ bash scripts/verify-day-3.sh

=== InsightHub — Verify Day 3 (IaC + Pipeline) ===
  [NOTE]  Terraform ở infra/terraform/ (không phải infra/ trực tiếp)
          → tflint/checkov/terraform fmt chạy từ infra/terraform/
  [PASS]  terraform fmt OK
  [PASS]  tflint pass (0 warning sau khi thêm versions.tf vào mỗi module)
  [PASS]  checkov no HIGH/CRITICAL (Passed: 58, Skipped: 13)
  [PASS]  .github/workflows/ci.yaml tồn tại
  [PASS]  Pipeline có scan stage (checkov + trivy)
  [PASS]  EKS namespace 'insighthub-dev' tồn tại
  [PASS]  Redis pod Running trên cluster (insighthub-dev)

Kết quả: 7 PASS / 0 FAIL ✅
```

---

## Tóm tắt công việc Day 3

- Sinh Terraform module production-grade cho InsightHub (RDS, IRSA, Secrets Manager)
  bằng AI với constraint-first prompt — 0 HIGH/CRITICAL sau checkov
- Áp dụng supply chain policy (CKV_TF_1): git URL + immutable commit hash
- `terraform apply` thành công — RDS + IRSA + 3 Secrets tồn tại trên AWS
- Xử lý ElastiCache IAM permission block → deploy Redis in-cluster (thực tế hơn cho lab)
- Sinh CI/CD pipeline 4-stage với AI: build matrix, GHA layer cache, trivy, deploy to EKS
- 3 unit tests không cần DB (import-safe, pass Python 3.12)
- Ghi chép AI prompt log tại ai-prompts/day3.md (7 prompts)
