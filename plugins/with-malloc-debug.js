// Android requires a debuggable APK to run wrap.sh.
// https://developer.android.com/ndk/guides/wrap-script
const fs = require('fs');
const path = require('path');
const { withAppBuildGradle, withGradleProperties, withDangerousMod } = require('expo/config-plugins');

const WRAP_SH = '#!/system/bin/sh\nLIBC_DEBUG_MALLOC_OPTIONS="fill_on_free free_track" exec "$@"\n';

module.exports = function withMallocDebug(config) {
  config = withAppBuildGradle(config, (c) => {
    if (!c.modResults.contents.includes('debuggable true')) {
      c.modResults.contents = c.modResults.contents.replace(
        /(release \{\s*\n(\s*)\/\/ Caution![^\n]*\n[^\n]*\n\s*signingConfig signingConfigs\.debug\n)/,
        '$1$2debuggable true\n'
      );
    }
    return c;
  });
  config = withGradleProperties(config, (c) => {
    const prop = c.modResults.find((p) => p.type === 'property' && p.key === 'expo.useLegacyPackaging');
    if (prop) prop.value = 'true';
    else c.modResults.push({ type: 'property', key: 'expo.useLegacyPackaging', value: 'true' });
    return c;
  });
  return withDangerousMod(config, [
    'android',
    (c) => {
      for (const abi of ['arm64-v8a', 'armeabi-v7a', 'x86', 'x86_64']) {
        const dir = path.join(c.modRequest.platformProjectRoot, 'app/src/main/resources/lib', abi);
        fs.mkdirSync(dir, { recursive: true });
        fs.writeFileSync(path.join(dir, 'wrap.sh'), WRAP_SH, { mode: 0o755 });
      }
      return c;
    },
  ]);
};
