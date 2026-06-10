"""
InsightHub ChatOps Bot — Audit log

Mọi tool call của bot PHẢI được ghi audit. Đây là yêu cầu bảo mật cốt lõi:
khi AI agent có quyền chạm vào hạ tầng, phải có dấu vết kiểm toán.
"""
import json
import logging
import os
from datetime import datetime, timezone

logger = logging.getLogger("chatops-bot.audit")

# Ghi đồng thời ra file (JSONL) và stdout logger
AUDIT_LOG_FILE = os.getenv("AUDIT_LOG_FILE", "chatops-audit.log")


def log_tool_call(
    user: str,
    tool: str,
    args: dict,
    result_summary: str,
    approved: bool = True,
) -> None:
    """Ghi 1 dòng audit JSON cho mỗi tool call.

    Trường: timestamp, user, tool, args, result, approved.
    Ghi ra file AUDIT_LOG_FILE (JSONL) và stdout logger.
    """
    record = {
        "ts":       datetime.now(timezone.utc).isoformat(),
        "user":     user,
        "tool":     tool,
        "args":     args,
        "result":   result_summary,
        "approved": approved,
    }
    line = json.dumps(record, ensure_ascii=False)
    logger.info("AUDIT %s", line)
    try:
        with open(AUDIT_LOG_FILE, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except OSError as e:
        logger.warning("Không ghi được audit file %s: %s", AUDIT_LOG_FILE, e)
