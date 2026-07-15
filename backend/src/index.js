require('dotenv').config();

const express = require('express');
const http = require('http');
const cors = require('cors');
const { Server } = require('socket.io');
const { setupSocketHandlers } = require('./socketHandlers');

const app = express();
const port = process.env.PORT || 3001;
const frontendUrl = process.env.FRONTEND_URL || 'http://localhost:3000';

app.use(cors({ origin: frontendUrl }));

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

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
});
