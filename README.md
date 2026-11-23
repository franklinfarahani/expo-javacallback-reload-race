# Android crash in JavaCallback during an app reload

This app reloads while a local Expo module resolves promises on background threads. With stock `expo-modules-core` 58.1.0, all 10 test runs crashed in `JavaCallback::invokeWithResolver`.

The release build is debuggable so Android can run the bundled `wrap.sh`. It enables malloc debug, which fills freed memory with `0xef`. That pattern is visible in the crash trace below.

## Run

Use an Android emulator (arm64 or x86_64), Node 24 and pnpm. One command builds the release app for the emulator's ABI, installs it and runs the reload loop:

```sh
./scripts/repro.sh          # stock expo-modules-core 58.1.0
./scripts/repro.sh --with-fix   # with fix/expo-modules-core@58.1.0.patch applied
```

It ends with one line:

```
REPRODUCED: 3 of 5 runs crashed in expo::JavaCallback::invokeWithResolver
NOT REPRODUCED: all 5 runs completed 200 reloads without a crash
```

Pass a run count as the last argument (default 5). Set `ANDROID_SERIAL` if more than one device is connected. `--with-fix` writes `pnpm-workspace.yaml` to apply the patch, and a run without it removes that file.

To run the steps by hand:

```sh
pnpm install
pnpm exec expo prebuild -p android
cd android && ./gradlew assembleRelease -PreactNativeArchitectures=$(adb shell getprop ro.product.cpu.abi) && cd ..
adb install -r android/app/build/outputs/apk/release/app-release.apk
./scripts/loop.sh 10
```

Each run clears the app’s data. `loop.sh` reports the reload count of each run and prints the directory containing the logcat files.

## Results

Android 14 emulator (API 34, arm64), Expo 58.0.26 and React Native 0.88.1, release build with the New Architecture.

| Build | Runs | Crashes | Last reload before crash or completion |
|---|---|---|---|
| Stock `expo-modules-core` 58.1.0 | 10 | 10 | 5–46 (median 11) |
| With `fix/expo-modules-core@58.1.0.patch` | 10 | 0 | 200 in every run |

The stock runs logged 143 reloads in total. The patched runs completed 2,000. Patched runs logged about 1,300 `Invalidated JavaCallback was invoked` warnings per run.

The top frames were the same in all 10 crashes.

```
Fatal signal 11 (SIGSEGV), code 1 (SEGV_MAPERR), fault addr 0xefefefefefefeff7 in tid … (pool-4-thread-4)
  #00 libc++_shared.so  std::__ndk1::__shared_weak_count::lock()+20
  #01 libexpo-modules-core.so  expo::JavaCallback::invokeWithResolver(...)+52
  #02 libexpo-modules-core.so  expo::JavaCallback::invokeString(...)+148
  ...  expo.modules.kotlin.jni.JavaCallback.invoke
  ...  expo.modules.kotlin.jni.PromiseImpl.resolve
  ...  expo.modules.raceprobe.RaceProbeModule$definition$1$1$1.run
```

### x86_64

`.github/workflows/repro.yml` runs `./scripts/repro.sh 3` and `./scripts/repro.sh --with-fix 2` on an API 35 x86_64 emulator in GitHub Actions and uploads the logcat files. In [run 45259072730](https://github.com/franklinfarahani/expo-javacallback-reload-race/actions/runs/45259072730), all 3 stock runs crashed in `invokeWithResolver` (at reloads 2, 3 and 10) and both patched runs completed 200 reloads.

On x86_64 the fill pattern is not a valid address, so the kernel reports `SIGSEGV, code 128 (SI_KERNEL), fault addr 0x0`. The register dump shows the freed pointer: `rdi efefefefefefefef`, the `this` argument of `__shared_weak_count::lock()`.

## Applying the fix

`./scripts/repro.sh --with-fix` does this for you. By hand, add the patch to `pnpm-workspace.yaml`.

```yaml
patchedDependencies:
  expo-modules-core@58.1.0: fix/expo-modules-core@58.1.0.patch
```

Run `pnpm install`, then rebuild and reinstall the APK. The patch holds the same lock as `resetNative()` while checking and invoking the callback.
