# AI Prompt Log — Day 3: AI-Powered IaC & Pipeline Engineering

Student: HieuPhung1003 (Phung Minh Hieu)
Date: 2026-06-10
Tools: Claude Code (claude-sonnet-4-6) + Terraform MCP server

---

## Prompt 1 — Prerequisites & MCP setup

```
kiểm tra Terraform v1.9+, tflint, checkov, GitHub CLI đã cài chưa
```

**Output:** Xác nhận Terraform v1.9.8, tflint v0.53.0, checkov 3.2.x, gh 2.x đã cài.

---

## Prompt 2 — Terraform modules (Constraint-first IaC)

```
Tạo Terraform module trong thư mục infra/ cho InsightHub trên AWS.
Ràng buộc (constraint-first):
- EKS: tạo namespace 'insighthub' trên cluster có sẵn (không tạo cluster mới)
- RDS PostgreSQL 16, có pgvector — KHÔNG public, encryption at rest, single-AZ (lab)
- ElastiCache Redis — KHÔNG public, trong VPC
- Dùng IRSA cho pod IAM, KHÔNG tạo IAM user
- Instance nhỏ nhất đủ chạy (cost-aware, môi trường lab)
- Mọi secret qua AWS Secrets Manager, không hardcode
Tổ chức thành module có cấu trúc rõ. Viết README + biến đầu vào.
Trình bày plan trước khi tạo file.
```

**Output:** Plan 4 modules (rds, elasticache, irsa, secrets) + root main.tf/variables.tf/outputs.tf.
Tạo 17 files. Agent trình bày dependency graph trước khi apply.

**Pattern học được:** Constraint-first prompt → AI tự giới hạn scope, không hallucinate unnecessary resources.

---

## Prompt 3 — Supply chain security (Prisma Cloud CKV_TF_1)

```
trong main.tf:15-39 giải thích đoạn này và kiểm tra lỗi đảm bảo nguồn module
sử dụng commit hash, lên kế hoạch sửa theo nguồn:
https://docs.prismacloud.io/en/enterprise-edition/policy-reference/supply-chain-policies/
terraform-policies/ensure-terraform-module-sources-use-git-url-with-commit-hash-revision
```

**Output:** Agent giải thích vấn đề version tag vs commit hash, đề xuất đổi từ
`registry.terraform.io/...?version=5.8.1` sang `git::https://...?ref=<immutable-sha>`.

**Learning:** Commit hash = immutable, version tag có thể bị overwrite → supply chain risk.

---

## Prompt 4 — checkov policy gate

```
chạy lệnh checkov -d ., xem kết quả list các lỗi đang mắc phải
giải thích tóm gọn và lên kế hoạch sửa
```

**Output trước sửa:** 18 findings (CRITICAL/HIGH/MEDIUM).
Agent phân nhóm: encryption, public access, backup, multi-az, SSL/TLS enforcement.

```
bắt đầu sửa
```

**Output sau sửa:** Passed: 58, Failed: 0, Skipped: 13.
Skipped items đều có `#checkov:skip=...` với lý do rõ ràng (lab cost constraints).

---

## Prompt 5 — Explain terraform plan bằng tiếng Việt

```
Giải thích terraform plan này bằng tiếng Việt: mỗi resource sẽ tạo gì,
có gì rủi ro, cost ước tính bao nhiêu.
```

**Output:** Agent giải thích 18 resources sẽ tạo, rủi ro (xóa nhầm, không có backup),
cost ước tính ~$26/tháng (RDS db.t3.micro + ElastiCache cache.t3.micro + data transfer).

**Human review step:** Đọc từng resource trước khi confirm apply.

---

## Prompt 6 — Xử lý IAM permission error (ElastiCache)

```
sửa theo phương án B
```

**Context:** `terraform apply` fail với `elasticache:CreateCacheSubnetGroup AccessDenied`.
Phương án A: xin thêm IAM permission. Phương án B: deploy Redis in-cluster (K8s Deployment).

**Output:** Agent xóa `module.elasticache` khỏi Terraform, hardcode Redis URL
`redis://redis.insighthub-dev.svc.cluster.local:6379` trong Secrets Manager,
tạo `infra/k8s/redis.yaml` (Deployment + Headless Service).

**Learning:** Managed service không phải lúc nào cũng đúng cho lab — in-cluster Redis
rẻ hơn, không cần thêm IAM permission, đủ cho ARQ job queue.

---

## Prompt 7 — CI/CD pipeline

```
Tạo GitHub Actions workflow trong .github/workflows/ cho InsightHub.
Stages:
- build: build 3 image (web, api, ingestion-worker)
- test: chạy test cơ bản
- scan: quét vulnerability image (trivy) + checkov cho infra/
- deploy: deploy lên namespace insighthub trên EKS (chỉ khi nhánh main)
Dùng matrix cho build 3 image. Cache layer. Secret qua GitHub Secrets.
```

**Output:** `.github/workflows/ci.yaml` với:
- build: `docker/build-push-action` + `type=gha` layer cache
- test-python: ruff lint + pytest (3 tests, no DB required)
- test-web: npm ci + lint + tsc --noEmit
- scan-images: trivy matrix (CRITICAL only, ignore-unfixed)
- scan-infra: checkov bridgecrewio/checkov-action@v12
- deploy: aws-actions/configure-aws-credentials + envsubst → kubectl apply

---

## Tổng kết prompt patterns hiệu quả

| Pattern | Prompt ví dụ | Kết quả |
|---|---|---|
| Constraint-first | "KHÔNG public, KHÔNG tạo IAM user..." | AI không sinh code vi phạm ràng buộc |
| Plan trước | "Trình bày plan trước khi tạo file" | Giảm back-and-forth chỉnh sửa |
| Paste error | "checkov báo lỗi sau: [output]" | Sửa đúng vấn đề, không đoán mò |
| Language switch | "Giải thích bằng tiếng Việt" | Human review dễ hơn |
| Option selection | "sửa theo phương án B" | AI không cần hỏi lại context |
