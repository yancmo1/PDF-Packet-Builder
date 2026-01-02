#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

slugify() {
  # lowercase; non-alnum -> '-'; collapse '-' ; trim edges
  local input
  input="$1"
  printf '%s' "$input" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/-+/-/g; s/^-+//; s/-+$//' \
    | sed -E 's/^$/(no-topic)/'
}

now_date() {
  date '+%Y-%m-%d'
}

now_ts() {
  date '+%Y%m%d-%H%M'
}

editor_open() {
  local editor
  if command -v code-insiders >/dev/null 2>&1; then
    editor="code-insiders"
  else
    editor="code"
  fi

  "${editor}" -r -- "$@" 2>/dev/null || "${editor}" -- "$@"
}

copy_to_clipboard() {
  if command -v pbcopy >/dev/null 2>&1; then
    pbcopy
    return 0
  fi
  if command -v wl-copy >/dev/null 2>&1; then
    wl-copy
    return 0
  fi
  if command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard
    return 0
  fi
  if command -v clip.exe >/dev/null 2>&1; then
    clip.exe
    return 0
  fi
  return 1
}

paste_from_clipboard() {
  if command -v pbpaste >/dev/null 2>&1; then
    pbpaste
    return 0
  fi
  if command -v wl-paste >/dev/null 2>&1; then
    wl-paste
    return 0
  fi
  if command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard -o
    return 0
  fi
  if command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -Command Get-Clipboard
    return 0
  fi
  return 1
}

escape_sed_replacement() {
  # Escape &, \, |, and / for safe sed replacement with | delimiter.
  printf '%s' "$1" | sed -e 's/[\\/&|]/\\\\&/g'
}

read -r -p "PR number (numeric): " PR_NUM
if [[ ! "${PR_NUM}" =~ ^[0-9]+$ ]]; then
  echo "Error: PR number must be numeric (e.g., 21)." >&2
  exit 1
fi

read -r -p "Topic (short, free text): " TOPIC
TOPIC_SLUG="$(slugify "${TOPIC}")"

STAMP_DATE="$(now_date)"
STAMP_TS="$(now_ts)"

REVIEW_FILENAME="PR_REVIEW_${STAMP_DATE}_pr-${PR_NUM}_${TOPIC_SLUG}.md"
REPLY_FILENAME="PR_REPLY_${STAMP_TS}_pr-${PR_NUM}_${TOPIC_SLUG}.md"
HANDOFF_FILENAME="PR_HANDOFF_${STAMP_TS}_pr-${PR_NUM}_${TOPIC_SLUG}.md"

TEMPLATE_PATH="${ROOT_DIR}/.vscode/pr_check_prompt_template.md"
if [[ ! -f "${TEMPLATE_PATH}" ]]; then
  echo "Error: Missing template at ${TEMPLATE_PATH}" >&2
  exit 1
fi

PR_NUM_ESC="$(escape_sed_replacement "${PR_NUM}")"
TOPIC_ESC="$(escape_sed_replacement "${TOPIC}")"
REVIEW_ESC="$(escape_sed_replacement "${REVIEW_FILENAME}")"
REPLY_ESC="$(escape_sed_replacement "${REPLY_FILENAME}")"

PROMPT_CONTENT="$(cat "${TEMPLATE_PATH}" \
  | sed -e "s|{{PR_NUMBER}}|${PR_NUM_ESC}|g" \
        -e "s|{{SHORT_TOPIC}}|${TOPIC_ESC}|g" \
        -e "s|{{REVIEW_FILENAME}}|${REVIEW_ESC}|g" \
        -e "s|{{REPLY_FILENAME}}|${REPLY_ESC}|g" \
)"

echo "Review artifact: docs/reviews/${REVIEW_FILENAME}"
echo "Reply scratchpad: docs/reviews/${REPLY_FILENAME}"
echo "Handoff file (if needed): docs/reviews/${HANDOFF_FILENAME}"
echo ""

if printf '%s' "${PROMPT_CONTENT}" | copy_to_clipboard; then
  echo "Prompt copied to clipboard."
else
  echo "Clipboard copy unsupported; printing prompt below:" >&2
  echo ""
  printf '%s\n' "${PROMPT_CONTENT}"
fi
