~~~markdown
# Portable PR Check Workflow Spec (VS Code Tasks + Bash)

**Purpose:** A reusable, copy‑pasteable “PR check” workflow that standardizes how you generate a PR‑review prompt, where you store review artifacts, and how you create (optional) PR reply and implementation handoff notes.

This workflow is designed to be portable across repositories with minimal dependencies (**Bash** + **clipboard tooling** when available).

---

## What this workflow is for

### Primary outcomes

1. **Fast, consistent PR review prompt** (copied to clipboard or printed to terminal)
   - Review‑only mode: **“Review only—do not implement.”**
   - References repo authority docs (e.g., `.github/copilot-instructions.md`, `WORKSPACE_LIVING_DOC.md`).
   - Forces a structured review response with a final **copy/paste PR reply** block.

2. **Standard artifact location** in the repo
   - All PR review artifacts and handoffs live under: `docs/reviews/`

3. **Two optional helper files**
   - A **PR reply scratchpad** file (for the final PR comment you’ll paste into GitHub).
   - An **implementation handoff** markdown file captured from clipboard (to hand to an implementer/agent).

### Non-goals

- Does **not** fetch PR diffs automatically.
- Does **not** require GitHub CLI.
- Does **not** enforce a specific tech stack; it standardizes *review output and storage*.

---

## Repo conventions

### Required folder

- `docs/reviews/` — store PR review artifacts, replies, and handoffs.

### Recommended artifact naming

> Conventions—adjust if your org has a different standard.

- **Review artifact (manual or Copilot‑generated content)**
  - `docs/reviews/PR_REVIEW_YYYY-MM-DD_pr-<PRNUM>_<topic-slug>.md`

- **Reply scratchpad (created by task/script)**
  - `docs/reviews/PR_REPLY_YYYYMMDD-HHMM_pr-<PRNUM>_<topic-slug>.md`

- **Implementation handoff (created from clipboard)**
  - `docs/reviews/PR_HANDOFF_YYYYMMDD-HHMM_pr-<PRNUM>_<topic-slug>.md`

---

## Components

### 1) VS Code tasks

Add 3 tasks in `.vscode/tasks.json`:

- **🧾 PR Check: Copy Prompt**
  - Runs a script that:
    - prompts for PR number + short topic,
    - fills a prompt template,
    - copies the prompt to clipboard when possible (otherwise prints),
    - prints the suggested filenames (review/reply/handoff) for quick reference.

- **📝 PR Reply: Create/Open Reply File**
  - Creates a reply scratchpad file under `docs/reviews/`.
  - Ensures a `## Copy/paste PR reply` section exists (idempotent).
  - Opens the file in VS Code (prefers Insiders when available).

- **🧩 PR Handoff: Save Markdown from Clipboard**
  - Takes clipboard contents and writes a handoff markdown file under `docs/reviews/`.
  - Opens the file.

**Task presentation guidance (recommended):**
- `presentation.reveal = "always"`
- `presentation.panel = "new"`
- `problemMatcher = []`

This keeps each run visible and avoids reusing an existing terminal panel.

---

### 2) Prompt template

Store a prompt template at:

- `.vscode/pr_check_prompt_template.md`

Template requirements:

- Placeholders:
  - `{{PR_NUMBER}}`
  - `{{SHORT_TOPIC}}`
  - `{{REVIEW_FILENAME}}` (recommended)
  - `{{REPLY_FILENAME}}` (optional)

- The template must instruct Copilot to:
  - operate in **PR check / review‑only** mode,
  - follow the repo’s **authority docs**,
  - produce a structured review output,
  - include a final **Copy/paste PR reply** block.

> Portability note: keep the authority doc list short and repo‑specific. If a repo lacks your preferred docs, point to what it *does* have (e.g., `CONTRIBUTING.md`, `docs/ARCHITECTURE.md`, `docs/DEV_RUNBOOK.md`).

---

### 3) Scripts

Store scripts at:

- `.vscode/pr_check_start.sh`
- `.vscode/pr_reply_create.sh`
- `.vscode/pr_handoff_from_clipboard.sh`

All scripts should:

- derive `ROOT_DIR` relative to their own location,
- create `docs/reviews/` if missing,
- validate inputs (PR number must be numeric),
- slugify the topic for filenames,
- use `set -euo pipefail` for safer execution.

Recommended filename slug rules:

- lowercase
- replace non‑alphanumeric with `-`
- collapse repeated `-`
- trim leading/trailing `-`

---

## UX flow (happy path)

1. Run **🧾 PR Check: Copy Prompt**.
2. Enter:
   - PR number (e.g., `64`)
   - short topic (e.g., `auth-guard-headers`)
3. Paste prompt into Copilot Chat and send.
4. Copilot returns:
   - findings + required changes + optional improvements,
   - file-by-file notes,
   - concrete suggested edits,
   - plus a final **Copy/paste PR reply** block.
5. (Optional) Run **📝 PR Reply** to create/open a reply file; paste the reply block there, then into GitHub.
6. (Optional) Copy an implementation handoff from chat and run **🧩 PR Handoff** to save it to `docs/reviews/`.

---

## Prompt template spec (portable baseline)

### Authority docs (repo-specific)

The prompt should name the authoritative docs for the target repo, for example:

- `.github/copilot-instructions.md`
- `WORKSPACE_LIVING_DOC.md`

If those don’t exist, prefer in this order:

1. `CONTRIBUTING.md`
2. `docs/ARCHITECTURE.md`
3. `docs/DEV_RUNBOOK.md`
4. `README.md`

### Required headings (review output)

To keep output consistent, require these headings:

1. Scope and intent
2. Findings summary (High / Medium / Low)
3. Decision required (if applicable)
4. Required changes
5. Approval criteria
6. File-by-file notes
7. Concrete suggested edits
8. Copy/paste PR reply (final block)

### PR reply block (required)

Enforce a terse PR reply block at the end:

- Decision: **Approve / Request changes / Block**
- Risk: **High / Medium / Low**
- Required actions (3–8 bullets, or “No required changes”)

---

## Implementation details (reference behavior)

### `pr_check_start.sh` (copy prompt)

Behavior:

- Prompts for `PR_NUM` and `TOPIC`.
- Computes:
  - `TOPIC_SLUG`
  - `STAMP_DATE` (YYYY-MM-DD)
  - `STAMP_TS` (YYYYMMDD-HHMM)
- Computes suggested filenames:
  - `REVIEW_FILENAME=PR_REVIEW_${STAMP_DATE}_pr-${PR_NUM}_${TOPIC_SLUG}.md`
  - `REPLY_FILENAME=PR_REPLY_${STAMP_TS}_pr-${PR_NUM}_${TOPIC_SLUG}.md`
  - `HANDOFF_FILENAME=PR_HANDOFF_${STAMP_TS}_pr-${PR_NUM}_${TOPIC_SLUG}.md`
- Reads `.vscode/pr_check_prompt_template.md` and substitutes placeholders.
- Copies prompt to clipboard if supported; otherwise prints to terminal.
- Does **not** create any files.

Rationale: generating the prompt should be “cheap” and safe; it should not write artifacts until you opt in.

### `pr_reply_create.sh` (create/open reply scratchpad)

Behavior:

- Prompts for `PR_NUM` and `TOPIC`.
- Creates `docs/reviews/${REPLY_FILENAME}` if missing with:
  - a brief header (PR number, topic, date/time),
  - a `## Copy/paste PR reply` section,
  - an optional `## Notes / Follow-ups` section.
- Ensures the reply section exists even if the file already exists.
- Opens the file in VS Code (`code-insiders` if available, else `code`).

### `pr_handoff_from_clipboard.sh` (save handoff)

Behavior:

- Prompts for `PR_NUM` and `TOPIC`.
- Reads clipboard contents and writes them into `docs/reviews/${HANDOFF_FILENAME}`.
- Fails with a clear error if clipboard read is not supported.
- Opens the file in VS Code.

---

## Portability & OS support

### macOS (works out of the box)

- Clipboard copy: `pbcopy`
- Clipboard paste: `pbpaste`

### Linux

Preferred clipboard utilities:

- Wayland: `wl-copy` / `wl-paste`
- X11: `xclip -selection clipboard` (copy) and `xclip -selection clipboard -o` (paste)

Recommended abstraction inside scripts:

- `copy_to_clipboard()` chooses `pbcopy`, then `wl-copy`, then `xclip -selection clipboard`
- `paste_from_clipboard()` chooses `pbpaste`, then `wl-paste`, then `xclip -selection clipboard -o`

### Windows

Recommended options:

- Run scripts under WSL and bridge clipboard:
  - Copy: `clip.exe`
  - Paste: `powershell.exe -NoProfile -Command Get-Clipboard`
- Or reimplement scripts as PowerShell tasks.

---

## “Copy this to another repo” checklist

1. Copy these files:
   - `.vscode/tasks.json` (or merge the 3 tasks into your existing tasks)
   - `.vscode/pr_check_prompt_template.md`
   - `.vscode/pr_check_start.sh`
   - `.vscode/pr_reply_create.sh`
   - `.vscode/pr_handoff_from_clipboard.sh`

2. Ensure folder exists (or let scripts create it):
   - `docs/reviews/`

3. Update prompt template for the repo:
   - authority docs list,
   - stack-specific expectations (if any),
   - any repo naming metadata (optional).

4. Make scripts executable:
   - macOS/Linux: `chmod +x .vscode/*.sh`

---

## Nice-to-have enhancements (future)

- Prompt for repo owner/name and substitute `{{REPO}}` in the template.
- Detect presence of authority docs and warn if missing.
- Add a “Save PR_REVIEW artifact from clipboard” task (parallel to the handoff task).
- Allow passing `PR_NUM` and `TOPIC` as optional CLI args (for automation).

---

## Minimal security reminder

Use this workflow to consistently enforce review expectations:

- UI gating is not authorization.
- Server-side checks and authorization must be verified (where applicable).
- Validate input handling and permission boundaries, not just UI behavior.

---
~~~markdown
