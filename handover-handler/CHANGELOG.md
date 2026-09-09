# Changelog

## 0.3.0 — 2026-09-09

- **feat:** add Acceptance Criteria section to `/hh:new` template between To-Be
  and Implementation Note. Phase 3.5 confirms AC items with the user via
  AskUserQuestion before writing. Supports checkbox and Given/When/Then formats.
- **feat:** inline STE writing rules in Phase 4 — sentence limits, active voice,
  simple tenses, banned-word kill list. Every handover doc comes out clean on
  first write without a separate skill invocation.
- **feat:** inline ASCII diagram guidance in Phase 4 — add a compact diagram when
  a section describes something with shape (flow, nesting, branching). Skip
  diagrams for flat lists and linear definitions.
- **chore:** expand word budget from 330 to 400 words (~2 min read) to
  accommodate the new AC section.

## 0.2.0 — 2026-08-11

- **feat!:** `HH_LIFEOS_ROOT` is now required. The hardcoded iCloud vault path
  is gone from all 9 call sites; commands fail fast with setup guidance instead of
  falling back to a path that may not exist. Set it once in `~/.zshrc`.
- **feat:** add `lib/lifeos-root.sh` — single resolver + guard for the vault root,
  used by every command and lib.
- **feat:** `/hh:init-service` now defaults `app_name` to the repo's kebab-case
  directory name instead of PascalCase (`creative-studio`, not `CreativeStudio`).
- **fix:** `HH_ARCHIVE_ROOT` defaults to `$VAULT/04Archive` instead of a second
  hardcoded iCloud path.
- **fix:** `/hh:new` reports a dangling `./handover` symlink with a real remedy
  (re-run `/hh:init-service`) instead of blaming iCloud sync.

## 0.1.5 — 2026-06-05

- **feat:** accept dynamic destination path via ARCHIVE_ROOT env var

## 0.1.4 — 2026-06-04

- **fix:** quote CLAUDE_PLUGIN_ROOT so bash expands it

## 0.1.3 — 2026-06-01

- **chore:** bump to trigger reload-plugins refresh

## 0.1.2 — 2026-06-01

- **chore:** align plugin manifest version with marketplace entry

## 0.1.1 — 2026-06-01

- **fix:** gate stop-offer-new on ./handover symlink

## 0.1.0 — 2026-05-31

- **feat:** initial release — LifeOS handover document management
- **feat:** add /hh:init-org, /hh:init-service, /hh:new, /hh:wrap-up commands
- **feat:** TL;DR/Context/As-Is/To-Be/Implementation-Note seed body framework
