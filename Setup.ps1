param([switch]$NoShortcut)
$ErrorActionPreference='Stop'
$runtime=Join-Path $PSScriptRoot 'runtime'
$staging=Join-Path $PSScriptRoot 'native-staging'
$active=@(Get-Process ReceiverHost,uxplay-windows -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($PSScriptRoot+'\',[StringComparison]::OrdinalIgnoreCase) })
if ($active.Count) { throw 'Please close FreeScreen before running setup.' }
if (!(Test-Path "$runtime\native-engine.txt")) {
    if (!(Test-Path "$staging\native-engine.txt")) { throw 'The native runtime is missing. Run Prepare-Build.ps1 and Build-Native.ps1 first.' }
    New-Item -ItemType Directory $runtime -Force | Out-Null
    Copy-Item "$staging\*" $runtime -Recurse -Force
}
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $compiler /nologo /target:winexe "/win32icon:$PSScriptRoot\assets\freescreen.ico" "/out:$PSScriptRoot\ReceiverHost.exe" "$PSScriptRoot\ReceiverHost.cs"
if ($LASTEXITCODE) { throw 'Could not build ReceiverHost.' }
if (!$NoShortcut) {
    $shell=New-Object -ComObject WScript.Shell
    $shortcut=$shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'FreeScreen.lnk'))
    $shortcut.TargetPath="$env:WINDIR\System32\wscript.exe"
    $shortcut.Arguments='"'+(Join-Path $PSScriptRoot 'Start.vbs')+'"'
    $shortcut.WorkingDirectory=$PSScriptRoot
    $shortcut.IconLocation=Join-Path $PSScriptRoot 'assets\freescreen.ico'
    $shortcut.Description='Your iPhone. On your PC.'
    $shortcut.Save()
}
Write-Host 'FreeScreen is ready. Open Start.vbs or the desktop shortcut.'
