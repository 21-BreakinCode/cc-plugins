#!/usr/bin/env python3
"""Build the interactive review page of a finished code-reviewer review.

usage: build-review-page.py <review-dir> <repo-root>

Reads pr.json, pr.diff, findings.json, report.md, drift.json and page.json from
<review-dir>. Every evidence ref is pulled from git, so no code on the page is
typed by hand. Writes <review-dir>/pr<N>-review.html and prints PAGE_FILE=<path>.
On bad input it prints one "error: ..." line per problem and exits 1.
"""

import hashlib
import html
import itertools
import json
import re
import shlex
import subprocess
import sys
from dataclasses import dataclass
from datetime import date, datetime, timezone
from pathlib import Path
from urllib.parse import quote

TEMPLATE = Path(__file__).resolve().parent.parent / 'templates' / 'review-page.html'
DATA_PLACEHOLDER = '__DATA_JSON__'
TITLE_PLACEHOLDER = '__PAGE_TITLE__'
CONTEXT_LINES = 2
MAX_REF_LINES = 60
MAX_DIFF_ROWS = 80
MAX_OUTPUT_LINES = 40
MAX_INLINE_LIST = 200
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
    if review.drift['status'] != 'checked':
        raise PageError(f'there is no test merge: {review.drift["reason"]}')
    return review.drift['merged_tree']


def code_snippet(review, path, start, end, at):
    if start < 1 or end < start:
        raise PageError('the line range must go up, from line 1 or later')
    if end - start + 1 > MAX_REF_LINES:
        raise PageError(f'cite at most {MAX_REF_LINES} lines, the ones that prove the claim')
    tree = tree_for(review, at)
    shown = git(review.repo, 'show', f'{tree}:{path}', allowed_codes=(0, 128))
    if shown.returncode:
        place = 'the PR head' if at == 'head' else 'the test merge'
        raise PageError(f'{path} is not in {place}. For removed code, use a diff ref')
    lines = shown.stdout.split('\n')
    lines = lines[:-1] if lines and lines[-1] == '' else lines
    if end > len(lines):
        raise PageError(f'{path} has {len(lines)} lines, so line {end} does not exist')
    first, last = max(1, start - CONTEXT_LINES), min(len(lines), end + CONTEXT_LINES)
    span = f'L{start}-L{end}' if end > start else f'L{start}'
    url = f'{review.pr["repo_url"]}/blob/{review.pr["head"]}/{quote(path)}#{span}' if at == 'head' else ''
    return {
        'kind': 'code',
        'title': path,
        'where': f'{review.pr["slug"]} @ {review.pr["head"][:7]}' if at == 'head' else drift_label(review),
        'lines': f'L{start}-{end}' if end > start else f'L{start}',
        'url': url,
        'rows': [{'n': n, 't': lines[n - 1], 'hl': start <= n <= end} for n in range(first, last + 1)],
    }


def diff_rows(body, marker, old_line, new_line):
    rows = []
    for line in body:
        sign, text = line[:1], line[1:]
        if sign == '\\':  # "\ No newline at end of file"
            continue
        marked = marker in text
        if sign == '-':
            rows.append({'o': old_line, 'n': None, 't': text, 'd': 'del', 'hl': marked})
            old_line += 1
        elif sign == '+':
            rows.append({'o': None, 'n': new_line, 't': text, 'd': 'add', 'hl': marked})
            new_line += 1
        else:
            rows.append({'o': old_line, 'n': new_line, 't': text, 'd': 'ctx', 'hl': marked})
            old_line += 1
            new_line += 1
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
    anchor = hashlib.sha256(path.encode()).hexdigest()
    return {
        'kind': 'diff',
        'title': path,
        'where': f'PR {review.pr["number"]} diff',
        'lines': header.split('@@')[1].strip(),
        'url': f'{review.pr["url"]}/files#diff-{anchor}',
        'rows': rows[window_start : window_start + MAX_DIFF_ROWS],
    }


def capped(output):
    """Command output as a list of lines, so each line of it sits on its own line of the page file."""
    lines = output.rstrip('\n').split('\n') if output.strip() else ['(no matches)']
    hidden = len(lines) - MAX_OUTPUT_LINES
    return lines[:MAX_OUTPUT_LINES] + ([f'... {hidden} more lines'] if hidden > 0 else [])


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
    return {
        'kind': 'command',
        'title': 'Search',
        'where': f'run on the PR commit {review.pr["head"][:7]}'
        if at == 'head'
        else f'run on the {drift_label(review)}',
        'command': shlex.join(['git', 'grep', *options, tree[:7], *path_args]),
        'output': capped(output),
    }


def merge_tree_snippet(review):
    tree_for(review, 'merged')
    base, head = review.drift['base'], review.pr['head']
    result = git(review.repo, 'merge-tree', '--write-tree', '--name-only', base, head, allowed_codes=(0, 1))
    return {
        'kind': 'command',
        'title': 'Test merge',
        'where': drift_label(review),
        'command': shlex.join(['git', 'merge-tree', '--write-tree', '--name-only', base[:7], head[:7]]),
        'output': capped(result.stdout),
    }


def resolve_ref(review, ref):
    """Turn one ref from the review contract into a snippet pulled from git."""
    try:
        tokens = shlex.split(ref)
    except ValueError as exc:
        raise PageError(f'cannot split the ref: {exc}') from exc
    at = 'merged' if tokens[-1:] == ['@merged'] else 'head'
    tokens = tokens[:-1] if at == 'merged' else tokens
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
    return sorted({ref for claim in claims for ref in claim['refs']})


# ---------- page ----------


def to_json_lines(value, depth=0):
    """JSON with one short item per line, so a line reader can page through the whole file.

    An object without nested containers (a code row, a point) stays on one line. A list stays on
    one line only while it is short; a long list, such as command output, gets one item per line.
    """
    flat = json.dumps(value, ensure_ascii=False)
    nested = isinstance(value, (dict, list)) and any(
        isinstance(item, (dict, list)) for item in (value.values() if isinstance(value, dict) else value)
    )
    long_list = isinstance(value, list) and len(flat) > MAX_INLINE_LIST
    if not nested and not long_list:
        return flat
    pad, end_pad = ' ' * (depth + 1), ' ' * depth
    if isinstance(value, dict):
        items = [
            f'{pad}{json.dumps(key, ensure_ascii=False)}: {to_json_lines(item, depth + 1)}'
            for key, item in value.items()
        ]
        return '{\n' + ',\n'.join(items) + f'\n{end_pad}}}'
    items = [pad + to_json_lines(item, depth + 1) for item in value]
    return '[\n' + ',\n'.join(items) + f'\n{end_pad}]'


def method_notes(review):
    pr, drift = review.pr, review.drift
    merge_note = (
        f'I made a test merge of the PR into the latest `{pr["target"]}` (`{drift["base"][:7]}`) with '
        '`git merge-tree`. It changes no branch. Code blocks marked "test merge" come from that result.'
        if drift['status'] == 'checked'
        else f'I did not make a test merge with the latest `{pr["target"]}`. Reason: {drift["reason"]}.'
    )
    return [
        f'Every code block comes from git at the PR commit `{pr["head"][:7]}`. A script copied the lines, '
        'so nothing was typed by hand.',
        merge_note,
        'I did not run the PR code. A claim marked "Read, not run" comes from reading the code only.',
    ]


def page_findings(findings, page):
    by_severity = sorted(findings, key=lambda finding: SEVERITIES.index(finding['severity']))
    return [
        {
            'id': finding['id'],
            'severity': finding['severity'],
            'areas': list(dict.fromkeys(source.split(':', 1)[0] for source in finding['sources'])),
            'file': finding['file'],
            'line': finding['line'],
            **{key: page['findings'][finding['id']][key] for key in ('title', 'points', 'claims', 'fixes')},
        }
        for finding in by_severity
    ]


def render(review, findings, page, verdict, snippets):
    pr = {
        key: review.pr[key]
        for key in ('number', 'url', 'title', 'author', 'branch', 'target', 'head', 'files', 'additions', 'deletions')
    }
    drift = {**review.drift, 'base_ref': review.pr['target'], 'conflicts': review.drift.get('conflicts', [])}
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    data = {
        'review_id': f'{review.pr["slug"]}#{pr["number"]}@{pr["head"][:7]}:{stamp}',
        'repo': review.pr['slug'],
        'reviewed_on': date.today().isoformat(),
        'pr': pr,
        'verdict': verdict,
        'headline': page['headline'],
        'drift': drift,
        'glossary': page.get('glossary', []),
        'findings': page_findings(findings, page),
        'done_well': page.get('done_well', []),
        'notes': method_notes(review) + page.get('notes', []),
        'snippets': snippets,
    }
    payload = to_json_lines(data).replace('<', '\\u003c')  # keeps </script> and <!-- out of the data block
    parts = TEMPLATE.read_text(encoding='utf-8').split(DATA_PLACEHOLDER)
    if len(parts) != 2:
        raise PageError(f'the template must hold {DATA_PLACEHOLDER} exactly once')
    title = f'{review.pr["slug"].split("/")[1]} PR {pr["number"]} Review'
    page_html = parts[0].replace(TITLE_PLACEHOLDER, html.escape(title)) + payload + parts[1]
    embedded = re.search(r'<script type="application/json" id="data">(.*?)</script>', page_html, re.DOTALL)
    json.loads(embedded.group(1))  # the data must survive the round trip
    return page_html


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
    review = Review(
        repo=repo,
        pr=pr,
        drift=read_drift(review_dir / 'drift.json'),
        diff_hunks=split_diff((review_dir / 'pr.diff').read_text(encoding='utf-8', errors='replace')),
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
    page_html = render(review, findings, page, verdict, snippets)
    out = review_dir / f'pr{pr["number"]}-review.html'
    out.write_text(page_html, encoding='utf-8')
    claims = sum(len(body['claims']) for body in page['findings'].values())
    print(f'PAGE_FILE={out}')
    print(f'findings={len(findings)} claims={claims} snippets={len(snippets)} bytes={len(page_html.encode())}')


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
