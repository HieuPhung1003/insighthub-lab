"""
InsightHub ChatOps Bot — 3-tier permission system

Tier   | Examples                          | Policy
-------|-----------------------------------|---------------------------
READ   | get_pods, query_prometheus, logs  | Auto-approved
WRITE  | scale_deployment, restart_pod     | Requires Slack approval
DESTRUCTIVE | delete_pod, drain_node       | Approval + confirm token
"""
from enum import Enum


class ActionTier(Enum):
    READ        = "read"
    WRITE       = "write"
    DESTRUCTIVE = "destructive"


TOOL_TIERS: dict[str, ActionTier] = {
    # Read-only — auto approved
    "get_pods":              ActionTier.READ,
    "get_pod_logs":          ActionTier.READ,
    "query_prometheus":      ActionTier.READ,
    "get_insighthub_health": ActionTier.READ,
    # Write — requires Slack approval message
    "scale_deployment":      ActionTier.WRITE,
    "restart_pod":           ActionTier.WRITE,
    "apply_manifest":        ActionTier.WRITE,
    # Destructive — requires approval + confirmation token
    "delete_pod":            ActionTier.DESTRUCTIVE,
    "drain_node":            ActionTier.DESTRUCTIVE,
    "delete_deployment":     ActionTier.DESTRUCTIVE,
}


def get_tier(tool_name: str) -> ActionTier:
    return TOOL_TIERS.get(tool_name, ActionTier.READ)


def is_auto_approved(tool_name: str) -> bool:
    return get_tier(tool_name) == ActionTier.READ


def requires_approval(tool_name: str) -> bool:
    return get_tier(tool_name) in (ActionTier.WRITE, ActionTier.DESTRUCTIVE)


def approval_message(tool_name: str) -> str:
    tier = get_tier(tool_name)
    if tier == ActionTier.WRITE:
        return (
            f"⚠️ Hành động `{tool_name}` thuộc tier WRITE — cần approval.\n"
            "Admin reply `approve` để xác nhận."
        )
    if tier == ActionTier.DESTRUCTIVE:
        return (
            f"🚨 Hành động `{tool_name}` thuộc tier DESTRUCTIVE — CỰC KỲ NGUY HIỂM.\n"
            "Admin reply `CONFIRM DELETE` để xác nhận. Không thể hoàn tác."
        )
    return ""
