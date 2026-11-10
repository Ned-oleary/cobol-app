#!/usr/bin/env bash
# Simple output-based test: runs the binary and compares against expected output.
set -euo pipefail
bin="${1:?usage: run.sh <binary>}"
expected="Hello from COBOL!"
actual="$("$bin")"
if [[ "$actual" == "$expected" ]]; then
  echo "PASS"
else
  echo "FAIL: expected '$expected', got '$actual'" >&2
  exit 1
fi
