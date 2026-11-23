#!/bin/bash
# Usage: ./scripts/loop.sh [runs] (set ANDROID_SERIAL when more than one device is connected)
set -u
PKG=com.example.javacallbackreloadrace
RUNS=${1:-10}
OUT=$(mktemp -d)
for run in $(seq 1 "$RUNS"); do
  log=$OUT/run-$run.log
  adb shell am force-stop $PKG
  adb shell pm clear $PKG >/dev/null
  for _ in $(seq 1 20); do adb shell pidof $PKG >/dev/null || break; sleep 1; done
  sleep 2
  adb logcat -c
  adb logcat -v time RaceProbe:I DEBUG:F libc:F '*:S' > "$log" &
  logcat=$!
  adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
  for _ in $(seq 1 450); do grep -q -E 'Fatal signal|reload 201' "$log" && break; sleep 2; done
  grep -q 'Fatal signal' "$log" && sleep 8
  kill $logcat 2>/dev/null; wait $logcat 2>/dev/null
  reloads=$(grep -c 'I/RaceProbe' "$log")
  if grep -q 'Fatal signal' "$log"; then
    frame=$(grep -m1 -E '#01 pc' "$log" | sed -E 's/.*\.so \(//; s/\(.*//')
    echo "run $run: crashed at reload $reloads in $frame"
  elif grep -q 'reload 201' "$log"; then
    echo "run $run: 200 reloads, no crash"
  else
    echo "run $run: timed out after $reloads reloads"
  fi
done
echo "logs: $OUT"
