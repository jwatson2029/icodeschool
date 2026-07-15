using SocketIOClient;
using SocketIOClient.Transport;

namespace ScreenLockAgent.Services;

public class SocketService
{
    private readonly string _backendUrl;
    private readonly string _clientId;
    private readonly string _machineName;
    private SocketIO? _client;
    private CancellationTokenSource? _reconnectCts;
    private int _reconnectDelayMs = 2000;
    private const int MaxReconnectDelayMs = 10000;

    public bool IsConnected { get; private set; }

    public event Action? OnLockRequested;
    public event Action? OnUnlockRequested;
    public event Action<bool>? OnConnectionChanged;

    public SocketService(string backendUrl, string? clientIdOverride)
    {
        _backendUrl = backendUrl;
        _machineName = Environment.MachineName;
        _clientId = ResolveClientId(clientIdOverride);
    }

    public async Task ConnectAsync()
    {
        _reconnectCts?.Cancel();
        _reconnectCts = new CancellationTokenSource();
        var token = _reconnectCts.Token;

        while (!token.IsCancellationRequested)
        {
            try
            {
                await ConnectOnceAsync(token);
                _reconnectDelayMs = 2000;
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Connection failed: {ex.Message}");
                SetConnected(false);
            }

            if (token.IsCancellationRequested) break;

            await Task.Delay(_reconnectDelayMs, token);
            _reconnectDelayMs = Math.Min(_reconnectDelayMs * 2, MaxReconnectDelayMs);
        }
    }

    private async Task ConnectOnceAsync(CancellationToken token)
    {
        _client?.Dispose();

        _client = new SocketIO(_backendUrl, new SocketIOOptions
        {
            Transport = TransportProtocol.WebSocket,
            Reconnection = false,
        });

        _client.OnConnected += async (_, _) =>
        {
            SetConnected(true);
            await _client.EmitAsync("register-client", new
            {
                clientId = _clientId,
                machineName = _machineName,
            });
        };

        _client.OnDisconnected += (_, _) => SetConnected(false);

        _client.On("lock", _ => OnLockRequested?.Invoke());
        _client.On("unlock", _ => OnUnlockRequested?.Invoke());

        await _client.ConnectAsync();

        while (_client.Connected && !token.IsCancellationRequested)
        {
            await Task.Delay(1000, token);
        }
    }

    private void SetConnected(bool connected)
    {
        IsConnected = connected;
        OnConnectionChanged?.Invoke(connected);
    }

    private static string ResolveClientId(string? overrideId)
    {
        if (!string.IsNullOrWhiteSpace(overrideId))
            return overrideId.Trim();

        var machineName = Environment.MachineName;
        if (!string.IsNullOrWhiteSpace(machineName))
            return machineName;

        var dataDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
            "ScreenLockAgent");

        Directory.CreateDirectory(dataDir);
        var idFile = Path.Combine(dataDir, "client-id.txt");

        if (File.Exists(idFile))
            return File.ReadAllText(idFile).Trim();

        var id = Guid.NewGuid().ToString();
        File.WriteAllText(idFile, id);
        return id;
    }
}
