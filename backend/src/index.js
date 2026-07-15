require('dotenv').config();

const express = require('express');
const http = require('http');
const cors = require('cors');
const { Server } = require('socket.io');
const { setupSocketHandlers, getStatus } = require('./socketHandlers');

const app = express();
const port = process.env.PORT || 3001;
const frontendUrl = 'https://icodeschool-eight.vercel.app';

app.use(cors({ origin: frontendUrl }));

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

/**
 * Status page — HTML for browsers, JSON when ?format=json or Accept: application/json
 */
app.get('/status', (req, res) => {
  const data = getStatus(io);
  const wantsJson =
    req.query.format === 'json' ||
    (req.headers.accept || '').includes('application/json');

  if (wantsJson) {
    return res.json(data);
  }

  const rows = data.clients
    .map(
      (c) => `
      <tr>
        <td>${escapeHtml(c.machineName)}</td>
        <td><code>${escapeHtml(c.id)}</code></td>
        <td><span class="badge ${c.locked ? 'locked' : 'unlocked'}">${c.locked ? 'Locked' : 'Unlocked'}</span></td>
        <td>${escapeHtml(c.connectedAt)}</td>
      </tr>`
    )
    .join('');

  res.type('html').send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta http-equiv="refresh" content="15" />
  <title>iCodeSchool API Status</title>
  <style>
    :root { color-scheme: light; }
    body { font-family: ui-sans-serif, system-ui, sans-serif; margin: 0; background: #f8fafc; color: #0f172a; }
    main { max-width: 880px; margin: 0 auto; padding: 2rem 1.25rem; }
    h1 { margin: 0 0 0.25rem; font-size: 1.75rem; }
    .sub { color: #64748b; margin-bottom: 1.5rem; }
    .ok { display: inline-flex; align-items: center; gap: 0.5rem; font-weight: 600; color: #15803d; }
    .dot { width: 10px; height: 10px; border-radius: 999px; background: #22c55e; }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 0.75rem; margin: 1.25rem 0 1.75rem; }
    .card { background: #fff; border: 1px solid #e2e8f0; border-radius: 10px; padding: 1rem; }
    .card .label { font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.04em; color: #64748b; }
    .card .value { font-size: 1.5rem; font-weight: 700; margin-top: 0.25rem; }
    table { width: 100%; border-collapse: collapse; background: #fff; border: 1px solid #e2e8f0; border-radius: 10px; overflow: hidden; }
    th, td { text-align: left; padding: 0.75rem 1rem; border-bottom: 1px solid #e2e8f0; font-size: 0.925rem; }
    th { background: #f1f5f9; font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.04em; color: #64748b; }
    tr:last-child td { border-bottom: none; }
    .badge { display: inline-block; padding: 0.15rem 0.5rem; border-radius: 999px; font-size: 0.75rem; font-weight: 600; }
    .badge.locked { background: #fee2e2; color: #991b1b; }
    .badge.unlocked { background: #dcfce7; color: #166534; }
    .empty { color: #64748b; padding: 1.25rem; background: #fff; border: 1px dashed #cbd5e1; border-radius: 10px; }
    a { color: #2563eb; }
    code { font-size: 0.85em; }
    footer { margin-top: 1.5rem; color: #94a3b8; font-size: 0.85rem; }
  </style>
</head>
<body>
  <main>
    <p class="ok"><span class="dot"></span> Online</p>
    <h1>iCodeSchool API Status</h1>
    <p class="sub">Backend coordination server · auto-refreshes every 15s · <a href="/status?format=json">JSON</a></p>

    <div class="grid">
      <div class="card"><div class="label">Sockets</div><div class="value">${data.connections.sockets}</div></div>
      <div class="card"><div class="label">Clients</div><div class="value">${data.connections.clients}</div></div>
      <div class="card"><div class="label">Locked</div><div class="value">${data.connections.locked}</div></div>
      <div class="card"><div class="label">Admins</div><div class="value">${data.connections.admins}</div></div>
      <div class="card"><div class="label">Uptime</div><div class="value">${formatUptime(data.uptimeSeconds)}</div></div>
    </div>

    <h2 style="font-size:1.1rem;margin:0 0 0.75rem;">Online devices</h2>
    ${
      data.clients.length === 0
        ? '<p class="empty">No student devices connected.</p>'
        : `<table>
            <thead><tr><th>Machine</th><th>Client ID</th><th>State</th><th>Connected</th></tr></thead>
            <tbody>${rows}</tbody>
          </table>`
    }

    <footer>
      Started ${escapeHtml(data.startedAt)} · Dashboard: <a href="${frontendUrl}">${frontendUrl}</a>
    </footer>
  </main>
</body>
</html>`);
});

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function formatUptime(seconds) {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  if (h > 0) return `${h}h ${m}m`;
  if (m > 0) return `${m}m ${s}s`;
  return `${s}s`;
}

const server = http.createServer(app);

const io = new Server(server, {
  cors: {
    origin: frontendUrl,
    methods: ['GET', 'POST'],
  },
  transports: ['websocket', 'polling'],
});

setupSocketHandlers(io);

server.listen(port, () => {
  console.log(`Server listening on port ${port}`);
  console.log(`CORS origin: ${frontendUrl}`);
  console.log(`Status page: http://localhost:${port}/status`);
});
