# CLAUDE.md

Shared, agent-agnostic instructions live in `AGENTS.md` (also read by Codex).
This file imports them and adds Claude-specific instructions.

@AGENTS.md

## Detailed rules

@.claude/rules/ble-domain-knowledge.md
@.claude/rules/review-and-release.md

## Claude-specific

### Communication

- Chat replies to the maintainer are in **Japanese**; everything written into
  the repository stays English (see `AGENTS.md`).
- Keep technical terms and code identifiers in their original form.

### Skills and tooling

- Cross-checking a review with the Codex pane runs through the
  `herdr-pane-chat` skill. Auto-trigger it whenever the maintainer asks to have
  something confirmed/reviewed by another agent.
- `/code-review <pr>` for PR reviews, `/pr` for opening PRs, `/commit` for
  commits.
- `/goal-codex-review` runs the full multi-round fix ⇄ review loop described in
  `.claude/rules/review-and-release.md`; use it only when explicitly invoked.

### Verification

- Never claim BLE behaviour was verified on hardware unless the `.app` bundle
  was actually launched (`AGENTS.md` → "Running for manual verification").
  Otherwise state plainly that only `swift test` was run.
