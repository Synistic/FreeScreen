param(
    [switch]$Preview,
    [switch]$SmokeTest,
    [ValidateSet('ready','video','connected','stopped','error')][string]$PreviewState = 'ready',
    [ValidateSet('home','help')][string]$PreviewPage = 'home',
    [int]$PreviewWidth = 1040,
    [int]$PreviewHeight = 760,
    [string]$PreviewOutput
)
$ErrorActionPreference = 'Stop'
if ($SmokeTest -and !$Preview) { throw 'SmokeTest requires Preview mode.' }
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class FreeScreenWindow {
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern bool SetWindowText(IntPtr handle, string text);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr handle);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr handle, int command);
}
"@
$script:mutex = $null
if (!$Preview) {
    $script:mutex = New-Object Threading.Mutex($false, 'Local\FreeScreen-Launcher')
    if (!$script:mutex.WaitOne(0)) {
        Get-Process powershell -ErrorAction SilentlyContinue | Where-Object MainWindowTitle -eq 'FreeScreen' | ForEach-Object {
            [FreeScreenWindow]::ShowWindow($_.MainWindowHandle, 9) | Out-Null
            [FreeScreenWindow]::SetForegroundWindow($_.MainWindowHandle) | Out-Null
        }
        $script:mutex.Dispose(); exit
    }
}
$exe = Join-Path $PSScriptRoot 'runtime\uxplay-windows.exe'
$script:startupError = $null
$script:fwProcess = $null
$script:state = 'starting'
$script:startingAt = Get-Date
function Get-Receiver {
    @(Get-Process -Name uxplay-windows -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exe })
}
function Start-Receiver {
    $script:startupError = $null
    if (!(Test-Path $exe)) { throw 'The receiver is missing. Please run Setup.ps1 first.' }
    $hostExe = Join-Path $PSScriptRoot 'ReceiverHost.exe'
    if (!(Test-Path $hostExe)) { throw 'The launcher is missing. Please run Setup.ps1 first.' }
    if (!(Get-Receiver)) {
        $script:startingAt = Get-Date
        Start-Process $hostExe -WorkingDirectory $PSScriptRoot -WindowStyle Hidden
    }
}
[xml]$xaml = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'ui\MainWindow.xaml'))
$window = [Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $xaml))
$ui = @{}
foreach ($name in 'TitleBar','Minimize','Close','NavHome','NavHelp','HomePage','HelpPage','StatusDot','StatusBadge','StatusTitle','StatusDescription','Primary','Toggle','NetworkLabel','Firewall','FirewallStatus','Back','Logs') { $ui[$name] = $window.FindName($name) }
$icon = Join-Path $PSScriptRoot 'assets\freescreen.ico'
if (Test-Path $icon) { $window.Icon = New-Object Windows.Media.Imaging.BitmapImage([Uri]$icon) }
function Set-Page([bool]$help) {
    $ui.HomePage.Visibility = if ($help) { 'Collapsed' } else { 'Visible' }
    $ui.HelpPage.Visibility = if ($help) { 'Visible' } else { 'Collapsed' }
    $ui.NavHome.Background = if ($help) { 'Transparent' } else { '#23342D' }
    $ui.NavHome.Foreground = if ($help) { '#DCE4DF' } else { '#B8F3CC' }
    $ui.NavHelp.Background = if ($help) { '#23342D' } else { 'Transparent' }
    $ui.NavHelp.Foreground = if ($help) { '#B8F3CC' } else { '#DCE4DF' }
}
function Set-State([string]$state) {
    $script:state = $state
    $ui.StatusDot.Fill = '#B8F3CC'
    $ui.StatusBadge.Foreground = '#B8F3CC'
    $ui.Primary.IsEnabled = $true
    $ui.Toggle.IsEnabled = $true
    $ui.Toggle.Visibility = 'Visible'
    $ui.Toggle.Content = 'Stop receiver'
    switch ($state) {
        'ready' { $badge='READY TO RECEIVE'; $title='Ready for your iPhone.'; $description='Choose FreeScreen in Screen Mirroring. Your screen will open in its own window.'; $action='How to connect' }
        'video' { $badge='SCREEN CONNECTED'; $title='Your screen is here.'; $description='Screen mirroring is active. Bring the screen window to the front, or press Alt + Enter there for fullscreen.'; $action='Open screen window' }
        'connected' { $badge='DEVICE CONNECTED'; $title='Connected. Waiting for video.'; $description='AirPlay is connected, but no screen stream is active yet. Connection help will guide you through the next step.'; $action='Connection help' }
        'stopped' { $badge='RECEIVER PAUSED'; $title='Ready when you are.'; $description='Start the receiver to make FreeScreen available on your iPhone again.'; $action='Start receiver'; $ui.Toggle.Visibility='Collapsed'; $ui.StatusDot.Fill='#8D9D97' }
        'error' { $badge='RECEIVER NOT READY'; $title='Something went wrong.'; $description=if ($script:startupError) { $script:startupError } else { 'The receiver could not start. Check connection help or try starting it again.' }; $action='Try again'; $ui.StatusDot.Fill='#F2C38A'; $ui.StatusBadge.Foreground='#F2C38A'; $ui.Toggle.Content='Connection help' }
        default { $badge='JUST A MOMENT'; $title='Getting your screen ready.'; $description='FreeScreen is starting the receiver. This usually takes just a few seconds.'; $action='Starting …'; $ui.Primary.IsEnabled=$false }
    }
    $ui.StatusBadge.Text=$badge; $ui.StatusTitle.Text=$title; $ui.StatusDescription.Text=$description; $ui.Primary.Content=$action
}
function Update-State {
    $receiver = @(Get-Receiver)
    if ($receiver.Count) {
        foreach ($process in $receiver) {
            $process.Refresh()
            if ($process.MainWindowHandle -ne [IntPtr]::Zero -and $process.MainWindowTitle -match 'Direct3D') {
                [FreeScreenWindow]::SetWindowText($process.MainWindowHandle, 'FreeScreen - iPhone Screen') | Out-Null
            }
        }
        $network = [Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
        $connections = $network.GetActiveTcpConnections()
        if (($connections | Where-Object { $_.LocalEndPoint.Port -eq 7000 -and $_.State -eq 'Established' }) -and ($receiver | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero })) { Set-State 'video' }
        elseif ($connections | Where-Object { $_.LocalEndPoint.Port -eq 7001 -and $_.State -eq 'Established' }) { Set-State 'connected' }
        elseif ($network.GetActiveTcpListeners() | Where-Object Port -eq 7001) { Set-State 'ready' }
        elseif (((Get-Date)-$script:startingAt).TotalSeconds -gt 20) { Set-State 'error' }
        else { Set-State 'starting' }
    } elseif ($script:startupError) { Set-State 'error' }
    elseif ($script:state -eq 'starting' -and ((Get-Date)-$script:startingAt).TotalSeconds -lt 10) { Set-State 'starting' }
    else { Set-State 'stopped' }
    if ($script:fwProcess -and !$script:fwProcess.HasExited) {
        $ui.Firewall.IsEnabled=$false; $ui.FirewallStatus.Text='Please approve the Windows permission request.'; $ui.NetworkLabel.Text='Setting up network access …'
    } else {
        $ui.Firewall.IsEnabled=$true
        $statusFile = Join-Path $PSScriptRoot 'firewall-status.txt'
        if ((Test-Path $statusFile) -and (Get-Content $statusFile -Raw).Trim() -eq 'OK') {
            $ui.Firewall.Content='Refresh network access'; $ui.FirewallStatus.Text='Set up to receive connections on your local network.'; $ui.NetworkLabel.Text='Network access enabled'
        } else {
            $ui.Firewall.Content='Allow network access'; $ui.FirewallStatus.Text='Windows will ask for administrator permission.'; $ui.NetworkLabel.Text='Check network access'
        }
        if ($script:fwProcess -and $script:fwProcess.HasExited -and $script:fwProcess.ExitCode -ne 0) { $ui.FirewallStatus.Text='Network setup did not finish. You can try again.' }
    }
}
$ui.TitleBar.Add_MouseLeftButtonDown({ if ($_.ClickCount -eq 1) { $window.DragMove() } })
$ui.Minimize.Add_Click({ $window.WindowState='Minimized' })
$ui.Close.Add_Click({ $window.Close() })
$ui.NavHome.Add_Click({ Set-Page $false })
$ui.NavHelp.Add_Click({ Set-Page $true })
$ui.Back.Add_Click({ Set-Page $false })
$ui.Primary.Add_Click({
    if ($Preview) { return }
    try {
        if ($script:state -in 'stopped','error') {
            Get-Receiver | Stop-Process
            Start-Receiver; Set-State 'starting'
        } elseif ($script:state -eq 'video') {
            $video = Get-Receiver | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } | Select-Object -First 1
            if ($video) { [FreeScreenWindow]::ShowWindow($video.MainWindowHandle,9) | Out-Null; [FreeScreenWindow]::SetForegroundWindow($video.MainWindowHandle) | Out-Null }
            else { $ui.StatusDescription.Text='The video stream is connected. The screen window is still getting ready.' }
        } else { Set-Page $true }
    } catch { $script:startupError=$_.Exception.Message; Set-State 'error' }
})
$ui.Toggle.Add_Click({
    if ($Preview) { return }
    if ($script:state -eq 'error') { Set-Page $true; return }
    Get-Receiver | Stop-Process
    Set-State 'stopped'
})
$ui.Firewall.Add_Click({
    if ($Preview) { return }
    try {
        $script:fwProcess=Start-Process powershell.exe -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "'+(Join-Path $PSScriptRoot 'Firewall.ps1')+'"') -WindowStyle Hidden -PassThru
        Update-State
    } catch { $ui.FirewallStatus.Text=$_.Exception.Message }
})
$ui.Logs.Add_Click({ if (!$Preview) { $log=Join-Path $PSScriptRoot 'receiver.log'; if (Test-Path $log) { Start-Process notepad.exe -ArgumentList ('"'+$log+'"') } else { $ui.FirewallStatus.Text='No diagnostic log is available yet.' } } })
$timer=New-Object Windows.Threading.DispatcherTimer
$timer.Interval=[TimeSpan]::FromSeconds(2)
$timer.Add_Tick({ try { Update-State } catch { $script:startupError=$_.Exception.Message; Set-State 'error' } })
$window.Add_Closed({
    $timer.Stop()
    if (!$Preview) { Get-Receiver | Stop-Process; $script:mutex.ReleaseMutex(); $script:mutex.Dispose() }
})
if ($Preview) {
    $window.Width=$PreviewWidth
    $window.Height=$PreviewHeight
    Set-State $PreviewState
    Set-Page ($PreviewPage -eq 'help')
    $ui.NetworkLabel.Text='Network access enabled'
    $ui.FirewallStatus.Text='Set up to receive connections on your local network.'
    $ui.Firewall.Content='Refresh network access'
    $window.Add_ContentRendered({
        if ($SmokeTest) {
            $ui.NavHelp.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
            if ($ui.HelpPage.Visibility -ne 'Visible' -or $ui.HomePage.Visibility -ne 'Collapsed') { throw 'Help navigation failed.' }
            $ui.Back.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
            if ($ui.HomePage.Visibility -ne 'Visible') { throw 'Back navigation failed.' }
            Set-State 'stopped'
            if ($ui.Toggle.Visibility -ne 'Collapsed' -or !$ui.Primary.IsEnabled) { throw 'Stopped state has no restart action.' }
            Set-State 'starting'
            if ($ui.Primary.IsEnabled) { throw 'Startup action must not start duplicate processes.' }
            Set-State 'video'
            if (!$ui.Primary.IsEnabled) { throw 'Video window action is inaccessible.' }
            Set-State $PreviewState
            Set-Page ($PreviewPage -eq 'help')
            Write-Output 'PASS: navigation, restart action, startup guard, video action'
        }
        if ($PreviewOutput) {
            $window.UpdateLayout()
            $bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap([int]$window.ActualWidth,[int]$window.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32)
            $bitmap.Render($window)
            $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder
            $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
            $stream=[IO.File]::Create($PreviewOutput)
            try { $encoder.Save($stream) } finally { $stream.Dispose() }
            $window.Close()
        }
    })
} else {
    Set-State 'starting'
    try { Start-Receiver } catch { $script:startupError=$_.Exception.Message; Set-State 'error' }
    $timer.Start()
}
$window.ShowDialog() | Out-Null
