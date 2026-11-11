#!/usr/bin/env python3
"""Build the interactive review page of a finished code-reviewer review.

usage: build-review-page.py <review-dir> <repo-root>

Reads pr.json, pr.diff, findings.json, report.md, drift.json and page.json from
<review-dir>. Every evidence ref is pulled from git, so no code on the page is
typed by hand. Writes the answer-me-with-html draft <review-dir>/pr<N>-review.md,
renders it with the bundled lib/am.mjs to <review-dir>/pr<N>-review.html, and
prints PAGE_FILE=<path>. On bad input it prints one "error: ..." line per
problem and exits 1.
"""

import itertools
import json
import os
import re
import shlex
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

AM_CLI = Path(__file__).resolve().parent / 'am.mjs'
CONTEXT_LINES = 2
MAX_REF_LINES = 60
MAX_DIFF_ROWS = 80
MAX_OUTPUT_LINES = 40
MAX_FIXES = 6  # an am ask block takes 2 to 6 options
MAX_ID_LENGTH = 64
ID_PATTERN = re.compile(r'^[a-z0-9]+(?:-[a-z0-9]+)*$')
FIX_ID_PATTERN = re.compile(r'^[a-z0-9]{1,16}$')
SEVERITIES = ('critical', 'important', 'suggestion')
VERDICTS = ('REQUEST_CHANGES', 'NEEDS_DISCUSSION', 'APPROVE')
CLAIM_KINDS = ('fact', 'assume', 'insight')
CHECKS = ('code', 'docs', 'reading', 'none')
CHECKS_THAT_SHOW_CODE = ('code', 'reading')
GREP_FLAGS = ('-n', '-w', '-i', '-F', '-E')
EM_DASH = '—'
CONTRACTION = re.compile(
    r"\b(?:\w+n['’]t|(?:i|you|we|they|it|that|there|here|what|who|he|she|let)['’](?:m|re|ve|ll|d|s))\b",
    re.IGNORECASE,
)
DIAGRAM_KINDS = ('class', 'flow')
DIAGRAM_DIRECTIONS = ('LR', 'TB', 'BT', 'RL')
AM_COMPONENTS = {
    'callout', 'kv', 'timeline', 'annot', 'tree', 'limits', 'chart', 'sequence',
    'flow', 'state', 'er', 'class', 'api', 'ask', 'html', 'svg', 'diff',
}
SEVERITY_LABELS = {'critical': 'Critical', 'important': 'Important', 'suggestion': 'Suggestion'}
SUGGESTED_CALL = {'critical': 'Block', 'important': 'Block', 'suggestion': 'Suggest'}
CALL_OPTIONS = (
    ('Block', 'must change before merge'),
    ('Suggest', 'post as a suggestion'),
    ('Skip', 'do not mention it'),
    ('Discuss', 'talk it over with Claude first'),
)
VERDICT_ACTIONS = {'REQUEST_CHANGES': 'Request changes', 'NEEDS_DISCUSSION': 'Comment', 'APPROVE': 'Approve'}
VERDICT_CALLOUTS = {'REQUEST_CHANGES': 'err', 'NEEDS_DISCUSSION': 'warn', 'APPROVE': 'ok'}
GITHUB_ACTION_OPTIONS = (
    ('Request changes', 'the author must change the PR'),
    ('Comment', 'feedback without a verdict'),
    ('Approve', 'the PR can merge'),
    ('Hold', 'post nothing now'),
)
CLAIM_TAGS = {
    ('fact', 'code'): 'FACT, seen in code',
    ('fact', 'docs'): 'FACT, from the PR docs',
    ('fact', 'reading'): 'FACT, read, not run',
    ('fact', 'none'): 'FACT, not checked',
}
REF_PLACES = {'@merged': 'merged', '@base': 'base'}
DRIFT_NOT_RUN = {'status': 'skipped', 'reason': 'the base drift check did not run'}
LIST_KEYS = ('glossary', 'done_well', 'notes')
PR_FIELDS = (
    'number',
    'title',
    'url',
    'author',
    'headRefName',
    'baseRefName',
    'headRefOid',
    'additions',
    'deletions',
    'changedFiles',
)


class PageError(Exception):
    """Problems in the review inputs. Each message names what to fix."""

    def __init__(self, *messages):
        super().__init__('\n'.join(messages))
        self.messages = messages


@dataclass(frozen=True)
class Review:
    repo: Path
    pr: dict
    drift: dict
    diff_hunks: dict
    merge_base: str


# ---------- inputs ----------


def read_json(path):
    if not path.is_file():
        raise PageError(f'{path.name} is missing in {path.parent}')
    try:
        return json.loads(path.read_text(encoding='utf-8'))
    except json.JSONDecodeError as exc:
        raise PageError(f'{path.name} is not valid JSON: {exc}') from exc


def read_drift(path):
    if not path.is_file() or not path.read_text(encoding='utf-8').strip():
        return DRIFT_NOT_RUN
    return read_json(path)


def read_pr(path):
    raw = read_json(path)
    missing = [key for key in PR_FIELDS if key not in raw]
    if missing:
        raise PageError(f'pr.json lacks {", ".join(missing)}')
    match = re.match(r'^(https?://[^/]+)/([^/]+/[^/]+)/pull/\d+$', raw['url'])
    if not match:
        raise PageError(f'pr.json url is not a pull request url: {raw["url"]}')
    host, slug = match.groups()
    return {
        'number': raw['number'],
        'url': raw['url'],
        'title': raw['title'],
        'author': (raw['author'] or {}).get('login', ''),
        'branch': raw['headRefName'],
        'target': raw['baseRefName'],
        'head': raw['headRefOid'],
        'files': raw['changedFiles'],
        'additions': raw['additions'],
        'deletions': raw['deletions'],
        'slug': slug,
        'repo_url': f'{host}/{slug}',
    }


def read_verdict(path):
    if not path.is_file():
        raise PageError(f'report.md is missing in {path.parent}')
    match = re.search(r'^## Verdict: (\w+)', path.read_text(encoding='utf-8'), re.MULTILINE)
    if not match or match.group(1) not in VERDICTS:
        raise PageError(f'report.md has no "## Verdict:" line with one of {", ".join(VERDICTS)}')
    return match.group(1)


def split_diff(diff_text):
    """Map every path in the PR diff to its hunks. Paths come from the file header only."""
    hunks_by_path = {}
    for section in re.split(r'(?m)^(?=diff --git )', diff_text):
        if not section.startswith('diff --git '):
            continue
        header, *hunks = re.split(r'(?m)^(?=@@ )', section)
        for path in set(re.findall(r'(?m)^(?:---|\+\+\+) [ab]/(.+)$', header)):
            hunks_by_path[path] = hunks
    return hunks_by_path


# ---------- validation ----------


def text_errors(where, value):
    return [] if isinstance(value, str) and value.strip() else [f'{where}: write a non-empty text']


def claim_errors(where, claim):
    if not isinstance(claim, dict):
        return [f'{where}: a claim is an object with kind, check, text and refs']
    errors = text_errors(f'{where}.text', claim.get('text'))
    kind, check, refs = claim.get('kind'), claim.get('check'), claim.get('refs')
    if kind not in CLAIM_KINDS:
        errors.append(f'{where}.kind: use one of {", ".join(CLAIM_KINDS)}')
    if check not in CHECKS:
        errors.append(f'{where}.check: use one of {", ".join(CHECKS)}')
    if not isinstance(refs, list) or not all(isinstance(ref, str) for ref in refs):
        return [*errors, f'{where}.refs: write a list of ref strings']
    if kind == 'assume' and check != 'none':
        errors.append(f'{where}: an ASSUME claim has check "none"')
    if check in CHECKS_THAT_SHOW_CODE and not refs:
        errors.append(f'{where}: check "{check}" needs a ref that shows the code')
    return errors


def fix_errors(where, fix):
    if not isinstance(fix, dict):
        return [f'{where}: a fix is an object with id and label']
    errors = text_errors(f'{where}.label', fix.get('label'))
    if not isinstance(fix.get('id'), str) or not FIX_ID_PATTERN.match(fix['id']):
        errors.append(f'{where}.id: use a short id such as "a"')
    if 'detail' in fix:
        errors += text_errors(f'{where}.detail', fix['detail'])
    steps = fix.get('steps', [])
    if not isinstance(steps, list):
        errors.append(f'{where}.steps: write a list of steps')
    else:
        errors += [error for i, step in enumerate(steps) for error in text_errors(f'{where}.steps[{i}]', step)]
    return errors


def page_finding_errors(where, body):
    if not isinstance(body, dict):
        return [f'{where}: write an object with title, points, claims and fixes']
    errors = text_errors(f'{where}.title', body.get('title'))
    for key in ('points', 'claims', 'fixes'):
        if not isinstance(body.get(key), list) or not body[key]:
            errors.append(f'{where}.{key}: write at least one item')
    if errors:
        return errors
    for i, point in enumerate(body['points']):
        point = point if isinstance(point, dict) else {}
        errors += text_errors(f'{where}.points[{i}].label', point.get('label'))
        errors += text_errors(f'{where}.points[{i}].text', point.get('text'))
    errors += [error for i, claim in enumerate(body['claims']) for error in claim_errors(f'{where}.claims[{i}]', claim)]
    errors += [error for i, fix in enumerate(body['fixes']) for error in fix_errors(f'{where}.fixes[{i}]', fix)]
    fix_ids = [fix.get('id') for fix in body['fixes'] if isinstance(fix, dict)]
    if len(fix_ids) != len(set(fix_ids)):
        errors.append(f'{where}.fixes: give each fix its own id')
    if len(fix_ids) > MAX_FIXES:
        errors.append(f'{where}.fixes: write at most {MAX_FIXES} fixes')
    return errors


def diagram_errors(where, diagram):
    if not isinstance(diagram, dict):
        return [f'{where}: write an object with kind, source and refs']
    errors = text_errors(f'{where}.source', diagram.get('source'))
    if diagram.get('kind') not in DIAGRAM_KINDS:
        errors.append(f'{where}.kind: use one of {", ".join(DIAGRAM_KINDS)}')
    if diagram.get('direction', 'LR') not in DIAGRAM_DIRECTIONS:
        errors.append(f'{where}.direction: use one of {", ".join(DIAGRAM_DIRECTIONS)}')
    if isinstance(diagram.get('source'), str) and re.search(r'(?m)^\s*(```|:::)', diagram['source']):
        errors.append(f'{where}.source: write only the diagram body, without fence lines')
    refs = diagram.get('refs')
    if not isinstance(refs, list) or not refs or not all(isinstance(ref, str) for ref in refs):
        errors.append(f'{where}.refs: list at least one ref that the diagram is drawn from')
    return errors


def arch_errors(arch):
    if not isinstance(arch, dict):
        return ['arch: write an object with "before" and "after" diagrams']
    errors = diagram_errors('arch.before', arch.get('before')) + diagram_errors('arch.after', arch.get('after'))
    if not errors and arch['before']['kind'] != arch['after']['kind']:
        errors.append('arch: use the same kind for "before" and "after"')
    return errors


def findings_json_errors(findings):
    if not isinstance(findings, list):
        return ['findings.json: write a JSON array of findings']
    errors = []
    for i, finding in enumerate(findings):
        finding = finding if isinstance(finding, dict) else {}
        finding_id = finding.get('id')
        if not isinstance(finding_id, str) or not ID_PATTERN.match(finding_id) or len(finding_id) > MAX_ID_LENGTH:
            errors.append(f'findings.json[{i}].id: use kebab-case, at most {MAX_ID_LENGTH} characters')
        if finding.get('severity') not in SEVERITIES:
            errors.append(f'findings.json[{i}].severity: use one of {", ".join(SEVERITIES)}')
        sources = finding.get('sources')
        if not isinstance(sources, list) or not sources or not all(isinstance(s, str) and ':' in s for s in sources):
            errors.append(f'findings.json[{i}].sources: list each "<agent>:<tag>"')
        if not isinstance(finding.get('file'), str) or not isinstance(finding.get('line'), int):
            errors.append(f'findings.json[{i}]: needs a "file" text and a "line" number')
    ids = [finding.get('id') for finding in findings if isinstance(finding, dict)]
    duplicate_ids = sorted({fid for fid in ids if isinstance(fid, str) and ids.count(fid) > 1})
    errors += [f'findings.json: id {fid} is used more than once' for fid in duplicate_ids]
    return errors


def page_errors(findings, page):
    if not isinstance(page, dict) or not isinstance(page.get('findings'), dict):
        return ['page.json: write an object whose "findings" maps each finding id to its page entry']
    errors = text_errors('headline', page.get('headline'))
    errors += [f'page.json: {key} must be a list' for key in LIST_KEYS if not isinstance(page.get(key, []), list)]
    if errors:
        return errors
    ids = [finding['id'] for finding in findings]
    errors += [f'page.json: finding {fid} is not on the page' for fid in ids if fid not in page['findings']]
    errors += [f'page.json: finding {fid} is not in findings.json' for fid in page['findings'] if fid not in ids]
    for fid, body in page['findings'].items():
        errors += page_finding_errors(f'findings.{fid}', body)
    errors += arch_errors(page.get('arch'))
    for i, term in enumerate(page.get('glossary', [])):
        term = term if isinstance(term, dict) else {}
        errors += text_errors(f'glossary[{i}].term', term.get('term'))
        errors += text_errors(f'glossary[{i}].meaning', term.get('meaning'))
    errors += [
        error for i, claim in enumerate(page.get('done_well', [])) for error in claim_errors(f'done_well[{i}]', claim)
    ]
    errors += [error for i, note in enumerate(page.get('notes', [])) for error in text_errors(f'notes[{i}]', note)]
    return errors


def prose(page):
    """Yield (where, text) for every text that the page shows to the reader."""
    yield 'headline', page['headline']
    for i, term in enumerate(page.get('glossary', [])):
        yield f'glossary[{i}]', f'{term["term"]} {term["meaning"]}'
    for fid, body in page['findings'].items():
        yield f'findings.{fid}.title', body['title']
        for i, point in enumerate(body['points']):
            yield f'findings.{fid}.points[{i}]', f'{point["label"]} {point["text"]}'
        for i, claim in enumerate(body['claims']):
            yield f'findings.{fid}.claims[{i}]', claim['text']
        for i, fix in enumerate(body['fixes']):
            yield f'findings.{fid}.fixes[{i}]', ' '.join([fix['label'], fix.get('detail', ''), *fix.get('steps', [])])
    for i, claim in enumerate(page.get('done_well', [])):
        yield f'done_well[{i}]', claim['text']
    for i, note in enumerate(page.get('notes', [])):
        yield f'notes[{i}]', note


def style_errors(page):
    """Simple English rules that a script can check: no em-dashes, no contractions. Code in backticks is exempt."""
    errors = []
    for where, text in prose(page):
        outside_code = re.sub(r'`[^`]*`', '', text)
        if EM_DASH in outside_code:
            errors.append(f'{where}: replace the em-dash with a period or a comma')
        contraction = CONTRACTION.search(outside_code)
        if contraction:
            errors.append(f'{where}: write "{contraction.group(0)}" in full')
    return errors


# ---------- evidence ----------


def git(repo, *args, allowed_codes=(0,)):
    result = subprocess.run(['git', '-C', str(repo), *args], capture_output=True, text=True, errors='replace')
    if result.returncode not in allowed_codes:
        reason = (result.stderr.strip().splitlines() or [f'exit {result.returncode}'])[0]
        raise PageError(f'git {args[0]} failed: {reason}')
    return result


def drift_label(review):
    drift = review.drift
    return f'test merge of {review.pr["target"]} {drift["base"][:7]} and PR {review.pr["head"][:7]}'


def tree_for(review, at):
    if at == 'head':
        return review.pr['head']
    if at == 'base':
        return review.merge_base
    if review.drift['status'] != 'checked':
        raise PageError(f'there is no test merge: {review.drift["reason"]}')
    return review.drift['merged_tree']


def place_label(review, at):
    if at == 'head':
        return f'PR head {review.pr["head"][:7]}'
    if at == 'base':
        return f'merge base {review.merge_base[:7]}'
    return drift_label(review)


def fence_language(path):
    extension = Path(path).suffix.lstrip('.').lower()
    return extension if re.fullmatch(r'[a-z0-9+]{1,12}', extension) and extension not in AM_COMPONENTS else 'text'


def code_snippet(review, path, start, end, at):
    if start < 1 or end < start:
        raise PageError('the line range must go up, from line 1 or later')
    if end - start + 1 > MAX_REF_LINES:
        raise PageError(f'cite at most {MAX_REF_LINES} lines, the ones that prove the claim')
    tree = tree_for(review, at)
    shown = git(review.repo, 'show', f'{tree}:{path}', allowed_codes=(0, 128))
    if shown.returncode:
        raise PageError(f'{path} is not in the {place_label(review, at)}. For removed code, use a diff ref')
    lines = shown.stdout.split('\n')
    lines = lines[:-1] if lines and lines[-1] == '' else lines
    if end > len(lines):
        raise PageError(f'{path} has {len(lines)} lines, so line {end} does not exist')
    first, last = max(1, start - CONTEXT_LINES), min(len(lines), end + CONTEXT_LINES)
    span = f'L{start}-{end}' if end > start else f'L{start}'
    return {
        'info': f'{fence_language(path)} title="{path} {span} at the {place_label(review, at)}" '
        f'start={first} hl={start}-{end}',
        'lines': lines[first - 1 : last],
    }


def diff_rows(body, marker, old_line, new_line):
    """Each row keeps the old and new line numbers where it starts, so any window gets a true @@ header."""
    rows = []
    for line in body:
        sign, text = line[:1], line[1:]
        if sign == '\\':  # "\ No newline at end of file"
            continue
        sign = sign if sign in '-+' else ' '
        rows.append({'o': old_line, 'n': new_line, 'sign': sign, 't': text, 'hl': marker in text})
        old_line += sign != '+'
        new_line += sign != '-'
    return rows


def diff_snippet(review, path, marker):
    hunks = review.diff_hunks.get(path)
    if hunks is None:
        raise PageError(f'{path} is not in the PR diff')
    hunk = next((h for h in hunks if marker in h), None)
    if hunk is None:
        raise PageError(f'no hunk of {path} has the text {marker!r}')
    header, *body = hunk.rstrip('\n').split('\n')
    start = re.match(r'^@@ -(\d+)(?:,\d+)? \+(\d+)', header)
    if not start:
        raise PageError(f'unexpected hunk header in {path}: {header}')
    rows = diff_rows(body, marker, int(start.group(1)), int(start.group(2)))
    first_marked = next((i for i, row in enumerate(rows) if row['hl']), 0)
    window_start = max(0, min(first_marked - MAX_DIFF_ROWS // 2, len(rows) - MAX_DIFF_ROWS))
    window = rows[window_start : window_start + MAX_DIFF_ROWS]
    old_count = sum(row['sign'] != '+' for row in window)
    new_count = sum(row['sign'] != '-' for row in window)
    marked_new_lines = [str(row['n']) for row in window if row['hl'] and row['sign'] != '-']
    highlight = f' hl={",".join(marked_new_lines)}' if marked_new_lines else ''
    return {
        'info': f'diff file={path} title="{path} in the PR {review.pr["number"]} diff"{highlight}',
        'lines': [f'@@ -{window[0]["o"]},{old_count} +{window[0]["n"]},{new_count} @@']
        + [row['sign'] + row['t'] for row in window],
    }


def capped(output):
    lines = output.rstrip('\n').split('\n') if output.strip() else ['(no matches)']
    hidden = len(lines) - MAX_OUTPUT_LINES
    return lines[:MAX_OUTPUT_LINES] + ([f'... {hidden} more lines'] if hidden > 0 else [])


def command_snippet(command, place, output):
    title = shlex.join(command).replace('"', "'")
    return {'info': f'text title="{title} ({place})"', 'lines': capped(output)}


def grep_snippet(review, tokens, at):
    flags = list(itertools.takewhile(lambda token: token.startswith('-') and token != '--', tokens))
    bad_flags = [flag for flag in flags if flag not in GREP_FLAGS]
    if bad_flags:
        raise PageError(f'flag {bad_flags[0]} is not allowed. Use only {", ".join(GREP_FLAGS)}')
    rest = tokens[len(flags) :]
    if not rest or rest[0] == '--':
        raise PageError('the pattern is missing')
    pattern, paths = rest[0], rest[1:]
    if paths and paths[0] != '--':
        raise PageError(f'write "--" before the paths, before {paths[0]!r}')
    tree = tree_for(review, at)
    options = ['-n', '-I', *[flag for flag in flags if flag != '-n'], '-e', pattern]
    path_args = ['--', *paths[1:]] if paths else []
    result = git(review.repo, 'grep', *options, tree, *path_args, allowed_codes=(0, 1))
    output = '\n'.join(line.removeprefix(f'{tree}:') for line in result.stdout.splitlines())
    return command_snippet(['git', 'grep', *options, tree[:7], *path_args], place_label(review, at), output)


def merge_tree_snippet(review):
    tree_for(review, 'merged')
    base, head = review.drift['base'], review.pr['head']
    result = git(review.repo, 'merge-tree', '--write-tree', '--name-only', base, head, allowed_codes=(0, 1))
    command = ['git', 'merge-tree', '--write-tree', '--name-only', base[:7], head[:7]]
    return command_snippet(command, drift_label(review), result.stdout)



def resolve_ref(review, ref):
    """Turn one ref from the review contract into a fenced block pulled from git."""
    try:
        tokens = shlex.split(ref)
    except ValueError as exc:
        raise PageError(f'cannot split the ref: {exc}') from exc
    at = REF_PLACES.get(tokens[-1] if tokens else '', 'head')
    tokens = tokens if at == 'head' else tokens[:-1]
    kind = tokens[0] if tokens else ''
    if kind == 'code' and len(tokens) == 2:
        lines = re.match(r'^(.+):(\d+)(?:-(\d+))?$', tokens[1])
        if not lines:
            raise PageError('write a code ref as "code <path>:<start>-<end>"')
        start = int(lines.group(2))
        return code_snippet(review, lines.group(1), start, int(lines.group(3) or start), at)
    if kind == 'diff' and len(tokens) == 3 and at == 'head':
        return diff_snippet(review, tokens[1], tokens[2])
    if kind == 'grep':
        return grep_snippet(review, tokens[1:], at)
    if kind == 'merge-tree' and len(tokens) == 1 and at == 'head':
        return merge_tree_snippet(review)
    raise PageError('use one ref form of the review contract: code, diff, grep, or merge-tree')


def page_refs(page):
    claims = [claim for body in page['findings'].values() for claim in body['claims']] + page.get('done_well', [])
    arch_refs = [ref for side in ('before', 'after') for ref in page['arch'][side]['refs']]
    return sorted({ref for claim in claims for ref in claim['refs']} | set(arch_refs))


def find_merge_base(repo, pr, drift):
    """The commit that the before diagram and @base refs read: where the PR branch left its target."""
    candidates = [drift['base']] if drift['status'] == 'checked' else []
    candidates += [pr['target'], f'origin/{pr["target"]}']
    for candidate in candidates:
        result = git(repo, 'merge-base', pr['head'], candidate, allowed_codes=(0, 1, 128))
        if result.returncode == 0:
            return result.stdout.strip()
    raise PageError(f'no merge base for @base refs: fetch {pr["target"]} into the local clone')


# ---------- draft ----------


def one_line(text):
    return ' '.join(text.split())


def option_text(text):
    return one_line(text).replace('|', '/')


def fenced(info, lines):
    """A fence longer than any backtick run inside, so code that holds ``` stays inside the block."""
    longest_run = max((len(run) for line in lines for run in re.findall(r'`+', line)), default=0)
    fence = '`' * max(3, longest_run + 1)
    return [f'{fence}{info}', *lines, fence]


def ask_block(question, options, suggested):
    lines = [question] + [
        f'{"*" if label == suggested else "-"} {option_text(label)}' + (f' | {note}' if note else '')
        for label, note in options
    ]
    return fenced('ask', lines)


def claim_line(claim):
    tag = CLAIM_TAGS.get((claim['kind'], claim['check']), claim['kind'].upper())
    return f'- **{tag}:** {one_line(claim["text"])}'


def evidence_blocks(claims, snippets):
    refs = list(dict.fromkeys(ref for claim in claims for ref in claim['refs']))
    return [line for ref in refs for line in ['', *fenced(snippets[ref]['info'], snippets[ref]['lines'])]]


def overview_panel(review, findings, page, verdict):
    pr, drift = review.pr, review.drift
    counts = [f'{sum(f["severity"] == s for f in findings)} {s}' for s in SEVERITIES]
    drift_text = (
        f'test merge with `{pr["target"]}` has {len(drift.get("conflicts", []))} conflicted files'
        if drift['status'] == 'checked'
        else f'not checked: {drift["reason"]}'
    )
    lines = ['## Overview', '', *fenced(f'callout {VERDICT_CALLOUTS[verdict]} Verdict: {verdict}', [one_line(page['headline'])]), '']
    lines += fenced('kv cols=2', [
        f'* PR: #{pr["number"]} {one_line(pr["title"])}',
        f'Author: {pr["author"]}',
        f'Branch: {pr["branch"]} into {pr["target"]}',
        f'Changed files: {pr["files"]}',
        f'Changed lines: +{pr["additions"]} -{pr["deletions"]}',
        f'Findings: {", ".join(counts)}',
        f'Base drift: {drift_text}',
    ])
    glossary = page.get('glossary', [])
    if glossary:
        lines += ['', '| Term | Meaning |', '| --- | --- |']
        lines += [f'| {option_text(term["term"])} | {option_text(term["meaning"])} |' for term in glossary]
    return lines


def arch_panel(review, side, diagram):
    at = 'merge base' if side == 'before' else 'PR head'
    sha = review.merge_base if side == 'before' else review.pr['head']
    refs = ', '.join(f'`{ref}`' for ref in diagram['refs'])
    return [
        f'## Architecture {side}',
        '',
        f'The code at the {at} `{sha[:7]}`. Drawn from: {refs}.',
        '',
        *fenced(f'{diagram["kind"]} {diagram.get("direction", "LR")}', diagram['source'].strip('\n').split('\n')),
    ]


def finding_panel(finding, body, snippets):
    areas = ', '.join(dict.fromkeys(source.split(':', 1)[0] for source in finding['sources']))
    lines = [
        f'## {SEVERITY_LABELS[finding["severity"]]}: {one_line(body["title"])}',
        '',
        f'`{finding["file"]}:{finding["line"]}`, found by {areas}.',
        '',
        *[f'- **{one_line(point["label"])}:** {one_line(point["text"])}' for point in body['points']],
        '',
        '**Claims**',
        '',
        *[claim_line(claim) for claim in body['claims']],
        *evidence_blocks(body['claims'], snippets),
        '',
        '**Fixes**',
        '',
    ]
    for fix in body['fixes']:
        detail = f' {one_line(fix["detail"])}' if fix.get('detail') else ''
        lines.append(f'- **{fix["id"]}.** {one_line(fix["label"]).rstrip(".")}.{detail}')
        lines += [f'  {i}. {one_line(step)}' for i, step in enumerate(fix.get('steps', []), 1)]
    lines += ['', *ask_block(f'[{finding["id"]}] Your call on this finding?', CALL_OPTIONS, SUGGESTED_CALL[finding['severity']])]
    if len(body['fixes']) > 1:
        fix_options = [(f'{fix["id"]}. {fix["label"]}', '') for fix in body['fixes']]
        lines += ['', *ask_block(f'[{finding["id"]}] Which fix?', fix_options, fix_options[0][0])]
    return lines


def method_notes(review):
    pr, drift = review.pr, review.drift
    merge_note = (
        f'I made a test merge of the PR into the latest `{pr["target"]}` (`{drift["base"][:7]}`) with '
        '`git merge-tree`. It changes no branch. Code blocks marked "test merge" come from that result.'
        if drift['status'] == 'checked'
        else f'I did not make a test merge with the latest `{pr["target"]}`. Reason: {drift["reason"]}.'
    )
    return [
        f'Every code block comes from git at the PR commit `{pr["head"][:7]}`, unless its title names another '
        'commit. A script copied the lines, so nothing was typed by hand.',
        f'The before diagram shows the merge base `{review.merge_base[:7]}`, where the PR branch starts.',
        merge_note,
        'I did not run the PR code. A claim marked "read, not run" comes from reading the code only.',
    ]


def render_draft(review, findings, page, verdict, snippets):
    pr = review.pr
    lines = [
        '---',
        'template: doc',
        f'title: {pr["slug"].split("/")[1]} PR {pr["number"]} review',
        'lang: en',
        '---',
        *overview_panel(review, findings, page, verdict),
        '',
        *arch_panel(review, 'before', page['arch']['before']),
        '',
        *arch_panel(review, 'after', page['arch']['after']),
    ]
    for finding in sorted(findings, key=lambda finding: SEVERITIES.index(finding['severity'])):
        lines += ['', *finding_panel(finding, page['findings'][finding['id']], snippets)]
    done_well = page.get('done_well', [])
    if done_well:
        lines += ['', '## Done well', '', *[claim_line(claim) for claim in done_well], *evidence_blocks(done_well, snippets)]
    notes = method_notes(review) + page.get('notes', [])
    lines += ['', '## How this review was made', '', *[f'- {one_line(note)}' for note in notes]]
    lines += [
        '',
        '## Verdict',
        '',
        'Answer the questions on this page, then press Reply and paste the reply into the chat.',
        '',
        *ask_block('[review] GitHub action?', GITHUB_ACTION_OPTIONS, VERDICT_ACTIONS[verdict]),
        '',
        *ask_block(
            '[review] Who posts the review?',
            (('Claude after my OK', 'Claude posts with gh'), ('Me', 'I post it on GitHub')),
            'Claude after my OK',
        ),
    ]
    return '\n'.join(lines) + '\n'


def render_page(draft_file, page_file):
    """Run the bundled am CLI. Its own settings and state stay in the review dir, with no update check."""
    env = {**os.environ, 'AM_HOME': str(draft_file.parent / '.am'), 'AM_NO_UPDATE_CHECK': '1'}
    command = ['node', str(AM_CLI), 'render', str(draft_file), '-o', str(page_file), '--no-open']
    try:
        result = subprocess.run(command, capture_output=True, text=True, errors='replace', env=env)
    except FileNotFoundError as exc:
        raise PageError('node is not on PATH. The review page needs Node.js 20 or newer') from exc
    output = [line for line in (result.stdout + result.stderr).splitlines() if line.strip()]
    if result.returncode or not page_file.is_file():
        raise PageError(*[f'am: {line}' for line in output], f'fix page.json, the draft is {draft_file}')
    return output


def build(review_dir, repo):
    pr = read_pr(review_dir / 'pr.json')
    if git(repo, 'cat-file', '-e', f'{pr["head"]}^{{commit}}', allowed_codes=(0, 1, 128)).returncode:
        raise PageError(
            f'the PR head {pr["head"][:7]} is not in the local clone. '
            f'Fetch it with: git fetch origin pull/{pr["number"]}/head'
        )
    findings = read_json(review_dir / 'findings.json')
    errors = findings_json_errors(findings)
    if errors:
        raise PageError(*errors)
    page = read_json(review_dir / 'page.json')
    errors = page_errors(findings, page)
    if errors:
        raise PageError(*errors)
    errors = style_errors(page)
    if errors:
        raise PageError(*errors)
    drift = read_drift(review_dir / 'drift.json')
    review = Review(
        repo=repo,
        pr=pr,
        drift=drift,
        diff_hunks=split_diff((review_dir / 'pr.diff').read_text(encoding='utf-8', errors='replace')),
        merge_base=find_merge_base(repo, pr, drift),
    )
    verdict = read_verdict(review_dir / 'report.md')
    snippets, errors = {}, []
    for ref in page_refs(page):
        try:
            snippets[ref] = resolve_ref(review, ref)
        except PageError as exc:
            errors += [f'ref {ref!r}: {message}' for message in exc.messages]
    if errors:
        raise PageError(*errors)
    draft_file = review_dir / f'pr{pr["number"]}-review.md'
    page_file = review_dir / f'pr{pr["number"]}-review.html'
    draft_file.write_text(render_draft(review, findings, page, verdict, snippets), encoding='utf-8')
    am_output = render_page(draft_file, page_file)
    claims = sum(len(body['claims']) for body in page['findings'].values())
    print(f'PAGE_FILE={page_file}')
    print(f'DRAFT_FILE={draft_file}')
    print(f'findings={len(findings)} claims={claims} snippets={len(snippets)}')
    for line in am_output:
        print(f'am: {line}')


def main(argv):
    if len(argv) != 3:
        print('usage: build-review-page.py <review-dir> <repo-root>', file=sys.stderr)
        return 64
    try:
        build(Path(argv[1]), Path(argv[2]))
    except PageError as exc:
        for message in exc.messages:
            print(f'error: {message}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
