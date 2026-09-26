$ErrorActionPreference='Stop'
foreach ($file in Get-ChildItem $PSScriptRoot -Filter '*.ps1') {
    $tokens=$null; $errors=$null
    [Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors) | Out-Null
    if ($errors.Count) { throw "$($file.Name): $($errors[0].Message)" }
}
$testDir=Join-Path $PSScriptRoot '.local\ui-tests'
New-Item -ItemType Directory $testDir -Force | Out-Null
foreach ($state in 'ready','video','connected','stopped','error') {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "$PSScriptRoot\FreeScreen.ps1" -Preview -SmokeTest -PreviewState $state -PreviewWidth 940 -PreviewHeight 720 -PreviewOutput "$testDir\$state.png"
    if ($LASTEXITCODE -ne 0 -or !(Test-Path "$testDir\$state.png")) { throw "UI test failed: $state" }
}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "$PSScriptRoot\FreeScreen.ps1" -Preview -SmokeTest -PreviewPage help -PreviewWidth 940 -PreviewHeight 720 -PreviewOutput "$testDir\help.png"
if ($LASTEXITCODE) { throw 'Help preview failed' }
Write-Host 'PASS: PowerShell syntax, five UI states, help navigation and 940px previews.'
