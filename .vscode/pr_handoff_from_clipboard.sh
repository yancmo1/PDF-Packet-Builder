#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

slugify() {
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

read -r -p "PR number (numeric): " PR_NUM
if [[ ! "${PR_NUM}" =~ ^[0-9]+$ ]]; then
  echo "Error: PR number must be numeric (e.g., 21)." >&2
  exit 1
fi

read -r -p "Topic (short, free text): " TOPIC
TOPIC_SLUG="$(slugify "${TOPIC}")"

STAMP_TS="$(now_ts)"
HANDOFF_FILENAME="PR_HANDOFF_${STAMP_TS}_pr-${PR_NUM}_${TOPIC_SLUG}.md"
HANDOFF_PATH="${ROOT_DIR}/docs/reviews/${HANDOFF_FILENAME}"

mkdir -p "${ROOT_DIR}/docs/reviews"

if ! CLIP_CONTENT="$(paste_from_clipboard)"; then
  echo "Error: Clipboard paste is not supported on this system (pbpaste/wl-paste/xclip/powershell.exe)." >&2
  exit 1
fi

if [[ -z "${CLIP_CONTENT//[[:space:]]/}" ]]; then
  echo "Error: Clipboard is empty (or contains only whitespace). Copy the markdown first, then retry." >&2
  exit 1
fi

{
  echo "# PR Handoff — PR #${PR_NUM} — ${TOPIC}"
  echo ""
  echo "Created: $(date '+%Y-%m-%d %H:%M %z')"
  echo "Source: Clipboard"
  echo ""
  echo "---"
  echo ""
  printf '%s\n' "${CLIP_CONTENT}"
  echo ""
} > "${HANDOFF_PATH}"

echo "Handoff file: docs/reviews/${HANDOFF_FILENAME}"
editor_open "${HANDOFF_PATH}"
