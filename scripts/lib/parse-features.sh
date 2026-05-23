#!/usr/bin/env bash
# Helpers to extract feature data from features/*.md (Markdown only, no JSON).

# Usage: list_feature_ids <file>
# Prints all FEAT-XXX IDs found in the file, one per line.
list_feature_ids() {
  grep -E '^## FEAT-[0-9]+:' "$1" 2>/dev/null | sed -E 's/^## (FEAT-[0-9]+):.*/\1/'
}

# Usage: next_feature_id <dir>
# Reads all *.md in dir, finds max FEAT-NNN, prints next.
next_feature_id() {
  local dir="${1:-features}"
  local max
  max=$(grep -hE '^## FEAT-[0-9]+:' "$dir"/*.md 2>/dev/null \
        | sed -E 's/^## FEAT-([0-9]+):.*/\1/' \
        | sort -n | tail -1)
  if [ -z "$max" ]; then
    echo "FEAT-001"
  else
    printf "FEAT-%03d\n" $((10#$max + 1))
  fi
}

# Usage: feature_status <file> <FEAT-XXX>
# Prints the Status: value for the given feature.
feature_status() {
  awk -v id="$2" '
    $0 ~ "^## "id":" {found=1}
    found && /^- \*\*Status\*\*:/ {
      sub(/^- \*\*Status\*\*: */, "")
      print
      exit
    }
    /^## FEAT-/ && found && $0 !~ "^## "id":" {exit}
  ' "$1"
}

# Usage: count_subtasks <file> <FEAT-XXX> <pattern>
# Counts subtasks containing pattern as a literal string (e.g. "[ ]" or "[x]").
# Uses index() to avoid regex bracket-class interpretation from awk -v escape processing.
count_subtasks() {
  awk -v id="$2" -v pat="$3" '
    $0 ~ "^## "id":" {found=1; next}
    /^## FEAT-/ && found {exit}
    found && index($0, pat) {count++}
    END {print count+0}
  ' "$1"
}

# Usage: check_complete <file> <FEAT-XXX>
# Prints COMPLETE, INCOMPLETE, or UNKNOWN.
#  - UNKNOWN: feature ID not found in file
#  - INCOMPLETE: feature has at least one "[ ]" subtask, OR has zero subtasks
#  - COMPLETE: feature has >=1 "[x]" subtask AND zero "[ ]" subtasks
check_complete() {
  local file="$1" id="$2"
  grep -qE "^## ${id}:" "$file" 2>/dev/null || { echo "UNKNOWN"; return; }
  local checked unchecked
  checked=$(count_subtasks "$file" "$id" "[x]")
  unchecked=$(count_subtasks "$file" "$id" "[ ]")
  if [ "${unchecked:-0}" -gt 0 ] || [ "${checked:-0}" -eq 0 ]; then
    echo "INCOMPLETE"
  else
    echo "COMPLETE"
  fi
}

# If sourced, expose functions; if executed, print usage hint.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo "This is a library. Source it: source $(basename "$0")"
fi
