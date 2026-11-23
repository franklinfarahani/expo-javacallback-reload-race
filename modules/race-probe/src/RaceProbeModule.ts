import { NativeModule, requireNativeModule } from 'expo';

declare class RaceProbeModule extends NativeModule<{}> {
  pending(): Promise<string>;
  nextReload(): number;
  resetReloads(): void;
}

export default requireNativeModule<RaceProbeModule>('RaceProbe');
