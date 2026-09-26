param([string]$Destination)
$ErrorActionPreference='Stop'
if (!$Destination) { $Destination=Join-Path $PSScriptRoot 'dist\FreeScreen-source.zip' }
$files=@('.gitignore','.gitattributes','README.md','LICENSE','THIRD_PARTY.md','CONTRIBUTING.md','Start.vbs','FreeScreen.ps1','ReceiverHost.cs','receiver.args','Firewall.ps1','Setup.ps1','Prepare-Build.ps1','Build-Native.ps1','Build-Brand.ps1','Test-UI.ps1','Export-Source.ps1','test_receiver.py','ui\MainWindow.xaml','assets\mark.svg','assets\wordmark.svg','assets\mark.png','assets\freescreen.ico','docs\app.png','docs\help.png','docs\connected.png','patches\combined-setup-info.patch','.github\workflows\check.yml')
Add-Type -AssemblyName System.IO.Compression,System.IO.Compression.FileSystem
$destinationPath=[IO.Path]::GetFullPath($Destination)
New-Item -ItemType Directory (Split-Path $destinationPath) -Force | Out-Null
if (Test-Path $destinationPath) { throw 'Export exists; choose a new destination to preserve the previous export.' }
$archive=[IO.Compression.ZipFile]::Open($destinationPath,[IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in $files) {
        $path=Join-Path $PSScriptRoot $file
        if (!(Test-Path $path -PathType Leaf)) { throw "Missing source file: $file" }
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,$path,$file.Replace('\','/'),[IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
} finally { $archive.Dispose() }
Write-Host "Source export: $destinationPath"
