# PR Check (Review-Only) — PR #{{PR_NUMBER}} — {{SHORT_TOPIC}}

You are reviewing a pull request. **Review-only mode: do not implement changes.**

## Authority docs (follow in priority order)
1) .github/copilot-instructions.md (if present)
2) WORKSPACE_LIVING_DOC.md (if present)
3) CONTRIBUTING.md (if present)
4) docs/ARCHITECTURE.md (if present)
5) docs/DEV_RUNBOOK.md (if present)
6) README.md (fallback)

## Inputs
- PR number: {{PR_NUMBER}}
- Topic: {{SHORT_TOPIC}}

## Required output
1) Scope and intent
2) Findings summary (High / Medium / Low)
3) Decision required (if applicable)
4) Required changes
5) Approval criteria
6) File-by-file notes
7) Concrete suggested edits (show exact patches or code blocks as needed)
8) Copy/paste PR reply (final block)

## Artifact instructions
- Create or provide the complete contents for:
  - docs/reviews/{{REVIEW_FILENAME}}
- Your response must end with a **Copy/paste PR reply** block suitable for GitHub.
- Optional: I may paste that reply into:
  - docs/reviews/{{REPLY_FILENAME}}
