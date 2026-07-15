using System.Threading;
using System.Windows;

namespace ScreenLockAgent;

public partial class App : System.Windows.Application
{
    private Mutex? _singleInstanceMutex;

    protected override void OnStartup(StartupEventArgs e)
    {
        _singleInstanceMutex = new Mutex(true, @"Global\iCodeSchool.ScreenLockAgent", out var createdNew);

        if (!createdNew)
        {
            // Already running (e.g. unlock trigger while agent is alive) — exit quietly
            Shutdown();
            return;
        }

        base.OnStartup(e);
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _singleInstanceMutex?.ReleaseMutex();
        _singleInstanceMutex?.Dispose();
        base.OnExit(e);
    }
}
