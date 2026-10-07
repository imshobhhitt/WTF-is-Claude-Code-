# Claude Code notification hook (Windows)
# Shows a tray balloon / Action Center toast when Claude Code needs attention.
# Claude Code pipes a JSON payload on stdin; we surface its "message" field.

$raw = [Console]::In.ReadToEnd()

$message = 'Claude Code needs your attention'
if ($raw) {
    try {
        $payload = $raw | ConvertFrom-Json
        if ($payload.message) { $message = $payload.message }
    } catch {
        # stdin wasn't valid JSON (e.g. run manually) - keep the default message
    }
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = [System.Drawing.SystemIcons]::Information
$notify.Visible = $true
$notify.ShowBalloonTip(
    5000,
    'Claude Code',
    $message,
    [System.Windows.Forms.ToolTipIcon]::Info
)

# Keep the process alive briefly so Windows can render the balloon,
# otherwise it can be dropped when powershell exits immediately.
Start-Sleep -Seconds 3
$notify.Dispose()
