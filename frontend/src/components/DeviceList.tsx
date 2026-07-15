import type { Device } from '@/types/device';
import { DeviceCard } from './DeviceCard';

interface DeviceListProps {
  devices: Device[];
  onLock: (clientId: string) => void;
  onUnlock: (clientId: string) => void;
}

export function DeviceList({ devices, onLock, onUnlock }: DeviceListProps) {
  if (devices.length === 0) {
    return (
      <div className="rounded-lg border border-dashed border-gray-300 bg-white p-12 text-center">
        <p className="text-lg font-medium text-gray-600">No devices online</p>
        <p className="mt-2 text-sm text-gray-400">
          Student agents will appear here when they connect to the backend.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      {devices.map((device) => (
        <DeviceCard
          key={device.id}
          device={device}
          onLock={onLock}
          onUnlock={onUnlock}
        />
      ))}
    </div>
  );
}
