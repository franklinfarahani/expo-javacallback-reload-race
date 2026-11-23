#!/bin/bash
# Builds the release app for the connected device's ABI, installs it and runs the reload loop.
# Usage: ./scripts/repro.sh [--with-fix] [runs]   (set ANDROID_SERIAL when more than one device is connected)
set -euo pipefail
cd "$(dirname "$0")/.."

WITH_FIX=0
if [ "${1:-}" = "--with-fix" ]; then WITH_FIX=1; shift; fi
RUNS=${1:-5}

if [ "$WITH_FIX" = 1 ]; then
  printf 'patchedDependencies:\n  expo-modules-core@58.1.0: fix/expo-modules-core@58.1.0.patch\n' > pnpm-workspace.yaml
else
  rm -f pnpm-workspace.yaml
fi

ABI=$(adb shell getprop ro.product.cpu.abi | tr -d '\r')
echo "Device ABI: $ABI; fix applied: $([ "$WITH_FIX" = 1 ] && echo yes || echo no)"

pnpm install
CI=1 pnpm exec expo prebuild -p android
(cd android && ./gradlew assembleRelease -PreactNativeArchitectures="$ABI")
adb install -r android/app/build/outputs/apk/release/app-release.apk

results=$(./scripts/loop.sh "$RUNS" | tee /dev/stderr)
crashed=$(grep -c 'crashed at reload .* in expo::JavaCallback::invokeWithResolver' <<< "$results" || true)
clean=$(grep -c '200 reloads, no crash' <<< "$results" || true)

echo
if [ "$crashed" -gt 0 ]; then
  echo "REPRODUCED: $crashed of $RUNS runs crashed in expo::JavaCallback::invokeWithResolver"
elif [ "$clean" = "$RUNS" ]; then
  echo "NOT REPRODUCED: all $RUNS runs completed 200 reloads without a crash"
else
  echo "INCONCLUSIVE: $crashed crashes in invokeWithResolver, $clean clean runs of $RUNS; see the loop output above"
fi
