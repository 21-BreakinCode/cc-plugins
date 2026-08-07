### Guard external API responses
- **What:** null-check payloads from the ads API before indexing.
- **Evidence:** PR #101 (https://x/c1) · commit deadbee — 2026-07-01
- **Why it matters:** unchecked payloads caused the 2026-07 hotfix.
