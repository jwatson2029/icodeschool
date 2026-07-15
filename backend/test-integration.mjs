import { createRequire } from 'module';

const require = createRequire(import.meta.url);
const { io } = require('../frontend/node_modules/socket.io-client/dist/socket.io.js');

const BACKEND = 'http://localhost:3001';
const TIMEOUT = 8000;

function wait(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function withTimeout(promise, label) {
  return Promise.race([
    promise,
    new Promise((_, reject) =>
      setTimeout(() => reject(new Error(`Timeout: ${label}`)), TIMEOUT)
    ),
  ]);
}

async function runTests() {
  const results = [];

  // Health check
  const health = await fetch(`${BACKEND}/health`).then((r) => r.json());
  results.push(['Health check', health.status === 'ok']);

  // Simulate student client
  const client = io(BACKEND, { transports: ['websocket'] });
  await withTimeout(
    new Promise((resolve, reject) => {
      client.on('connect', resolve);
      client.on('connect_error', reject);
    }),
    'client connect'
  );

  let lockReceived = false;
  let unlockReceived = false;

  client.on('lock', () => {
    lockReceived = true;
  });
  client.on('unlock', () => {
    unlockReceived = true;
  });

  client.emit('register-client', {
    clientId: 'test-machine-001',
    machineName: 'TestLab-PC-01',
  });
  await wait(300);

  // Simulate admin dashboard
  const admin = io(BACKEND, { transports: ['websocket'] });
  await withTimeout(
    new Promise((resolve, reject) => {
      admin.on('connect', resolve);
      admin.on('connect_error', reject);
    }),
    'admin connect'
  );

  let clientList = [];
  admin.on('clients-updated', (list) => {
    clientList = list;
  });

  admin.emit('register-admin');
  await wait(500);

  const deviceFound = clientList.some(
    (d) => d.id === 'test-machine-001' && d.machineName === 'TestLab-PC-01'
  );
  results.push(['Client appears in admin list', deviceFound]);

  // Lock
  admin.emit('lock-device', { clientId: 'test-machine-001' });
  await wait(500);
  results.push(['Lock command received by client', lockReceived]);

  const lockedInList = clientList.find((d) => d.id === 'test-machine-001')?.locked === true;
  results.push(['Client shows locked in admin list', lockedInList]);

  // Unlock
  admin.emit('unlock-device', { clientId: 'test-machine-001' });
  await wait(500);
  results.push(['Unlock command received by client', unlockReceived]);

  const unlockedInList = clientList.find((d) => d.id === 'test-machine-001')?.locked === false;
  results.push(['Client shows unlocked in admin list', unlockedInList]);

  // Disconnect client and verify removal
  client.disconnect();
  await wait(500);
  const removedAfterDisconnect = !clientList.some((d) => d.id === 'test-machine-001');
  results.push(['Client removed after disconnect', removedAfterDisconnect]);

  admin.disconnect();

  console.log('\n=== Integration Test Results ===\n');
  let allPassed = true;
  for (const [name, passed] of results) {
    console.log(`${passed ? 'PASS' : 'FAIL'}: ${name}`);
    if (!passed) allPassed = false;
  }
  console.log(`\n${allPassed ? 'All tests passed!' : 'Some tests failed.'}\n`);
  process.exit(allPassed ? 0 : 1);
}

runTests().catch((err) => {
  console.error('Test error:', err.message);
  process.exit(1);
});
