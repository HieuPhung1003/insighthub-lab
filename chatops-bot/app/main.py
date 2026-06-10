"""
InsightHub ChatOps Bot — Day 5

Nhận câu hỏi vận hành từ Slack (Socket Mode), dùng Gemini + tools
để query K8s và Prometheus, trả lời ngắn gọn bằng tiếng Việt.
"""
import asyncio
import functools
import hashlib
import hmac
import logging
import os
from concurrent.futures import ThreadPoolExecutor
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI
from google import genai
from google.genai import types
from slack_bolt.async_app import AsyncApp
from slack_bolt.adapter.socket_mode.aiohttp import AsyncSocketModeHandler

from app.permissions import is_auto_approved, approval_message

from app.audit import log_tool_call

logging.basicConfig(level="INFO", format="%(asctime)s %(name)s %(levelname)s %(message)s")
logger = logging.getLogger("chatops-bot")

SLACK_BOT_TOKEN      = os.getenv("SLACK_BOT_TOKEN", "")
SLACK_APP_TOKEN      = os.getenv("SLACK_APP_TOKEN", "")
SLACK_SIGNING_SECRET = os.getenv("SLACK_SIGNING_SECRET", "")
GEMINI_API_KEY       = os.getenv("GEMINI_API_KEY", "")
# gemini-2.5-flash: verified OK; gemini-flash-latest làm fallback
_PRIMARY_MODEL  = "gemini-2.5-flash"
_FALLBACK_MODEL = "gemini-flash-latest"
GEMINI_CHAT_MODEL = _PRIMARY_MODEL
PROMETHEUS_URL       = os.getenv(
    "PROMETHEUS_URL",
    "http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090",
)
INSIGHTHUB_API_URL   = os.getenv(
    "INSIGHTHUB_API_URL",
    "http://api.insighthub-dev.svc.cluster.local:8000",
)

slack_app     = AsyncApp(token=SLACK_BOT_TOKEN, signing_secret=SLACK_SIGNING_SECRET)
gemini_client  = genai.Client(api_key=GEMINI_API_KEY)
_thread_pool   = ThreadPoolExecutor(max_workers=4)  # chạy Gemini sync trong thread

# ── Slack signature verification (dùng cho HTTP Events API mode) ──────────────

def verify_slack_signature(body: bytes, timestamp: str, x_slack_signature: str) -> bool:
    """Verify Slack request signature theo HMAC-SHA256.

    Socket Mode dùng OAuth nên không cần verify per-request,
    nhưng giữ hàm này để dùng khi switch sang HTTP Events API.
    """
    basestring = f"v0:{timestamp}:{body.decode('utf-8')}"
    mac = hmac.new(
        SLACK_SIGNING_SECRET.encode("utf-8"),
        basestring.encode("utf-8"),
        hashlib.sha256,
    )
    expected = "v0=" + mac.hexdigest()
    return hmac.compare_digest(expected, x_slack_signature)

# ── Tool definitions ──────────────────────────────────────────────────────────

GEMINI_TOOLS = types.Tool(function_declarations=[
    types.FunctionDeclaration(
        name="get_pods",
        description="Lấy danh sách pods và trạng thái trong namespace insighthub-dev.",
        parameters=types.Schema(type=types.Type.OBJECT, properties={}, required=[]),
    ),
    types.FunctionDeclaration(
        name="get_pod_logs",
        description="Lấy log gần nhất của một pod cụ thể trong namespace insighthub-dev.",
        parameters=types.Schema(
            type=types.Type.OBJECT,
            properties={
                "pod_name": types.Schema(type=types.Type.STRING, description="Tên pod, vd: api-68b58c8484-h5x7p"),
                "tail":     types.Schema(type=types.Type.INTEGER, description="Số dòng cuối cần lấy, mặc định 50"),
            },
            required=["pod_name"],
        ),
    ),
    types.FunctionDeclaration(
        name="query_prometheus",
        description=(
            "Query Prometheus bằng PromQL để lấy metrics thực tế. "
            "Dùng cho: HTTP request rate, LLM latency p95, error rate, queue depth, v.v. "
            "Ví dụ: rate(insighthub_http_requests_total[5m]), insighthub:llm_call_latency_p95:rate5m"
        ),
        parameters=types.Schema(
            type=types.Type.OBJECT,
            properties={
                "query": types.Schema(type=types.Type.STRING, description="PromQL expression"),
            },
            required=["query"],
        ),
    ),
    types.FunctionDeclaration(
        name="get_insighthub_health",
        description="Kiểm tra liveness (/healthz) và readiness (/readyz) của InsightHub API.",
        parameters=types.Schema(type=types.Type.OBJECT, properties={}, required=[]),
    ),
])

# ── Tool implementations ──────────────────────────────────────────────────────

async def _kubectl(*args: str) -> str:
    proc = await asyncio.create_subprocess_exec(
        "kubectl", *args,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=15)
    return (stdout or stderr).decode().strip()


async def _prom_query(query: str) -> str:
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{PROMETHEUS_URL}/api/v1/query",
            params={"query": query},
            timeout=10,
        )
    data = resp.json()
    results = data.get("data", {}).get("result", [])
    if not results:
        return "No data (metric chưa có giá trị hoặc query không khớp)"
    lines = []
    for r in results[:10]:
        metric = {k: v for k, v in r["metric"].items() if k != "__name__"}
        lines.append(f"{metric} = {r['value'][1]}")
    return "\n".join(lines)


async def _execute_tool(name: str, args: dict, user: str) -> str:
    # Kiểm tra permission tier trước khi thực thi
    if not is_auto_approved(name):
        msg = approval_message(name)
        log_tool_call(user=user, tool=name, args=args, result_summary="BLOCKED — requires approval", approved=False)
        return msg

    try:
        if name == "get_pods":
            result = await _kubectl("get", "pods", "-n", "insighthub-dev", "-o", "wide")

        elif name == "get_pod_logs":
            pod  = args["pod_name"]
            tail = str(args.get("tail", 50))
            result = await _kubectl("logs", "-n", "insighthub-dev", pod, "--tail", tail)

        elif name == "query_prometheus":
            result = await _prom_query(args["query"])

        elif name == "get_insighthub_health":
            async with httpx.AsyncClient() as client:
                lv = await client.get(f"{INSIGHTHUB_API_URL}/healthz", timeout=5)
                rd = await client.get(f"{INSIGHTHUB_API_URL}/readyz",  timeout=5)
            result = (
                f"liveness:  {lv.status_code} {lv.text[:120]}\n"
                f"readiness: {rd.status_code} {rd.text[:120]}"
            )
        else:
            result = f"Unknown tool: {name}"

    except Exception as exc:
        result = f"Error executing {name}: {exc}"

    log_tool_call(user=user, tool=name, args=args, result_summary=result[:300])
    return result

# ── Core question handler ─────────────────────────────────────────────────────

SYSTEM_PROMPT = (
    "Bạn là InsightHub ChatOps Bot — trợ lý vận hành cho hệ thống InsightHub "
    "đang chạy trên Kubernetes (namespace insighthub-dev).\n"
    "Nguyên tắc:\n"
    "- Trả lời ngắn gọn, rõ ràng bằng tiếng Việt.\n"
    "- Với câu hỏi về trạng thái hệ thống, LUÔN dùng tools để lấy dữ liệu thực thay vì đoán.\n"
    "- Với hành động có thể phá hủy (xóa pod, restart), báo cáo và yêu cầu xác nhận từ admin — "
    "KHÔNG tự thực hiện.\n"
    "- Tóm tắt kết quả tools thành câu trả lời dễ hiểu cho người vận hành."
)


_CALL_TIMEOUT = 25  # giây tối đa cho mỗi Gemini request


async def _generate(model: str, contents, config) -> types.GenerateContentResponse:
    """Chạy Gemini sync trong thread pool — asyncio.wait_for có thể interrupt được."""
    from google.genai.errors import ServerError, ClientError

    loop = asyncio.get_event_loop()

    async def _call(m: str):
        fn = functools.partial(
            gemini_client.models.generate_content,  # sync version
            model=m, contents=contents, config=config,
        )
        return await asyncio.wait_for(
            loop.run_in_executor(_thread_pool, fn),
            timeout=_CALL_TIMEOUT,
        )

    try:
        return await _call(model)
    except (ServerError, ClientError, asyncio.TimeoutError) as e:
        if _FALLBACK_MODEL != model:
            logger.warning("Model %s lỗi (%s), fallback sang %s", model, e, _FALLBACK_MODEL)
            return await _call(_FALLBACK_MODEL)
        raise


async def handle_question(question: str, user: str = "unknown") -> str:
    contents: list[types.Content] = [
        types.Content(role="user", parts=[types.Part(text=question)])
    ]

    for _ in range(6):  # tối đa 6 vòng tool-use
        response = await _generate(
            GEMINI_CHAT_MODEL,
            contents,
            types.GenerateContentConfig(
                tools=[GEMINI_TOOLS],
                system_instruction=SYSTEM_PROMPT,
            ),
        )

        candidate = response.candidates[0]
        parts      = candidate.content.parts

        # Kiểm tra có function call không
        fc_parts = [p for p in parts if p.function_call is not None]
        if not fc_parts:
            # Không có tool call → trả lời cuối
            return response.text or "Không có câu trả lời."

        # Có tool call → thực thi rồi trả kết quả về Gemini
        contents.append(candidate.content)
        fn_responses = []
        for p in fc_parts:
            fc     = p.function_call
            result = await _execute_tool(fc.name, dict(fc.args), user)
            logger.info("Tool %s → %s", fc.name, result[:80])
            fn_responses.append(types.Part(
                function_response=types.FunctionResponse(
                    name=fc.name,
                    response={"result": result},
                )
            ))
        contents.append(types.Content(role="user", parts=fn_responses))

    return "Không thể xử lý câu hỏi sau nhiều vòng tool-use."

# ── Slack event handlers ──────────────────────────────────────────────────────

@slack_app.event("app_mention")
async def on_mention(event, say):
    user     = event.get("user", "unknown")
    raw_text = event.get("text", "")
    question = " ".join(w for w in raw_text.split() if not w.startswith("<@")).strip()
    if not question:
        await say("Xin chào! Hỏi tôi về trạng thái InsightHub nhé.")
        return
    logger.info("Câu hỏi từ %s: %s", user, question)
    await say("⏳ Đang kiểm tra hệ thống...")
    try:
        answer = await asyncio.wait_for(handle_question(question, user=user), timeout=60)
    except asyncio.TimeoutError:
        answer = "⏱️ Hết thời gian chờ (60s). Thử lại sau."
    except Exception as exc:
        logger.exception("handle_question thất bại")
        answer = f"❌ Lỗi: {exc}"
    await say(answer)


@slack_app.event("message")
async def on_message():
    # Bỏ qua message thường để tránh duplicate với app_mention
    pass

# ── FastAPI lifespan ──────────────────────────────────────────────────────────

_socket_handler: AsyncSocketModeHandler | None = None


@asynccontextmanager
async def lifespan(_: FastAPI):
    global _socket_handler
    if SLACK_APP_TOKEN:
        _socket_handler = AsyncSocketModeHandler(slack_app, SLACK_APP_TOKEN)
        asyncio.create_task(_socket_handler.start_async())
        logger.info("Slack Socket Mode đã kết nối")
    else:
        logger.warning("SLACK_APP_TOKEN chưa set — bot không kết nối Slack")
    yield


app = FastAPI(title="InsightHub ChatOps Bot", lifespan=lifespan)


@app.get("/healthz")
async def health():
    return {"status": "ok"}
