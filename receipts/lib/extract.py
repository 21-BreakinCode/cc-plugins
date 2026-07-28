"""Pull the current main-session assistant turn out of a Claude Code transcript.

The transcript is JSONL. We want everything the assistant produced since the
last real user prompt: its text, and the tool calls it made this turn paired
with their results. Sidechain (subagent) lines are ignored — receipts audits
the main session's claims only, not what a subagent said to itself.
"""
from __future__ import annotations

import json


def _load(path):
    rows = []
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except (json.JSONDecodeError, ValueError):
                continue
    return rows


def _blocks(row):
    content = (row.get("message") or {}).get("content")
    return content if isinstance(content, list) else []


def _is_real_user_prompt(row):
    """A genuine user turn — not a tool_result carrier, not a subagent line."""
    if row.get("type") != "user" or row.get("isSidechain"):
        return False
    if "toolUseResult" in row:
        return False
    content = (row.get("message") or {}).get("content")
    if isinstance(content, str):
        return True
    if isinstance(content, list):
        return any(isinstance(b, dict) and b.get("type") == "text" for b in content)
    return False


def _result_text(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for b in content:
            if isinstance(b, dict) and b.get("type") == "text":
                parts.append(b.get("text", ""))
            elif isinstance(b, str):
                parts.append(b)
        return "\n".join(parts)
    return ""


def extract(path):
    """Return (turn_text, tools) for the current main-session turn.

    tools is a list of {"name", "input", "output"} — one per tool call the
    assistant made this turn, output resolved from the matching tool_result.
    """
    rows = _load(path)

    start = 0
    for i in range(len(rows) - 1, -1, -1):
        if _is_real_user_prompt(rows[i]):
            start = i + 1
            break
    turn = [r for r in rows[start:] if not r.get("isSidechain")]

    texts = []
    tool_uses = []            # (id, name, input)
    results = {}              # tool_use_id -> output text
    for row in turn:
        rtype = row.get("type")
        for block in _blocks(row):
            if not isinstance(block, dict):
                continue
            btype = block.get("type")
            if rtype == "assistant" and btype == "text":
                texts.append(block.get("text", ""))
            elif rtype == "assistant" and btype == "tool_use":
                tool_uses.append((block.get("id"), block.get("name", ""), block.get("input", "")))
            elif btype == "tool_result":
                results[block.get("tool_use_id")] = _result_text(block.get("content"))

    tools = [
        {"name": name, "input": inp, "output": results.get(tid, "")}
        for (tid, name, inp) in tool_uses
    ]
    return "\n".join(texts), tools
