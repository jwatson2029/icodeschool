# Frontend Dashboard

Next.js admin dashboard for locking and unlocking student devices.

## Setup

```bash
cp .env.local.example .env.local
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

## Environment Variables

| Variable | Description |
|----------|-------------|
| `NEXT_PUBLIC_BACKEND_URL` | Render backend URL (e.g. `http://localhost:3001`) |

## Vercel Deployment

1. Import the repository on Vercel.
2. Set **Root Directory** to `frontend`.
3. Add `NEXT_PUBLIC_BACKEND_URL` pointing to your Render backend.
4. Deploy.
