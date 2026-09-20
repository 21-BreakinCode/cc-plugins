#!/usr/bin/env python3
"""Advisory writing checks for Traditional Chinese technical text.

Never blocks. Self-contained: does not import or assume any other
plugin's linter (plugin-rules.md rule 2).

PostToolUse (Write|Edit on a .md file): split into sentences, count
Han characters per sentence (not words — Chinese has no word spaces),
and flag anything over MAX_SENTENCE_CHARS. Also flag em-dashes, filler
or marketing words, and passive-voice markers. Skips paths under the
Claude config directory. Exit 2 is advisory: the file already exists.

Stop: check the reply register (headers, bold, bullets, em-dashes,
filler words, opener/closer phrases). Always exit 0.
"""
import fnmatch
import json
import os
import pathlib
import re
import sys

CLAUDE_DIR = ".claude"
MAX_SENTENCE_CHARS = 25
MAX_HOOK_HITS = 12

FILLER_WORDS = [
    "極致", "賦能", "全方位", "無縫", "值得注意的是", "領先業界",
    "一鍵", "顛覆", "打造", "完美無缺", "強大",
]

OPENERS = re.compile(r"^\s*(好的|沒問題|當然|這是個好問題)[，,]")
CLOSERS = re.compile(r"(希望這對你有幫助|如有任何問題請隨時詢問|歡迎再問)")
CJK_RE = re.compile(r"[一-鿿㐀-䶿]")
SENTENCE_SPLIT = re.compile(r"[^。！？]*[。！？]|[^。！？]+$")
PASSIVE_MARKERS = re.compile(r"被|遭到|由\S{1,6}(?:所)?")


def strip_code(text):
    text = re.sub(r"```.*?```", " ", text, flags=re.S)
    return re.sub(r"`[^`]*`", " ", text)


def split_sentences(text):
    sentences = []
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        sentences.extend(p for p in SENTENCE_SPLIT.findall(line) if p.strip())
    return sentences


def char_count(sentence):
    return len(CJK_RE.findall(sentence))


def find_long_sentences(text):
    hits = []
    for sentence in split_sentences(strip_code(text)):
        n = char_count(sentence)
        if n > MAX_SENTENCE_CHARS:
            hits.append((n, sentence.strip()))
    return hits


def find_filler_words(text):
    return [w for w in FILLER_WORDS if w in text]


def find_passive_markers(text):
    return PASSIVE_MARKERS.findall(text)


def count_em_dash(text):
    return text.count("—")


def reader_check(text):
    return {
        "headers": len(re.findall(r"^#{1,6}\s", text, re.M)),
        "bold": len(re.findall(r"\*\*[^*]+\*\*", text)),
        "bullets": len(re.findall(r"^\s*[-*]\s", text, re.M)),
        "em_dash": count_em_dash(text),
    }


def self_test():
    text = "你好。今天天氣真的非常好，陽光普照，適合出門走走看看世界的美好風景。"
    sentences = split_sentences(text)
    assert sentences == [
        "你好。",
        "今天天氣真的非常好，陽光普照，適合出門走走看看世界的美好風景。",
    ], sentences
    assert char_count("你好。") == 2, char_count("你好。")
    assert char_count(sentences[1]) > MAX_SENTENCE_CHARS
    hits = find_long_sentences(text)
    assert len(hits) == 1, hits
    assert find_filler_words("這個方案很極致") == ["極致"]
    assert find_filler_words("這是正常文字") == []
    assert count_em_dash("這是—測試") == 1
    assert OPENERS.search("好的，我來說明。")
    assert not OPENERS.search("這是說明。")
    assert CLOSERS.search("希望這對你有幫助。")
    assert not CLOSERS.search("這是說明。")
    assert find_passive_markers("這個檔案被刪除了")
    assert not find_passive_markers("刪除這個檔案")
    counts = reader_check("# 標題\n**粗體**\n- 項目\n這是—測試")
    assert counts == {"headers": 1, "bold": 1, "bullets": 1, "em_dash": 1}, counts
    print("self-test passed")


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        self_test()
        sys.exit(0)
