# AI Prompt Log — Day 1

## Mục tiêu
Tách `ingestion-worker` khỏi API, thêm Redis queue (ARQ), và viết CLAUDE.md.

---

## Prompt 1 — Phân tích kiến trúc v0
**Tool:** Claude Code  
**Prompt:**
```
Phân tích kiến trúc hiện tại của InsightHub v0. Điểm yếu của việc ingest đồng bộ trong API là gì? Đề xuất kiến trúc v1 với background worker.
```
**Kết quả:** Claude xác định `ingest_document_sync()` trong `documents.py` block request, đề xuất tách thành ARQ worker + Redis queue.

---

## Prompt 2 — Tạo ingestion-worker
**Tool:** Claude Code  
**Prompt:**
```
Tạo ingestion-worker với ARQ. Cần: Dockerfile, requirements.txt, worker/settings.py, worker/tasks.py với hàm ingest_document nhận document_id, filename, content_b64.
```
**Kết quả:** Tạo đủ 5 file: `Dockerfile`, `requirements.txt`, `worker/__init__.py`, `worker/settings.py`, `worker/tasks.py`.

---

## Prompt 3 — Refactor API documents router
**Tool:** Claude Code  
**Prompt:**
```
Refactor api/app/routers/documents.py: thay ingest_document_sync bằng ARQ enqueue_job. Upload trả về 202 Accepted ngay, worker xử lý bất đồng bộ.
```
**Kết quả:** `documents.py` dùng `create_pool` + `enqueue_job("ingest_document", ...)`, status_code đổi từ 201 → 202.

---

## Prompt 4 — Cập nhật docker-compose
**Tool:** Claude Code  
**Prompt:**
```
Cập nhật docker-compose.yml từ v0 (3 service) lên v1 (5 service): thêm redis và ingestion-worker với đúng depends_on và environment variables.
```
**Kết quả:** `docker-compose.yml` v1 có đủ 5 service: `web`, `api`, `ingestion-worker`, `redis`, `postgres`.

---

## Prompt 5 — Viết CLAUDE.md
**Tool:** Claude Code  
**Prompt:**
```
Viết CLAUDE.md hoàn chỉnh cho project InsightHub v1. Bao gồm: kiến trúc v0→v1, commands, LLM providers, critical constraints, day-by-day scope.
```
**Kết quả:** CLAUDE.md 104 dòng, đủ 7 section, mô tả đầy đủ kiến trúc và ràng buộc cho AI agent.
