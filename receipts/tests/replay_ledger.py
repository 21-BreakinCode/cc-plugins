"""Rejoin sampled ledger claims to the transcript turn that produced them.

The `.log` ledger stores only (timestamp, verdict, claim) — no evidence — so a
claim cannot be labelled from the ledger alone. The session transcripts are
still on disk, and the session id is the ledger filename, so the turn's tool
calls can be recovered and the classifier re-run against them.

Usage: python3 replay_ledger.py sample.tsv > replayed.jsonl
"""
from __future__ import annotations

import glob
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))

from classify import classify  # noqa: E402
from extract import _blocks, _is_real_user_prompt, _load, _result_text  # noqa: E402

CONFIG_DIR = os.environ.get("CLAUDE_CONFIG_DIR", os.path.expanduser("~/.claude"))
TRANSCRIPT_GLOB = os.path.join(CONFIG_DIR, "projects", "*", "*.jsonl")
MAX_EXCERPT = 400


def ledger_session_ids():
    return {
        os.path.basename(path)[: -len(".log")]
        for path in glob.glob(os.path.join(CONFIG_DIR, "receipts", "*.log"))
    }


def transcripts_for(session_ids):
    for path in glob.glob(TRANSCRIPT_GLOB):
        if os.path.basename(path)[: -len(".jsonl")] in session_ids:
            yield path


def turns(path):
    """Yield (turn_text, tools) for every main-session turn in a transcript."""
    rows = [r for r in _load(path) if not r.get("isSidechain")]
    starts = [i for i, r in enumerate(rows) if _is_real_user_prompt(r)]
    if not starts:
        return
    bounds = list(zip(starts, starts[1:] + [len(rows)]))
    for start, end in bounds:
        texts, tool_uses, results = [], [], {}
        for row in rows[start + 1 : end]:
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
        if not texts:
            continue
        tools = [
            {"name": name, "input": inp, "output": results.get(tid, "")}
            for (tid, name, inp) in tool_uses
        ]
        yield "\n".join(texts), tools


def excerpt(tools, evidence):
    """The output lines the classifier matched on, or a short head of each output."""
    if evidence and evidence.get("tool_index") is not None:
        index = evidence["tool_index"]
        if 0 <= index < len(tools):
            return f"{tools[index]['name']}: {evidence.get('matched', '')}"[:MAX_EXCERPT]
    heads = [f"{t['name']}: {t['output'][:120].replace(chr(10), ' ')}" for t in tools[:4]]
    return " | ".join(heads)[:MAX_EXCERPT]


def main():
    wanted = {}
    with open(sys.argv[1], encoding="utf-8") as handle:
        for line in handle:
            parts = line.rstrip("\n").split("\t")
            if len(parts) == 2:
                wanted[parts[1]] = parts[0]

    found = {}
    for path in transcripts_for(ledger_session_ids()):
        for turn_text, tools in turns(path):
            for claim, logged in wanted.items():
                if claim in found or claim not in turn_text:
                    continue
                result = classify(claim, tools)
                verdict, evidence = result if isinstance(result, tuple) else (result, None)
                found[claim] = {
                    "claim": claim,
                    "logged": logged,
                    "session": os.path.basename(path)[: -len(".jsonl")],
                    "tool_count": len(tools),
                    "verdict_now": verdict,
                    "evidence": excerpt(tools, evidence),
                }

    for claim in wanted:
        if claim in found:
            print(json.dumps(found[claim], ensure_ascii=False))
    print(
        f"resolved {len(found)}/{len(wanted)} sampled claims to a transcript turn",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
