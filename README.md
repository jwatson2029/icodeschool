# Classroom Screen Lock System

A lightweight classroom screen-locking utility with three components:

- **Backend** (Render) — Node.js/Express + Socket.io coordination server
- **Frontend** (Vercel) — Next.js admin dashboard to lock/unlock student devices
- **Windows Client** — C# WPF agent that displays a full-screen black overlay on command

## Prerequisites

- Node.js 20+
- .NET 8 SDK (for building the Windows agent)
- Windows 10/11 (for running the client agent)

## Local Development

### 1. Backend

```bash
cd backend
cp .env.example .env
npm install
npm run dev
```

Server runs at `http://localhost:3001`. Health check: `GET /health`.

### 2. Frontend

```bash
cd frontend
cp .env.local.example .env.local
# Set NEXT_PUBLIC_BACKEND_URL=http://localhost:3001
npm install
npm run dev
```

Dashboard runs at `http://localhost:3000`.

### 3. Windows Client Agent

```bash
cd client/ScreenLockAgent
# Edit appsettings.json — set BackendUrl to http://localhost:3001
dotnet run
```

Or build a self-contained executable (see [Windows Agent Install](#windows-agent-install)).

## Deployment

### Render (Backend)

1. Create a new **Web Service** on [Render](https://render.com).
2. Connect this repository; set **Root Directory** to `backend`.
3. **Build Command:** `npm install`
4. **Start Command:** `node src/index.js`
5. Add environment variable:
   - `FRONTEND_URL` = your Vercel URL (e.g. `https://icodeschool.vercel.app`)
6. Deploy. Note the service URL (e.g. `https://icodeschool-api.onrender.com`).

Alternatively, use the included `render.yaml` Blueprint.

### Vercel (Frontend)

1. Import the repository on [Vercel](https://vercel.com).
2. Set **Root Directory** to `frontend`.
3. Add environment variable:
   - `NEXT_PUBLIC_BACKEND_URL` = your Render backend URL
4. Deploy.

### Windows Agent Install

1. Build the executable:

```powershell
cd client/ScreenLockAgent
dotnet publish -c Release -r win-x64 --self-contained true `
  -p:PublishSingleFile=true `
  -p:IncludeNativeLibrariesForSelfExtract=true `
  -o ./publish
```

2. Copy the `publish/` folder to each student machine (e.g. `C:\Program Files\ScreenLockAgent\`).
3. Edit `appsettings.json` and set `BackendUrl` to your Render backend URL.
4. Create a Scheduled Task to run at logon:
   - **Program:** `C:\Program Files\ScreenLockAgent\ScreenLockAgent.exe`
   - **Trigger:** At log on (any user)
   - **Settings:** Run with highest privileges

The agent requires administrator rights (configured in `app.manifest`).

## Architecture

```
Admin Dashboard (Vercel)  ←→  Backend (Render)  ←→  Windows Agents (student PCs)
     Socket.io client            Socket.io server         Socket.io client
```

All real-time communication flows through the Render backend. The Vercel frontend connects outbound via WebSocket; it does not host persistent connections.

## Socket Events

| Event | Direction | Description |
|-------|-----------|-------------|
| `register-client` | Agent → Server | Register with clientId and machineName |
| `register-admin` | Dashboard → Server | Join admin room, receive client list |
| `clients-updated` | Server → Dashboard | Updated list of online devices |
| `lock-device` | Dashboard → Server | Request lock for a device |
| `unlock-device` | Dashboard → Server | Request unlock for a device |
| `lock` | Server → Agent | Show full-screen overlay |
| `unlock` | Server → Agent | Hide overlay |

## Security Notes

This MVP has no authentication. For production classroom use, consider:

- Admin token validation on `register-admin`
- Shared secret for `register-client`
- HTTPS/WSS only (Render provides TLS by default)
