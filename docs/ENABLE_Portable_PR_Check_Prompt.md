~~~markdown
# VS Code Agent Prompt — Enable “Portable PR Check” Workflow (Tasks + Scripts)

## Role
You are a repository automation engineer. Implement the “Portable PR Check” workflow in **this repo** by adding VS Code tasks, a prompt template, and three Bash scripts. Keep it portable across workspaces and OSes.

## Non-negotiables
- Do **not** change application code (this is editor tooling only).
- Create/modify only the files listed below.
- Keep behavior **idempotent** (re-running scripts should not break anything).
- Prefer **Bash** for scripts; no GitHub CLI dependency.
- Use `docs/reviews/` as the canonical artifact directory.

---

## Deliverables (files to create or update)

### 1) Create folder (if missing)
- `docs/reviews/` (directory)

### 2) Create prompt template
- `.vscode/pr_check_prompt_template.md`

### 3) Create scripts
- `.vscode/pr_check_start.sh`
- `.vscode/pr_reply_create.sh`
- `.vscode/pr_handoff_from_clipboard.sh`

### 4) Update VS Code tasks
- `.vscode/tasks.json` (create if missing; otherwise merge tasks without breaking existing tasks)

---

## Acceptance criteria (must pass)

### A) PR prompt generation (task: “🧾 PR Check: Copy Prompt”)
- Prompts for:
  - PR number (numeric)
  - Topic (free text)
- Computes:
  - topic slug (lowercase, non-alnum → `-`, collapse `-`, trim edges)
  - date stamps (`YYYY-MM-DD` and `YYYYMMDD-HHMM`)
- Substitutes placeholders in `.vscode/pr_check_prompt_template.md`:
  - `{{PR_NUMBER}}`
  - `{{SHORT_TOPIC}}`
  - `{{REVIEW_FILENAME}}`
  - `{{REPLY_FILENAME}}`
- Copies the final prompt to clipboard when supported; otherwise prints it to terminal.
- **Does not write any files** (by design).
- Always prints the suggested filenames and their `docs/reviews/…` paths for reference.

### B) PR reply scratchpad (task: “📝 PR Reply: Create/Open Reply File”)
- Prompts for PR number and topic.
- Creates `docs/reviews/PR_REPLY_YYYYMMDD-HHMM_pr-<PRNUM>_<topic-slug>.md` if missing.
- Ensures the file contains:
  - a header with PR number/topic + created timestamp
  - `## Copy/paste PR reply`
  - `## Notes / Follow-ups`
- If the file already exists, ensure the `## Copy/paste PR reply` section still exists (idempotent).
- Opens the file in VS Code:
  - Prefer `code-insiders` if available; else `code`.

### C) PR handoff from clipboard (task: “🧩 PR Handoff: Save Markdown from Clipboard”)
- Prompts for PR number and topic.
- Reads clipboard content using the best available tool on the OS.
- Writes it to `docs/reviews/PR_HANDOFF_YYYYMMDD-HHMM_pr-<PRNUM>_<topic-slug>.md`.
- Fails with a clear error message if clipboard paste is unavailable.
- Opens the file in VS Code (prefer Insiders).

### D) Portability
- macOS: uses `pbcopy` / `pbpaste`
- Linux: supports Wayland (`wl-copy`/`wl-paste`) and X11 (`xclip`)
- Windows: if running in WSL, support:
  - copy: `clip.exe`
  - paste: `powershell.exe -NoProfile -Command Get-Clipboard`
- Clipboard selection logic must be inside helper functions in scripts.

---

## Implementation instructions

### 1) `.vscode/pr_check_prompt_template.md` (create)

Create a portable template that:
- States “review-only; do not implement”
- Lists authority docs **with a fallback** if not present
- Requires a structured output including a final “Copy/paste PR reply” block
- Mentions the target filenames:
  - `docs/reviews/{{REVIEW_FILENAME}}`
  - `docs/reviews/{{REPLY_FILENAME}}`

Use this exact template content:

```markdown
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
```

---

## 2) Scripts (create)

### Shared script requirements
- Start each script with: `#!/usr/bin/env bash` and `set -euo pipefail`
- Resolve repo root relative to the script location:
  - `SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"`
  - `ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"`
- Ensure `docs/reviews` exists when scripts need it:
  - `mkdir -p "${ROOT_DIR}/docs/reviews"`
- Input validation:
  - PR number must match `^[0-9]+$` (fail otherwise)

### Shared helper functions (recommend copy/paste into all scripts)
Implement these helpers in each script (keep consistent):

- `slugify()`
- `now_date()` → `YYYY-MM-DD`
- `now_ts()` → `YYYYMMDD-HHMM`
- `editor_open()` chooses `code-insiders` else `code`
- `copy_to_clipboard()`:
  1) `pbcopy`
  2) `wl-copy`
  3) `xclip -selection clipboard`
  4) `clip.exe` (WSL)
- `paste_from_clipboard()`:
  1) `pbpaste`
  2) `wl-paste`
  3) `xclip -selection clipboard -o`
  4) `powershell.exe -NoProfile -Command Get-Clipboard` (WSL)

#### Script: `.vscode/pr_check_start.sh` (create)
Behavior:
- Prompt for PR number + topic.
- Compute:
  - `REVIEW_FILENAME=PR_REVIEW_${YYYY-MM-DD}_pr-${PR_NUM}_${TOPIC_SLUG}.md`
  - `REPLY_FILENAME=PR_REPLY_${YYYYMMDD-HHMM}_pr-${PR_NUM}_${TOPIC_SLUG}.md`
- Read `.vscode/pr_check_prompt_template.md`, replace placeholders, and copy/print:
  - Replace `{{PR_NUMBER}}`, `{{SHORT_TOPIC}}`, `{{REVIEW_FILENAME}}`, `{{REPLY_FILENAME}}`
- Attempt clipboard copy; if not supported, print to terminal.
- Print these lines (minimum):
  - `Review artifact: docs/reviews/<name>`
  - `Reply scratchpad: docs/reviews/<name>`
  - `Handoff file (if needed): docs/reviews/<computed PR_HANDOFF_...>`

#### Script: `.vscode/pr_reply_create.sh` (create)
Behavior:
- Prompt for PR number + topic.
- Compute `REPLY_FILENAME` like above.
- Create file if missing with starter content:
  - Title line with PR number + topic
  - Created timestamp
  - Sections:
    - `## Copy/paste PR reply`
    - `## Notes / Follow-ups`
- If file exists, ensure `## Copy/paste PR reply` exists (append if missing).
- Open in VS Code.

#### Script: `.vscode/pr_handoff_from_clipboard.sh` (create)
Behavior:
- Prompt for PR number + topic.
- Read clipboard via `paste_from_clipboard()`; fail if empty or unsupported.
- Compute `HANDOFF_FILENAME=PR_HANDOFF_${YYYYMMDD-HHMM}_pr-${PR_NUM}_${TOPIC_SLUG}.md`
- Write clipboard content to file (include a short header above the pasted content).
- Open in VS Code.

---

## 3) VS Code tasks (update)

Update or create `.vscode/tasks.json` to include **exactly** these tasks (merging safely if file exists). Do not remove existing tasks.

### Task requirements
- `type`: `"shell"`
- Ensure they run from `${workspaceFolder}`
- Use `presentation.reveal = "always"` and `presentation.panel = "new"`
- Use `problemMatcher: []`

### Tasks to add
Add these tasks with these labels and commands:

1) **🧾 PR Check: Copy Prompt**
- command:
  - `bash .vscode/pr_check_start.sh`

2) **📝 PR Reply: Create/Open Reply File**
- command:
  - `bash .vscode/pr_reply_create.sh`

3) **🧩 PR Handoff: Save Markdown from Clipboard**
- command:
  - `bash .vscode/pr_handoff_from_clipboard.sh`

If the repo already has a tasks.json with a `version` and `tasks` array, merge by appending these tasks unless a task with the same `label` already exists; if it does, update it to match this spec.

---

## Final step
After implementing:
1) Ensure scripts are executable on macOS/Linux:
   - `chmod +x .vscode/*.sh`
2) Provide a short summary in the PR description or commit message of what was added.

---

## Output format for your work
- Implement the changes in the repo files.
- If you are responding in chat, include:
  - a file tree of what changed
  - any merge notes (e.g., how tasks.json was merged)
  - no extra commentary beyond what’s needed to run the workflow.
~~~markdown
