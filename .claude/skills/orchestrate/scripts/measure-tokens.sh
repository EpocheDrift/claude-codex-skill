#!/usr/bin/env bash
#
# measure-tokens.sh — Measure Claude token usage from session JSONL files.
#
# Usage:
#   measure-tokens.sh <session.jsonl>
#   measure-tokens.sh <session1.jsonl> <session2.jsonl>   # compare two sessions
#
# Parses Claude Code session JSONL files from ~/.claude/projects/
# and extracts per-message usage data (input, output, cache creation, cache read).

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: measure-tokens.sh <session.jsonl> [session2.jsonl]"
  echo ""
  echo "Single session: prints token usage summary"
  echo "Two sessions:   prints comparison (session1 = baseline, session2 = smart)"
  exit 1
fi

SESSION1="$1"
SESSION2="${2:-}"

if [ ! -f "$SESSION1" ]; then
  echo "Error: File not found: $SESSION1"
  exit 1
fi

extract_usage() {
  local file="$1"
  python3 -c "
import json, sys

output_tokens = 0
input_tokens = 0
cache_creation = 0
cache_read = 0
api_calls = 0

for line in open(sys.argv[1]):
    line = line.strip()
    if not line:
        continue
    try:
        obj = json.loads(line)
    except json.JSONDecodeError:
        continue
    usage = obj.get('message', {}).get('usage', {})
    if not usage:
        continue
    api_calls += 1
    output_tokens += usage.get('output_tokens', 0)
    input_tokens += usage.get('input_tokens', 0)
    cache_creation += usage.get('cache_creation_input_tokens', 0)
    cache_read += usage.get('cache_read_input_tokens', 0)

non_cached = input_tokens - cache_read
print(f'{output_tokens}|{input_tokens}|{cache_creation}|{cache_read}|{non_cached}|{api_calls}')
" "$file"
}

print_usage() {
  local label="$1"
  local data="$2"
  IFS='|' read -r output input cache_create cache_read non_cached calls <<< "$data"
  echo "=== $label ==="
  echo "  Output tokens:       $output"
  echo "  Input tokens:        $input"
  echo "  Cache creation:      $cache_create"
  echo "  Cache read:          $cache_read"
  echo "  Non-cached input:    $non_cached"
  echo "  API calls:           $calls"
  echo ""
}

DATA1=$(extract_usage "$SESSION1")
print_usage "Session: $(basename "$SESSION1")" "$DATA1"

if [ -n "$SESSION2" ]; then
  if [ ! -f "$SESSION2" ]; then
    echo "Error: File not found: $SESSION2"
    exit 1
  fi

  DATA2=$(extract_usage "$SESSION2")
  print_usage "Session: $(basename "$SESSION2")" "$DATA2"

  # Compare
  python3 -c "
import sys
d1 = sys.argv[1].split('|')
d2 = sys.argv[2].split('|')
labels = ['Output tokens', 'Input tokens', 'Cache creation', 'Cache read', 'Non-cached input', 'API calls']

print('=== COMPARISON ===')
print(f'{\"Metric\":<20} {\"Baseline\":>12} {\"Smart\":>12} {\"Savings\":>10}')
print('-' * 56)
for i, label in enumerate(labels):
    v1 = int(d1[i])
    v2 = int(d2[i])
    if v1 > 0:
        pct = ((v1 - v2) / v1) * 100
        print(f'{label:<20} {v1:>12,} {v2:>12,} {pct:>+9.1f}%')
    else:
        print(f'{label:<20} {v1:>12,} {v2:>12,} {\"N/A\":>10}')
" "$DATA1" "$DATA2"
fi
