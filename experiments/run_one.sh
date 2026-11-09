#!/bin/sh
# usage: run_one.sh <label> <dir> [prompt-file]
set -u
LABEL="$1"; DIR="$2"
OUT="$(cd "$(dirname "$0")" && pwd)"
PROMPT="$(cat "${3:-$OUT/prompt.txt}")"
cd "$DIR" || exit 1
START=$(date +%s)
env -u CLAUDECODE timeout 5400 claude -p "$PROMPT" \
  --model claude-opus-5-5 \
  --permission-mode acceptEdits \
  --allowedTools "Read,Write,Edit,Glob,Grep,Bash(flutter:*),Bash(dart:*),Bash(ls:*),Bash(cat:*),Bash(mkdir:*),Bash(find:*),Bash(head:*),Bash(tail:*),Bash(wc:*),Bash(cp:*),Bash(mv:*),Bash(touch:*),Bash(grep:*)${EXTRA_TOOLS:+,$EXTRA_TOOLS}" \
  --disallowedTools "Bash(flutter build:*),Bash(flutter run:*),Bash(flutter pub publish:*)" \
  --output-format json > "$OUT/run-$LABEL.json" 2> "$OUT/run-$LABEL.err"
CODE=$?
END=$(date +%s)
python3 -I - "$OUT/run-$LABEL.json" "$OUT/run-$LABEL.md" <<'PY'
import json,sys
try:
    d=json.load(open(sys.argv[1]))
    open(sys.argv[2],'w').write(f"session_id: {d.get('session_id')}\ncost_usd: {d.get('total_cost_usd')}\nturns: {d.get('num_turns')}\nduration_ms: {d.get('duration_ms')}\n\n---\n\n{d.get('result','')}\n")
    print('ok', d.get('session_id'))
except Exception as e:
    print('parse failed', e)
PY
MIN=$(( (END-START)/60 ))
command -v tg >/dev/null 2>&1 && tg "[rigattiere] run $LABEL finito in ${MIN} min, exit $CODE. Output: experiments/run-$LABEL.md"
