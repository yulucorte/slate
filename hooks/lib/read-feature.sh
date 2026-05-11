#!/usr/bin/env bash
# Usage: read-feature.sh <markdown-file> <FEAT-NNN>
# Emits key=value lines to stdout: title, branch, plan, verification, verified, notes
# Returns:
#   0  on success
#   1  if feature ID not found in file
#   2  if feature found but Branch: field missing

set -u

FILE="$1"
ID="$2"

awk -v id="$ID" '
  BEGIN { found=0; capturing_notes=0; notes="" }
  $0 ~ "^## "id":" {
    found=1
    sub("^## "id": *", "")
    print "title=" $0
    next
  }
  /^## FEAT-/ && found {
    if (capturing_notes && notes != "") print "notes=" notes
    exit
  }
  found && /^### Notes/ {
    capturing_notes=1
    next
  }
  found && capturing_notes {
    if (notes == "") {
      notes=$0
    } else {
      notes=notes "\\n" $0
    }
    next
  }
  found && /^- \*\*Branch\*\*:/ {
    sub(/^- \*\*Branch\*\*: */, "")
    sub(/[[:space:]]*$/, "")
    print "branch=" $0
    next
  }
  found && /^- \*\*Plan\*\*:/ {
    sub(/^- \*\*Plan\*\*: */, "")
    sub(/[[:space:]]*$/, "")
    print "plan=" $0
    next
  }
  found && /^- \*\*Verification\*\*:/ {
    sub(/^- \*\*Verification\*\*: */, "")
    sub(/[[:space:]]*$/, "")
    sub(/^`/, ""); sub(/`$/, "")
    print "verification=" $0
    next
  }
  found && /^- \*\*Verified\*\*:/ {
    sub(/^- \*\*Verified\*\*: */, "")
    sub(/[[:space:]]*$/, "")
    print "verified=" $0
    next
  }
  END {
    if (!found) exit 1
    if (capturing_notes && notes != "") print "notes=" notes
  }
' "$FILE" > /tmp/read-feature.$$
rc=$?
if [ "$rc" -ne 0 ]; then
  rm -f /tmp/read-feature.$$
  exit 1
fi

if ! grep -q '^branch=' /tmp/read-feature.$$; then
  rm -f /tmp/read-feature.$$
  exit 2
fi

cat /tmp/read-feature.$$
rm -f /tmp/read-feature.$$
