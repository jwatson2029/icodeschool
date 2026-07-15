'use client';

import { DeviceList } from '@/components/DeviceList';
import { useSocket } from '@/hooks/useSocket';

export default function DashboardPage() {
  const { connected, devices, lockDevice, unlockDevice } = useSocket();

  return (
    <main className="min-h-screen">
      <header className="border-b border-gray-200 bg-white">
        <div className="mx-auto flex max-w-4xl items-center justify-between px-4 py-6 sm:px-6">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">
              Screen Lock Dashboard
            </h1>
            <p className="mt-1 text-sm text-gray-500">
              Manage connected student devices
            </p>
          </div>
          <div className="flex items-center gap-2">
            <span
              className={`h-2.5 w-2.5 rounded-full ${
                connected ? 'bg-green-500' : 'bg-red-500'
              }`}
            />
            <span className="text-sm font-medium text-gray-600">
              {connected ? 'Connected' : 'Disconnected'}
            </span>
          </div>
        </div>
      </header>

      <div className="mx-auto max-w-4xl px-4 py-8 sm:px-6">
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-lg font-semibold text-gray-800">
            Online Devices
            <span className="ml-2 text-base font-normal text-gray-400">
              ({devices.length})
            </span>
          </h2>
        </div>

        <DeviceList
          devices={devices}
          onLock={lockDevice}
          onUnlock={unlockDevice}
        />
      </div>
    </main>
  );
}
