#!/usr/bin/env bash
# End-to-end smoke test: starts the server against a throwaway database,
# drives it over HTTP with curl, then cleans up.
set -euo pipefail

bin="${1:?usage: smoke.sh <server-binary>}"
port="${SMOKE_PORT:-18089}"
db="${SMOKE_DB:-cobol_notes_smoke}"
base="http://127.0.0.1:$port"
log="$(mktemp)"

dropdb --if-exists "$db" >/dev/null 2>&1 || true
createdb "$db"

PORT="$port" DATABASE_URL="dbname=$db" "$bin" >"$log" 2>&1 &
pid=$!
cleanup() {
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  dropdb --if-exists "$db" >/dev/null 2>&1 || true
  rm -f "$log"
}
trap cleanup EXIT

for _ in $(seq 1 50); do
  curl -s -o /dev/null "$base/" && break
  sleep 0.1
done

failures=0
check() { # name, expected, actual
  if [[ "$2" == "$3" ]]; then
    echo "  ok    $1"
  else
    echo "  FAIL  $1: expected '$2', got '$3'"
    failures=$((failures + 1))
  fi
}
contains() { # name, needle, haystack
  if [[ "$3" == *"$2"* ]]; then
    echo "  ok    $1"
  else
    echo "  FAIL  $1: missing '$2'"
    failures=$((failures + 1))
  fi
}
status() { curl -s -o /dev/null -w '%{http_code}' "$@"; }

check "index loads" 200 "$(status "$base/")"
contains "empty state" "No notes yet" "$(curl -s "$base/")"
check "stylesheet" 200 "$(status "$base/style.css")"

check "create note" 303 "$(status --data-urlencode 'title=<b>Groceries</b>' \
  --data-urlencode $'body=milk & eggs\r\nbread' "$base/notes")"
page="$(curl -s "$base/")"
contains "title is escaped" "&lt;b&gt;Groceries&lt;/b&gt;" "$page"
contains "body snippet is escaped" "milk &amp; eggs bread" "$page"

id="$(grep -o 'href="/notes/[0-9]*"' <<<"$page" | head -1 | grep -o '[0-9]*')"
check "note page" 200 "$(status "$base/notes/$id")"
contains "edit form keeps newlines" $'milk &amp; eggs\r\nbread</textarea>' \
  "$(curl -s "$base/notes/$id")"

check "update note" 303 "$(status -d 'title=Errands&body=post+office' "$base/notes/$id")"
contains "update persisted" 'value="Errands"' "$(curl -s "$base/notes/$id")"

contains "search finds note" "Errands" "$(curl -s "$base/?q=POST")"
contains "search misses" "No notes match" "$(curl -s "$base/?q=zzzz")"

check "delete note" 303 "$(status -X POST "$base/notes/$id/delete")"
check "deleted note is gone" 404 "$(status "$base/notes/$id")"

check "unknown path" 404 "$(status "$base/nope")"
check "non-numeric id" 404 "$(status "$base/notes/abc")"
check "wrong method" 405 "$(status -X PUT "$base/")"
check "oversized body" 413 "$(head -c 300000 /dev/zero | tr '\0' a | \
  status --data-binary @- "$base/notes")"

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures smoke check(s) failed. Server log:"
  cat "$log"
  exit 1
fi
echo "all smoke checks passed"
