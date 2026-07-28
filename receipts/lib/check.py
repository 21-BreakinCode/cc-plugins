"""receipts orchestrator — runs on Stop, decides block vs approve.

stdin:  the Stop hook payload {transcript_path, session_id, stop_hook_active}
stdout: {"decision":"block","reason":...} to force Claude to keep going,
        {"decision":"approve", ...} / nothing to let it stop.

Fails open everywhere: a verifier must never wedge the session on infra error.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
from datetime import datetime
from typing import NoReturn

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from classify import classify  # type: ignore  # noqa: E402
from extract import extract  # type: ignore  # noqa: E402

_FACT_TAG = re.compile(r"\*\*FACT:\*\*\s*(.+)")
_VERB = re.compile(
    r"\b(verified|confirmed|tests?\s+pass(?:ed|ing)?|passes|fixed|it works|"
    r"works now|all green|done)\b",
    re.IGNORECASE,
)


def extract_claims(turn_text):
    """Triggering claims: the **FACT:** tag plus work-completion phrasings."""
    claims = []
    for line in turn_text.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        tag = _FACT_TAG.search(stripped)
        if tag:
            claims.append(tag.group(1).strip())
            continue
        if _VERB.search(stripped):
            claims.append(stripped)
    seen, ordered = set(), []
    for claim in claims:
        if claim not in seen:
            seen.add(claim)
            ordered.append(claim)
    return ordered


def _config_dir():
    base = os.environ.get("CLAUDE_CONFIG_DIR", os.path.expanduser("~/.claude"))
    return os.path.join(base, "receipts")


def _resolve_mode():
    """Mode precedence: /receipts override file > CLAUDE_RECEIPTS_MODE env > warn."""
    try:
        with open(os.path.join(_config_dir(), "mode"), encoding="utf-8") as handle:
            override = handle.read().strip().lower()
        if override in ("block", "warn", "report"):
            return override
    except OSError:
        pass
    return os.environ.get("CLAUDE_RECEIPTS_MODE", "warn").lower()


def _claim_hash(claim):
    return hashlib.sha1(claim.encode("utf-8")).hexdigest()[:16]


def _ledger_path(session_id):
    return os.path.join(_config_dir(), f"{session_id}.blocked")


def load_ledger(session_id):
    try:
        with open(_ledger_path(session_id), encoding="utf-8") as handle:
            return {line.strip() for line in handle if line.strip()}
    except OSError:
        return set()


def record_ledger(session_id, claims):
    path = _ledger_path(session_id)
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "a", encoding="utf-8") as handle:
            for claim in claims:
                handle.write(_claim_hash(claim) + "\n")
    except OSError:
        pass


def log_audit(session_id, verdicts):
    path = os.path.join(_config_dir(), f"{session_id}.log")
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        stamp = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
        with open(path, "a", encoding="utf-8") as handle:
            for claim, verdict in verdicts.items():
                handle.write(f"{stamp}\t{verdict}\t{claim}\n")
    except OSError:
        pass


def run_judge(claims, tools):
    """Fresh-context Haiku verdict for ambiguous claims. None on any failure."""
    judge = os.path.join(os.path.dirname(os.path.abspath(__file__)), "judge.sh")
    if not os.path.exists(judge):
        return None
    try:
        proc = subprocess.run(
            ["bash", judge],
            input=json.dumps({"claims": claims, "tools": tools}),
            capture_output=True,
            text=True,
            timeout=25,
        )
        if proc.returncode != 0:
            return None
        return json.loads(proc.stdout).get("verdicts", {})
    except (OSError, ValueError, subprocess.SubprocessError):
        return None


def approve(note=None) -> NoReturn:
    if note:
        print(json.dumps({"decision": "approve", "systemMessage": note}))
    sys.exit(0)


def block(claims) -> NoReturn:
    bullets = "\n".join(f"  • {c}" for c in claims)
    reason = (
        "receipts: these claims are not backed by any tool call in this turn:\n"
        f"{bullets}\n"
        "Prove each with a real tool call (Read/Bash/Grep/…), or downgrade "
        "**FACT:** → **ASSUME:** / retract it. Then finish."
    )
    print(json.dumps({"decision": "block", "reason": reason}))
    sys.exit(0)


def _warn_text(claims):
    bullets = "\n".join(f"  • {c}" for c in claims)
    return f"⚠ receipts: unbacked claim(s):\n{bullets}\nProve or downgrade to **ASSUME:**."


def main():
    raw = sys.stdin.read()
    try:
        payload = json.loads(raw) if raw.strip() else {}
    except ValueError:
        approve()

    transcript = payload.get("transcript_path")
    session_id = payload.get("session_id") or payload.get("sessionId") or "unknown"
    stop_active = bool(payload.get("stop_hook_active"))
    mode = _resolve_mode()

    if not transcript or not os.path.exists(transcript):
        approve()
    try:
        turn_text, tools = extract(transcript)
    except OSError:
        approve()

    claims = extract_claims(turn_text)
    if not claims:
        approve()

    verdicts, escalate = {}, []
    for claim in claims:
        verdict = classify(claim, tools)
        if verdict == "escalate":
            escalate.append(claim)
        else:
            verdicts[claim] = verdict
    if escalate:
        judged = run_judge(escalate, tools) or {}
        for claim in escalate:
            verdicts[claim] = judged.get(claim, "backed")  # fail open → backed

    log_audit(session_id, verdicts)
    cheating = [c for c, v in verdicts.items() if v == "cheating"]
    if not cheating:
        approve()

    ledger = load_ledger(session_id)
    fresh = [c for c in cheating if _claim_hash(c) not in ledger]

    # Loop-bounded: challenge each unique claim at most once; stop_hook_active
    # is the backstop against any residual loop.
    if not fresh or stop_active:
        approve(note=_warn_text(cheating) if mode != "report" else None)
    record_ledger(session_id, fresh)

    if mode == "report":
        approve()
    if mode == "warn":
        approve(note=_warn_text(fresh))
    block(fresh)


if __name__ == "__main__":
    main()
