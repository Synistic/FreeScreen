$ErrorActionPreference='Stop'
$vendor=Join-Path $PSScriptRoot 'vendor'
New-Item -ItemType Directory $vendor -Force | Out-Null
$msys=Join-Path $vendor 'msys64'
$archive=Join-Path $vendor 'msys2-base.tar.xz'
if (!(Test-Path "$msys\usr\bin\bash.exe")) {
    if (!(Test-Path $archive)) { Invoke-WebRequest 'https://repo.msys2.org/distrib/x86_64/msys2-base-x86_64-20260611.tar.xz' -OutFile $archive -UseBasicParsing }
    if ((Get-FileHash $archive).Hash -ne 'A2D047E8EE213C3C6A49A8DE427EB1069DF12207C0422FF1B3CBB5C905C34221') { throw 'MSYS2 archive checksum mismatch.' }
    & tar.exe -xf $archive -C $vendor
    if ($LASTEXITCODE) { throw 'Could not extract MSYS2.' }
    & "$msys\usr\bin\bash.exe" -lc 'true'
    if ($LASTEXITCODE) { throw 'MSYS2 initialization failed.' }
}
& "$msys\usr\bin\bash.exe" -lc 'pacman -Sy --noconfirm --needed mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-cmake mingw-w64-ucrt-x86_64-libplist mingw-w64-ucrt-x86_64-openssl mingw-w64-ucrt-x86_64-gstreamer mingw-w64-ucrt-x86_64-gst-plugins-base mingw-w64-ucrt-x86_64-gst-plugins-good mingw-w64-ucrt-x86_64-gst-plugins-bad mingw-w64-ucrt-x86_64-gst-libav'
if ($LASTEXITCODE) { throw 'MSYS2 package installation failed.' }
$source=Join-Path $vendor 'UxPlay-current'
$revision='41ca38e3d36cab10bca86c9c5f04e0e4fcbe4303'
if (!(Test-Path "$source\.git")) {
    & git clone https://github.com/FDH2/UxPlay.git $source
    if ($LASTEXITCODE) { throw 'UxPlay clone failed.' }
    & git -C $source checkout --detach $revision
    if ($LASTEXITCODE) { throw 'Pinned revision unavailable.' }
}
if ((& git -C $source rev-parse HEAD).Trim() -ne $revision) { throw 'Existing source differs from pinned revision; no files were reset.' }
$patch=Join-Path $PSScriptRoot 'patches\combined-setup-info.patch'
$ErrorActionPreference='Continue'
& git -C $source apply --reverse --check $patch 2>$null
$alreadyApplied=($LASTEXITCODE -eq 0)
$ErrorActionPreference='Stop'
if (!$alreadyApplied) {
    & git -C $source apply --check $patch
    if ($LASTEXITCODE) { throw 'Patch cannot be applied safely.' }
    & git -C $source apply $patch
    if ($LASTEXITCODE) { throw 'Patch failed.' }
}
Write-Host 'Build environment ready. Run Build-Native.ps1 next.'
