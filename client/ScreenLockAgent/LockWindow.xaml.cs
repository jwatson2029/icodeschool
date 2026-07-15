using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Input;
using System.Windows.Interop;
using WinForms = System.Windows.Forms;

namespace ScreenLockAgent;

public partial class LockWindow : Window
{
    private static readonly List<LockWindow> ActiveWindows = new();
    private bool _allowClose;

    public LockWindow(double left, double top, double width, double height)
    {
        InitializeComponent();
        Left = left;
        Top = top;
        Width = width;
        Height = height;
        WindowState = WindowState.Normal;
    }

    public static void ShowAll()
    {
        CloseAll();

        foreach (var screen in WinForms.Screen.AllScreens)
        {
            var bounds = screen.Bounds;
            var window = new LockWindow(bounds.Left, bounds.Top, bounds.Width, bounds.Height);
            ActiveWindows.Add(window);
            window.Show();
        }

        if (ActiveWindows.Count > 0)
        {
            var primary = ActiveWindows[0];
            primary.Activate();
            primary.Focus();
            ForceForeground(primary);
        }
    }

    public static void CloseAll()
    {
        foreach (var window in ActiveWindows.ToList())
        {
            window._allowClose = true;
            window.Close();
        }
        ActiveWindows.Clear();
    }

    protected override void OnClosing(System.ComponentModel.CancelEventArgs e)
    {
        if (!_allowClose)
        {
            e.Cancel = true;
        }
        base.OnClosing(e);
    }

    private void Window_KeyDown(object sender, System.Windows.Input.KeyEventArgs e)
    {
        if (e.Key == Key.System && e.SystemKey == Key.F4)
        {
            e.Handled = true;
        }
    }

    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr hWnd);

    private static void ForceForeground(Window window)
    {
        var helper = new WindowInteropHelper(window);
        SetForegroundWindow(helper.Handle);
    }
}
