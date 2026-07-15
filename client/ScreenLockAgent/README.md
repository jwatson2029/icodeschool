# Screen Lock Agent (Windows)

C# WPF .NET 8 desktop agent that connects to the backend and displays a full-screen black overlay when locked.

## Requirements

- Windows 10/11
- .NET 8 SDK (for building)
- Administrator privileges (required at runtime)

## Configuration

Edit `appsettings.json` before deploying:

```json
{
  "BackendUrl": "https://your-app.onrender.com",
  "ClientId": ""
}
```

- **BackendUrl** — Render backend URL (use `http://localhost:3001` for local dev).
- **ClientId** — Optional override. Defaults to the Windows machine name; falls back to a persisted GUID in `%ProgramData%\ScreenLockAgent\client-id.txt`.

## Local Development

```powershell
cd client/ScreenLockAgent
dotnet run
```

Run the terminal as Administrator. The app runs in the system tray with no visible window when unlocked.

## Build Self-Contained EXE

```powershell
cd client/ScreenLockAgent
dotnet publish -c Release -r win-x64 --self-contained true `
  -p:PublishSingleFile=true `
  -p:IncludeNativeLibrariesForSelfExtract=true `
  -o ./publish
```

Output: `publish/ScreenLockAgent.exe` (~60–80 MB, no .NET runtime required on target machines).

Also copy `appsettings.json` from the publish folder or edit it before distribution.

## Install on Student Machines

1. Copy the `publish/` folder to e.g. `C:\Program Files\ScreenLockAgent\`.
2. Edit `appsettings.json` with your production `BackendUrl`.
3. Create a Scheduled Task:
   - **General:** Run whether user is logged on or not; Run with highest privileges
   - **Trigger:** At log on (any user)
   - **Action:** Start `C:\Program Files\ScreenLockAgent\ScreenLockAgent.exe`
4. Test: run the EXE manually as admin, confirm the device appears in the admin dashboard, then test Lock/Unlock.

## Behavior

- Connects to the backend via WebSocket on startup.
- Auto-reconnects with exponential backoff (2s → 4s → 8s → 10s cap) on network drops.
- **Lock:** Creates one full-screen black window per monitor; blocks Alt+F4.
- **Unlock:** Closes all lock windows and restores desktop access.
