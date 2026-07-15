using System.Windows;
using System.Windows.Forms;
using Microsoft.Extensions.Configuration;
using ScreenLockAgent.Services;

namespace ScreenLockAgent;

public partial class MainWindow : Window
{
    private readonly SocketService _socketService;
    private readonly NotifyIcon _trayIcon;
    private bool _isLocked;

    public MainWindow()
    {
        InitializeComponent();

        var config = new ConfigurationBuilder()
            .SetBasePath(AppContext.BaseDirectory)
            .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
            .Build();

        var backendUrl = config["BackendUrl"] ?? "http://localhost:3001";
        var clientIdOverride = config["ClientId"];

        _socketService = new SocketService(backendUrl, clientIdOverride);
        _socketService.OnLockRequested += HandleLock;
        _socketService.OnUnlockRequested += HandleUnlock;
        _socketService.OnConnectionChanged += UpdateTrayStatus;

        _trayIcon = new NotifyIcon
        {
            Icon = System.Drawing.SystemIcons.Shield,
            Visible = true,
            Text = "Screen Lock Agent — Connecting..."
        };

        Loaded += async (_, _) => await _socketService.ConnectAsync();
        Closing += (_, _) => _trayIcon.Dispose();
    }

    private void HandleLock()
    {
        Dispatcher.Invoke(() =>
        {
            if (_isLocked) return;
            LockWindow.ShowAll();
            _isLocked = true;
            UpdateTrayStatus(_socketService.IsConnected);
        });
    }

    private void HandleUnlock()
    {
        Dispatcher.Invoke(() =>
        {
            LockWindow.CloseAll();
            _isLocked = false;
            UpdateTrayStatus(_socketService.IsConnected);
        });
    }

    private void UpdateTrayStatus(bool connected)
    {
        Dispatcher.Invoke(() =>
        {
            var status = _isLocked ? "Locked" : connected ? "Connected" : "Disconnected";
            _trayIcon.Text = $"Screen Lock Agent — {status}";
        });
    }
}
