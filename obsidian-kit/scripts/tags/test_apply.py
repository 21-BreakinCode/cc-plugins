"""Self-check for apply.py plan parsing: python3 test_apply.py"""
import tempfile
from pathlib import Path

from apply import PlanError, affected_paths, check_backup_dir, paths_for_body_rewrite, read_plan

inventory = {"domain/db": ["a.md"], "domain/db/query": ["b.md"], "domain/dbx": ["c.md"], "0c8599": ["d.md"]}
assert affected_paths(inventory, ["domain/db"]) == ["a.md", "b.md"]
assert affected_paths(inventory, ["domain/db", "0c8599"]) == ["a.md", "b.md", "d.md"]

with tempfile.TemporaryDirectory() as temp:
    plan_path = Path(temp) / "tag-plan.tsv"
    plan_path.write_text("old\tkind\taction\tnew\tfiles\n"
                         "domain/db\tduplicate\trename\tdomain/database\t30\n"
                         "0c8599\tfalse\tcode\t\t1\n"
                         "one-off\tsingleton\tkeep\t\t1\n", encoding="utf-8")
    assert read_plan(plan_path) == ({"domain/db": "domain/database"}, {"0c8599"}, ["one-off"])
    plan_path.write_text("old\tkind\taction\tnew\tfiles\ndomain/db\tduplicate\trename\t\t30\n", encoding="utf-8")
    try:
        read_plan(plan_path)
        raise AssertionError("expected PlanError for a rename without a new tag")
    except PlanError as plan_error:
        assert "line 2" in str(plan_error)

    # C2: an empty-old row raises PlanError.
    plan_path.write_text("old\tkind\taction\tnew\tfiles\n\tsingleton\tkeep\t\t1\n", encoding="utf-8")
    try:
        read_plan(plan_path)
        raise AssertionError("expected PlanError for an empty old tag")
    except PlanError as plan_error:
        assert "line 2" in str(plan_error)

    # C2: a leading "#" on old/new is stripped.
    plan_path.write_text("old\tkind\taction\tnew\tfiles\n#a\tx\trename\t#b\t1\n", encoding="utf-8")
    renames, false_tags, kept = read_plan(plan_path)
    assert renames == {"a": "b"}

    # C2: too few columns (a missing cell reads as None) raises PlanError.
    plan_path.write_text("old\tkind\taction\tnew\tfiles\na\tx\trename\n", encoding="utf-8")
    try:
        read_plan(plan_path)
        raise AssertionError("expected PlanError for a row with too few columns")
    except PlanError as plan_error:
        assert "line 2" in str(plan_error)

    # C2: whitespace inside the new tag raises PlanError.
    plan_path.write_text("old\tkind\taction\tnew\tfiles\na\tx\trename\tb c\t1\n", encoding="utf-8")
    try:
        read_plan(plan_path)
        raise AssertionError("expected PlanError for whitespace inside the new tag")
    except PlanError as plan_error:
        assert "line 2" in str(plan_error)

# C1: a second apply into the same work dir refuses instead of overwriting the backup.
with tempfile.TemporaryDirectory() as temp:
    work_dir = Path(temp)
    assert check_backup_dir(work_dir / "backup") is None
    (work_dir / "backup").mkdir()
    conflict = check_backup_dir(work_dir / "backup")
    assert conflict is not None and "backup folder exists" in conflict and "new work dir" in conflict

# I1: a file that failed the frontmatter step is skipped in the body-rewrite step.
assert paths_for_body_rewrite(["a.md", "b.md"], [{"path": "a.md", "error": "bad yaml"}]) == ["b.md"]
assert paths_for_body_rewrite(["a.md", "b.md"], []) == ["a.md", "b.md"]

print("test_apply: all passed")
