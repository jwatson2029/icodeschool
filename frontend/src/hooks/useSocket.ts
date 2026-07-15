'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { io, Socket } from 'socket.io-client';
import type { Device } from '@/types/device';

const BACKEND_URL = 'https://icodeschool.onrender.com';

export function useSocket() {
  const socketRef = useRef<Socket | null>(null);
  const [connected, setConnected] = useState(false);
  const [devices, setDevices] = useState<Device[]>([]);

  useEffect(() => {
    const socket = io(BACKEND_URL, {
      transports: ['websocket', 'polling'],
      reconnection: true,
      reconnectionAttempts: Infinity,
      reconnectionDelay: 2000,
    });

    socketRef.current = socket;

    socket.on('connect', () => {
      setConnected(true);
      socket.emit('register-admin');
    });

    socket.on('disconnect', () => {
      setConnected(false);
    });

    socket.on('clients-updated', (list: Device[]) => {
      setDevices(list);
    });

    return () => {
      socket.disconnect();
      socketRef.current = null;
    };
  }, []);

  const lockDevice = useCallback((clientId: string) => {
    socketRef.current?.emit('lock-device', { clientId });
  }, []);

  const unlockDevice = useCallback((clientId: string) => {
    socketRef.current?.emit('unlock-device', { clientId });
  }, []);

  return { connected, devices, lockDevice, unlockDevice };
}
