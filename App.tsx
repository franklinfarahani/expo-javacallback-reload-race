import * as Updates from 'expo-updates';
import { useEffect, useState } from 'react';
import { Button, StyleSheet, Text, View } from 'react-native';

import RaceProbe from './modules/race-probe';

const RELOADS = 200;
const PENDING_PER_RELOAD = 40;

export default function App() {
  const [reload, setReload] = useState(0);

  useEffect(() => {
    const n = RaceProbe.nextReload();
    setReload(n);
    if (n > RELOADS) return;

    for (let i = 0; i < PENDING_PER_RELOAD; i++) {
      RaceProbe.pending().catch(() => {});
    }
    const timer = setTimeout(() => {
      Updates.reloadAsync().catch((e) => console.warn('reloadAsync failed', e));
    }, 20 + Math.random() * 130);
    return () => clearTimeout(timer);
  }, []);

  return (
    <View style={styles.container}>
      <Text testID="reload-count">
        {reload > RELOADS ? `Done: ${RELOADS} reloads without a crash` : `Reload ${reload} of ${RELOADS}`}
      </Text>
      <Button
        title="Start again"
        onPress={() => {
          RaceProbe.resetReloads();
          Updates.reloadAsync();
        }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: 16 },
});
