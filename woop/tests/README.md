# woop tests

## `test_woop_conformance.sh`

Deterministic structural gate — asserts the plugin's files exist and carry their contract:
manifest name/version, the skill's leading words + Obstacle rule + all four W/O/O/P steps +
persist template, the four mode references, the four command modes, the obstacle-hunter's
read-only tool set, and no cross-plugin `find`.

```bash
bash woop/tests/test_woop_conformance.sh
```

Exit 0 with `Failed: 0` on success.

## What this does NOT cover

The **behavioral** regression — running a real WOOP and scoring whether the output reframes a
surface→essence wish, keeps only rule-passing obstacles, and pairs every kept obstacle with an
`If … then …` — needs an agent/LLM and is not part of this deterministic script.

Note: `./scripts/cicd.sh VERIFY` runs the repo's **doc-generator** tests + doc-sync check, not
this script. Run this one directly.
