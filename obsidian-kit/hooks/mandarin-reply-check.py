#!/usr/bin/env python3
"""Advisory check of Claude's Traditional Chinese chat replies. Never blocks.

Self-contained: does not import or assume any other plugin's linter
(plugin-rules.md rule 2).

Stop: check a reply that contains Han characters for em-dashes, filler
words, and opener/closer phrases. Always exit 0. Markdown files are not
checked.
"""
import json
import os
import pathlib
import re
import sys


def in_vault(cwd="."):
    """Gate A: the working directory is an Obsidian vault."""
    return pathlib.Path(cwd, ".obsidian").is_dir()


FILLER_WORDS = [
    "極致", "賦能", "全方位", "無縫", "值得注意的是", "領先業界",
    "一鍵", "顛覆", "打造", "完美無缺", "強大",
]

OPENERS = re.compile(r"^\s*(好的|沒問題|當然|這是個好問題)[，,]")
CLOSERS = re.compile(r"(希望這對你有幫助|如有任何問題請隨時詢問|歡迎再問)")
CJK_RE = re.compile(r"[一-鿿㐀-䶿]")


def strip_code(text):
    text = re.sub(r"```.*?```", " ", text, flags=re.S)
    return re.sub(r"`[^`]*`", " ", text)


def find_filler_words(text):
    return [w for w in FILLER_WORDS if w in text]


def count_em_dash(text):
    return text.count("—")


def reply_problems(reply):
    body = strip_code(reply)
    if not CJK_RE.search(body):
        return []
    problems = []
    em_dashes = count_em_dash(reply)
    if em_dashes:
        problems.append(f"{em_dashes} em-dash(s)")
    fillers = find_filler_words(body)
    if fillers:
        problems.append(f"{len(fillers)} filler word(s)")
    if OPENERS.search(reply):
        problems.append("a filler opener")
    if CLOSERS.search(reply):
        problems.append("a filler closer")
    return problems


def stop(event):
    problems = reply_problems(event.get("last_assistant_message") or "")
    if problems:
        message = "simple-mandarin reply check: " + "; ".join(problems) + "。不用破折號，不用開場白或結尾語。"
        print(json.dumps({"systemMessage": message}, ensure_ascii=False))
    return 0


def main():
    if os.environ.get("OBSIDIAN_KIT_MANDARIN") == "0" or not in_vault():
        return 0
    try:
        event = json.load(sys.stdin)
    except Exception:
        return 0
    try:
        if event.get("hook_event_name", "") == "Stop":
            return stop(event)
    except Exception:
        return 0
    return 0


def self_test():
    assert find_filler_words("這個方案很極致") == ["極致"]
    assert find_filler_words("這是正常文字") == []
    assert count_em_dash("這是—測試") == 1
    assert OPENERS.search("好的，我來說明。")
    assert not OPENERS.search("這是說明。")
    assert CLOSERS.search("希望這對你有幫助。")
    assert not CLOSERS.search("這是說明。")
    assert reply_problems("Plain English reply — with an em-dash.") == []
    assert reply_problems("# 標題\n**粗體**\n- 項目\n這是說明。") == []
    assert reply_problems("這是—測試") == ["1 em-dash(s)"]
    assert stop({"last_assistant_message": "Plain English."}) == 0
    print("self-test passed")


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        self_test()
        sys.exit(0)
    sys.exit(main())
