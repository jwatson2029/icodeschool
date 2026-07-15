/** @typedef {{ socketId: string, machineName: string, connectedAt: string, locked: boolean }} ClientRecord */

/** @type {Map<string, ClientRecord>} */
const clients = new Map();
const startedAt = new Date();

function getClientList() {
  return [...clients.entries()].map(([id, client]) => ({
    id,
    machineName: client.machineName,
    connectedAt: client.connectedAt,
    locked: client.locked ?? false,
  }));
}

/**
 * @param {import('socket.io').Server} io
 */
function getStatus(io) {
  const list = getClientList();
  return {
    status: 'ok',
    service: 'icodeschool-api',
    timestamp: new Date().toISOString(),
    startedAt: startedAt.toISOString(),
    uptimeSeconds: Math.floor((Date.now() - startedAt.getTime()) / 1000),
    frontendUrl: 'https://icodeschool-eight.vercel.app',
    connections: {
      sockets: io.engine.clientsCount,
      clients: list.length,
      locked: list.filter((c) => c.locked).length,
      admins: [...(io.sockets.adapter.rooms.get('admins') ?? [])].length,
    },
    clients: list,
  };
}

/**
 * @param {import('socket.io').Server} io
 */
function setupSocketHandlers(io) {
  function broadcastClients() {
    io.to('admins').emit('clients-updated', getClientList());
  }

  io.on('connection', (socket) => {
    console.log(`Socket connected: ${socket.id}`);

    socket.on('register-client', ({ clientId, machineName }) => {
      if (!clientId || typeof clientId !== 'string') {
        socket.emit('error', { message: 'clientId is required' });
        return;
      }

      const existing = clients.get(clientId);
      if (existing) {
        io.sockets.sockets.get(existing.socketId)?.disconnect(true);
      }

      clients.set(clientId, {
        socketId: socket.id,
        machineName: machineName || clientId,
        connectedAt: new Date().toISOString(),
        locked: existing?.locked ?? false,
      });

      socket.join(`client:${clientId}`);
      socket.data.role = 'client';
      socket.data.clientId = clientId;

      console.log(`Client registered: ${clientId} (${machineName})`);
      broadcastClients();
    });

    socket.on('register-admin', () => {
      socket.join('admins');
      socket.data.role = 'admin';
      console.log(`Admin registered: ${socket.id}`);
      socket.emit('clients-updated', getClientList());
    });

    socket.on('lock-device', ({ clientId }) => {
      const client = clients.get(clientId);
      if (!client) {
        socket.emit('error', { message: `Client not found: ${clientId}` });
        return;
      }

      client.locked = true;
      io.to(`client:${clientId}`).emit('lock');
      console.log(`Lock sent to: ${clientId}`);
      broadcastClients();
    });

    socket.on('unlock-device', ({ clientId }) => {
      const client = clients.get(clientId);
      if (!client) {
        socket.emit('error', { message: `Client not found: ${clientId}` });
        return;
      }

      client.locked = false;
      io.to(`client:${clientId}`).emit('unlock');
      console.log(`Unlock sent to: ${clientId}`);
      broadcastClients();
    });

    socket.on('disconnect', () => {
      console.log(`Socket disconnected: ${socket.id}`);

      if (socket.data.role === 'client' && socket.data.clientId) {
        const client = clients.get(socket.data.clientId);
        if (client && client.socketId === socket.id) {
          clients.delete(socket.data.clientId);
          broadcastClients();
        }
      }
    });
  });
}

module.exports = { setupSocketHandlers, getStatus, getClientList };
