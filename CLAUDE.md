# CLAUDE.md

Shared, agent-agnostic instructions live in `AGENTS.md` (also read by Codex).
This file imports them and adds Claude-specific instructions.

@AGENTS.md

## Detailed rules

@.claude/rules/ble-domain-knowledge.md
@.claude/rules/review-and-release.md

## Claude-specific

### Verification

- Never claim BLE behaviour was verified on hardware unless the `.app` bundle
  was actually launched (`AGENTS.md` → "Running for manual verification").
  Otherwise state plainly that only `swift test` was run.
- Do not claim a fix works because the code looks correct; BLE recovery paths
  are callback-ordering sensitive (see
  `.claude/rules/review-and-release.md`).

### Reviews

- When asked to have a change confirmed or reviewed by another agent, follow
  `.claude/rules/review-and-release.md`: report each finding's verdict
  separately instead of silently folding it in.
