"""Self-check for apply.py plan parsing: python3 test_apply.py"""
import tempfile
from pathlib import Path

from apply import PlanError, affected_paths, read_plan

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

print("test_apply: all passed")
