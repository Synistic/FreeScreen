$ErrorActionPreference='Stop'
$exe=Join-Path $PSScriptRoot 'runtime\uxplay-windows.exe'
$statusPath=Join-Path $PSScriptRoot 'firewall-status.txt'
$isAdmin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
try {
    if (!$isAdmin) {
        $process=Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "'+$PSCommandPath+'"') -PassThru -Wait
        exit $process.ExitCode
    }
    if (!(Test-Path $exe)) { throw 'The receiver is not installed.' }
    foreach ($protocol in 'TCP','UDP') {
        $name="FreeScreen-$protocol"
        $ports=@('7000-7002'); if ($protocol -eq 'UDP') { $ports+='5353' }
        $rule=Get-NetFirewallRule -Name $name -ErrorAction SilentlyContinue
        if (!$rule) {
            New-NetFirewallRule -Name $name -DisplayName "FreeScreen AirPlay ($protocol, local network)" -Direction Inbound -Action Allow -Program $exe -Protocol $protocol -LocalPort $ports -RemoteAddress LocalSubnet -Profile Any | Out-Null
        } else {
            $rule | Set-NetFirewallRule -Enabled True -Direction Inbound -Action Allow -Profile Any | Out-Null
            $rule | Get-NetFirewallApplicationFilter | Set-NetFirewallApplicationFilter -Program $exe | Out-Null
            $rule | Get-NetFirewallPortFilter | Set-NetFirewallPortFilter -Protocol $protocol -LocalPort $ports | Out-Null
            $rule | Get-NetFirewallAddressFilter | Set-NetFirewallAddressFilter -RemoteAddress LocalSubnet | Out-Null
        }
    }
    'OK' | Set-Content $statusPath
} catch { $_.Exception.Message | Set-Content $statusPath; exit 1 }
