#!/bin/bash
# Verify the running cleaner by writing test URLs to the clipboard.
# The user's current clipboard text is saved and restored afterwards
# (an empty clipboard is cleared again; images/files are not restored).
# Usage: bash macos/selftest.sh [https://www.threads.com/share/XXXX/]

# pbcopy/pbpaste mangle non-ASCII text without a UTF-8 locale (e.g. over SSH).
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

share_url="${1:-}"
saved="$(pbpaste 2>/dev/null)"
fail=0

check() {  # input want wait
  printf '%s' "$1" | pbcopy
  sleep "$3"
  got="$(pbpaste)"
  if [ "$got" = "$2" ]; then echo "PASS $1"; else printf 'FAIL %s\n  want %s\n  got  %s\n' "$1" "$2" "$got"; fail=$((fail + 1)); fi
}

check 'https://www.threads.com/@someone/post/ABC123?xmt=AQGexampleTOKEN_123-xyz' \
      'https://www.threads.com/@someone/post/ABC123' 1.5
check 'https://www.threads.net/@someone/post/ABC123?xmt=AQGexample&slof=1&foo=2' \
      'https://www.threads.net/@someone/post/ABC123?foo=2' 1.5
check 'see https://example.com/?xmt=keep and https://www.threads.com/@a/post/X?xmt=t' \
      'see https://example.com/?xmt=keep and https://www.threads.com/@a/post/X' 1.5
check '看這https://www.threads.com/@a/post/X?xmt=abc，超好' \
      '看這https://www.threads.com/@a/post/X，超好' 1.5
check 'link (https://www.threads.com/@a/post/X?xmt=abc) end' \
      'link (https://www.threads.com/@a/post/X) end' 1.5
check 'https://www.threads.com/@someone/post/ABC123' \
      'https://www.threads.com/@someone/post/ABC123' 1.5

if [ -n "$share_url" ]; then
  printf '%s' "$share_url" | pbcopy
  sleep 5
  got="$(pbpaste)"
  if [[ "$got" =~ ^https://www\.threads\.(com|net)/@[^/]+/post/[^?]+$ ]]; then echo "PASS $share_url -> $got"
  else echo "FAIL $share_url -> $got"; fail=$((fail + 1)); fi
fi

printf '%s' "$saved" | pbcopy
if [ "$fail" -gt 0 ]; then echo "RESULT=FAIL ($fail)"; exit 1; fi
echo "RESULT=PASS"
