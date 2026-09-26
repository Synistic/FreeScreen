$ErrorActionPreference = 'Stop'
$msys = Join-Path $PSScriptRoot 'vendor\msys64'
$prefix = Join-Path $msys 'ucrt64'
$source = Join-Path $PSScriptRoot 'vendor\UxPlay-current'
$env:MSYSTEM = 'UCRT64'
$env:PATH = "$prefix\bin;$env:PATH"
& "$prefix\bin\cmake.exe" -S $source -B "$source\build" -G Ninja -DCMAKE_BUILD_TYPE=Release -DNO_MARCH_NATIVE=ON
if ($LASTEXITCODE) { throw 'CMake configuration failed' }
& "$prefix\bin\cmake.exe" --build "$source\build" -j 8
if ($LASTEXITCODE) { throw 'Build failed' }
$dest = Join-Path $PSScriptRoot 'native-staging'
New-Item -ItemType Directory "$dest\lib\gstreamer-1.0" -Force | Out-Null
Copy-Item "$source\build\uxplay.exe" "$dest\uxplay-windows.exe" -Force
$plugins = 'autodetect','level','app','audioconvert','audioresample','coreelements','d3d11','libav','playback','videoconvertscale','videoparsersbad','videotestsrc','volume','wasapi2','typefindfunctions'
foreach ($plugin in $plugins) { Copy-Item "$prefix\lib\gstreamer-1.0\libgst$plugin.dll" "$dest\lib\gstreamer-1.0" -Force }
$queue = New-Object 'Collections.Generic.Queue[string]'
$seen = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
Get-ChildItem $dest -Recurse -File | Where-Object Extension -in '.exe','.dll' | ForEach-Object { $queue.Enqueue($_.FullName) }
while ($queue.Count) {
    $file = $queue.Dequeue()
    $imports = & "$prefix\bin\objdump.exe" -p $file
    if ($LASTEXITCODE) { throw "Cannot inspect $file" }
    foreach ($line in $imports) {
        if ($line -match 'DLL Name:\s*(\S+)') {
            $dll = $Matches[1]
            if ($seen.Add($dll) -and (Test-Path "$prefix\bin\$dll")) {
                Copy-Item "$prefix\bin\$dll" "$dest\$dll" -Force
                $queue.Enqueue("$dest\$dll")
            }
        }
    }
}
Copy-Item "$source\LICENSE" "$dest\LICENSE-UxPlay.txt" -Force
'UxPlay 1.74 with combined control SETUP info patch' | Set-Content "$dest\native-engine.txt"
New-Item -ItemType Directory "$dest\licenses" -Force | Out-Null
Copy-Item "$prefix\share\licenses\*" "$dest\licenses" -Recurse -Force
Get-ChildItem $dest -Recurse -File | Where-Object Name -ne 'manifest.json' | ForEach-Object {
    [pscustomobject]@{ File=$_.FullName.Substring($dest.Length+1).Replace('\','/'); SHA256=(Get-FileHash $_.FullName).Hash }
} | ConvertTo-Json | Set-Content "$dest\manifest.json"
Write-Host "Native receiver staged in $dest"
