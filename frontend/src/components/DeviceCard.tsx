import type { Device } from '@/types/device';

interface DeviceCardProps {
  device: Device;
  onLock: (clientId: string) => void;
  onUnlock: (clientId: string) => void;
}

function formatConnectedAt(iso: string) {
  try {
    return new Date(iso).toLocaleString();
  } catch {
    return iso;
  }
}

export function DeviceCard({ device, onLock, onUnlock }: DeviceCardProps) {
  return (
    <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2">
          <h3 className="truncate text-lg font-semibold text-gray-900">
            {device.machineName}
          </h3>
          <span
            className={`inline-flex shrink-0 rounded-full px-2 py-0.5 text-xs font-medium ${
              device.locked
                ? 'bg-red-100 text-red-800'
                : 'bg-green-100 text-green-800'
            }`}
          >
            {device.locked ? 'Locked' : 'Unlocked'}
          </span>
        </div>
        <p className="mt-1 truncate text-sm text-gray-500">ID: {device.id}</p>
        <p className="text-xs text-gray-400">
          Connected: {formatConnectedAt(device.connectedAt)}
        </p>
      </div>

      <div className="flex shrink-0 gap-2">
        <button
          type="button"
          onClick={() => onLock(device.id)}
          disabled={device.locked}
          className="rounded-md bg-red-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-red-700 disabled:cursor-not-allowed disabled:opacity-40"
        >
          Lock
        </button>
        <button
          type="button"
          onClick={() => onUnlock(device.id)}
          disabled={!device.locked}
          className="rounded-md bg-green-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-green-700 disabled:cursor-not-allowed disabled:opacity-40"
        >
          Unlock
        </button>
      </div>
    </div>
  );
}
