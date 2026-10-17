#!/usr/bin/env python3
"""Stop hook: block once when a turn ends with a plain-text question instead of AskUserQuestion."""
import json
import os
import sys

PICKER_TOOL_NAME = "AskUserQuestion"
BLOCK_REASON = (
    "Your reply ends with a plain-text question. If it asks the user to choose or approve "
    "something, ask it again with the AskUserQuestion tool (one picker per decision, "
    "'Step N of M' when there are more than 3). If it is not a decision, end without a question."
)


def is_human_prompt(entry):
    if entry.get("type") != "user":
        return False
    content = entry.get("message", {}).get("content")
    if isinstance(content, str):
        return True
    return not any(block.get("type") == "tool_result" for block in content or [])


def current_turn_entries(transcript_path):
    with open(transcript_path) as transcript_file:
        entries = [json.loads(line) for line in transcript_file if line.strip()]
    last_prompt_index = max((i for i, e in enumerate(entries) if is_human_prompt(e)), default=-1)
    return entries[last_prompt_index + 1:]


def assistant_blocks(turn_entries):
    return [
        block
        for entry in turn_entries
        if entry.get("type") == "assistant"
        for block in entry.get("message", {}).get("content") or []
        if isinstance(block, dict)
    ]


def main():
    if os.environ.get("CLAUDE_ADHD_REVIEW", "1") == "0":
        return
    hook_input = json.load(sys.stdin)
    if hook_input.get("stop_hook_active"):
        return
    blocks = assistant_blocks(current_turn_entries(hook_input["transcript_path"]))
    used_picker = any(b.get("type") == "tool_use" and b.get("name") == PICKER_TOOL_NAME for b in blocks)
    texts = [b.get("text", "") for b in blocks if b.get("type") == "text" and b.get("text", "").strip()]
    final_text = texts[-1].rstrip() if texts else ""
    if used_picker or not final_text.endswith("?"):
        return
    print(json.dumps({"decision": "block", "reason": BLOCK_REASON}))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:  # fail open: a broken hook must never trap the session
        print(f"require-ask-picker hook error: {error}", file=sys.stderr)
