#!/usr/bin/env bash
# Usage:
#   exec 9>"/path/to/lockfile"
#   bash acquire-lock.sh <timeout-seconds> 9
# Returns 0 on success, non-zero on timeout.
# Caller is responsible for opening the file descriptor and releasing the lock
# (release happens automatically when the FD is closed / shell exits).

TIMEOUT="${1:-5}"
FD="${2:-9}"

flock -w "$TIMEOUT" "$FD"
