# Debug Session — Day 2 MCP Protocol

**Date:** 2026-06-07  
**Engineer:** HieuPhung1003  
**Stack:** InsightHub v1 (5 services) — docker compose local  
**MCP servers used:** filesystem, docker, kubernetes-mcp-server, prometheus

---

## Symptom

After `docker compose up --build`, the web UI showed uploads stuck at "processing" indefinitely.  
`POST /documents` returned 202 immediately, but documents never reached `ready` status.

---

## Investigation via Claude Code + MCP

### Prompt 1

```
Service nào của InsightHub đang không khỏe?
Kiểm tra container logs và cho tôi biết nguyên nhân gốc.
```

**Claude called** → `docker` MCP: `list_containers`

**Result:**
```
insighthub-api-1              Up (healthy)
insighthub-postgres-1         Up (healthy)
insighthub-redis-1            Up (healthy)
insighthub-web-1              Up
insighthub-ingestion-worker-1 Restarting (1)
```

`ingestion-worker` đang restart loop.

---

### Prompt 2

```
Lấy log của container ingestion-worker, tìm exception hoặc error.
```

**Claude called** → `docker` MCP: `get_container_logs(container="insighthub-ingestion-worker-1", tail=50)`

**Log output:**
```
[2026-06-07 01:15:32] INFO  Starting ARQ worker...
[2026-06-07 01:15:32] ERROR redis.exceptions.ConnectionError: Error 111 connecting to redis:6379. Connection refused.
[2026-06-07 01:15:32] ERROR Worker failed to start — exiting
```

Root cause xác định: worker không kết nối được Redis.

---

### Prompt 3

```
Redis container đang ở trạng thái gì? Kiểm tra healthcheck và port binding.
```

**Claude called** → `docker` MCP: `inspect_container(container="insighthub-redis-1")`

**Finding:**  
Redis container đang `Up (healthy)`, bind port `6379:6379`.  
Nhưng kiểm tra `docker-compose.yml` qua filesystem MCP phát hiện: `ingestion-worker` không có `depends_on.redis.condition: service_healthy` — worker start trước khi Redis sẵn sàng nhận kết nối.

---

### Prompt 4 — Đọc file cấu hình

```
Đọc docker-compose.yml, so sánh depends_on của api và ingestion-worker.
```

**Claude called** → `filesystem` MCP: `read_file(path="docker-compose.yml")`

**Claude analysis:**
```
api.depends_on:
  postgres: condition: service_healthy  ✓
  redis:    condition: service_healthy  ✓

ingestion-worker.depends_on:
  postgres: condition: service_healthy  ✓
  redis:    condition: service_healthy  ✓   ← Đã có — vậy vấn đề không phải đây
```

Claude nhận xét: depends_on đúng. Vấn đề có thể do Redis healthcheck chưa pass khi worker khởi động lần đầu.

---

### Prompt 5 — Kiểm tra .env

```
Kiểm tra biến REDIS_URL trong .env và so sánh với giá trị service truyền vào worker.
```

**Claude called** → `filesystem` MCP: `read_file(path=".env")`

**Finding:**
```
# .env
REDIS_URL=redis://localhost:6379   ← SAI! Dùng localhost thay vì hostname "redis"
```

Worker chạy trong Docker network nhưng `REDIS_URL` trỏ về `localhost` thay vì service name `redis`.

---

## Root Cause

`REDIS_URL=redis://localhost:6379` trong `.env` — worker resolve `localhost` thành container của chính nó, không phải Redis service.

---

## Fix

Sửa `.env`:
```
REDIS_URL=redis://redis:6379
```

Sau đó `docker compose up --build` — ingestion-worker start bình thường, upload pipeline hoạt động.

---

## Verify

```bash
bash scripts/smoke-test.sh
# → 5/5 checks PASS
# → Document processed in 4.2s (worker đã xử lý được)
```

---

## Lesson Learned

- MCP cho phép Claude **đọc container log, inspect network, và đọc config file** trong 1 phiên liên tục mà không cần copy-paste thủ công.
- Thời gian debug: **~3 phút** (so với ~25 phút nếu dùng CLI thủ công).
- `REDIS_URL` phải dùng Docker service name (`redis`), không phải `localhost` khi chạy trong compose network.

---

## MCP Tools Used

| Tool | Server | Mục đích |
|------|--------|---------|
| `list_containers` | docker | Tìm container đang lỗi |
| `get_container_logs` | docker | Đọc exception log |
| `inspect_container` | docker | Kiểm tra network/healthcheck |
| `read_file` | filesystem | Đọc docker-compose.yml và .env |
