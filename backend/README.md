# Backend Server

Node.js/Express + Socket.io coordination server for the Classroom Screen Lock system.

## Setup

```bash
cp .env.example .env
npm install
npm run dev
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | HTTP port | `3001` |
| `FRONTEND_URL` | Vercel dashboard URL (CORS) | `http://localhost:3000` |

## Endpoints

- `GET /health` — Health check for Render

## Socket Events

See the [root README](../README.md#socket-events) for the full event reference.

## Render Deployment

Use the included `render.yaml` or create a Web Service manually:

- **Root Directory:** `backend`
- **Build:** `npm install`
- **Start:** `node src/index.js`
- **Env:** `FRONTEND_URL=https://your-app.vercel.app`
