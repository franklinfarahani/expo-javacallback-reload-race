# Android crash in JavaCallback during an app reload

This app reloads while a local Expo module resolves promises on background threads. With stock `expo-modules-core` 58.1.0, all 10 test runs crashed in `JavaCallback::invokeWithResolver`.

The release build is debuggable so Android can run the bundled `wrap.sh`. It enables malloc debug, which fills freed memory with `0xef`. That pattern is visible in the crash trace below.

## Run

Use an arm64 Android emulator, Node 24 and pnpm.

```sh
pnpm install
pnpm exec expo prebuild -p android
cd android && ./gradlew assembleRelease -PreactNativeArchitectures=arm64-v8a && cd ..
adb install -r android/app/build/outputs/apk/release/app-release.apk
./scripts/loop.sh 10
```

Each run clears the app’s data. The script reports the reload count and prints the directory containing the logcat files. Set `ANDROID_SERIAL` if more than one device is connected.

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

## Applying the fix

Add the patch to `pnpm-workspace.yaml`.

```yaml
patchedDependencies:
  expo-modules-core@58.1.0: fix/expo-modules-core@58.1.0.patch
```

Run `pnpm install`, then rebuild and reinstall the APK. The patch holds the same lock as `resetNative()` while checking and invoking the callback.
