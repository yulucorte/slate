#!/usr/bin/env bash
# Usage: hash_path <string>
# Prints an 8-char hash of the input string using whatever hash tool is available.
# Tries: shasum (macOS, many Linux) → sha1sum (Linux coreutils) → cksum (POSIX fallback).

hash_path() {
  local input="$1"
  if command -v shasum >/dev/null 2>&1; then
    echo -n "$input" | shasum | cut -c1-8
  elif command -v sha1sum >/dev/null 2>&1; then
    echo -n "$input" | sha1sum | cut -c1-8
  else
    # POSIX fallback: cksum returns "<crc> <size>", take crc, zero-pad to 8
    printf '%08x' "$(echo -n "$input" | cksum | awk '{print $1}')" | cut -c1-8
  fi
}
