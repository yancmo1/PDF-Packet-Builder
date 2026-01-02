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

REPLY_FILENAME="PR_REPLY_${STAMP_TS}_pr-${PR_NUM}_${TOPIC_SLUG}.md"
REPLY_PATH="${ROOT_DIR}/docs/reviews/${REPLY_FILENAME}"

mkdir -p "${ROOT_DIR}/docs/reviews"

if [[ ! -f "${REPLY_PATH}" ]]; then
  {
    echo "# PR Reply Scratchpad — PR #${PR_NUM} — ${TOPIC}"
    echo ""
    echo "Created: $(date '+%Y-%m-%d %H:%M %z')"
    echo ""
    echo "## Copy/paste PR reply"
    echo ""
    echo "(Paste the final GitHub reply block here.)"
    echo ""
    echo "## Notes / Follow-ups"
    echo ""
  } > "${REPLY_PATH}"
fi

if ! grep -q '^## Copy/paste PR reply$' "${REPLY_PATH}"; then
  {
    echo ""
    echo "## Copy/paste PR reply"
    echo ""
  } >> "${REPLY_PATH}"
fi

if ! grep -q '^## Notes / Follow-ups$' "${REPLY_PATH}"; then
  {
    echo ""
    echo "## Notes / Follow-ups"
    echo ""
  } >> "${REPLY_PATH}"
fi

echo "Reply scratchpad: docs/reviews/${REPLY_FILENAME}"
editor_open "${REPLY_PATH}"
