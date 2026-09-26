# Third-party components

This source export contains FreeScreen code, original branding and a patch. Downloaded binaries and upstream trees are excluded.

## UxPlay

- Project: https://github.com/FDH2/UxPlay
- Pinned revision: `41ca38e3d36cab10bca86c9c5f04e0e4fcbe4303` (1.74)
- Change: `patches/combined-setup-info.patch`
- Main project license: GPLv3. Retain LICENSE and individual component notices, including LGPL and MIT components.

FreeScreen branding does not replace upstream authorship. An earlier prototype used leapbtw/uxplay-windows; the current receiver is built directly from UxPlay.

## Dependencies

MSYS2 supplies MinGW, GStreamer, FFmpeg/libav, OpenSSL, libplist and transitive dependencies. They have separate licenses. Build-Native.ps1 copies installed license directories into staging; consult original package/source metadata too.

MSYS2 archive: `msys2-base-x86_64-20260611.tar.xz` from https://repo.msys2.org/distrib/x86_64/

SHA-256: `A2D047E8EE213C3C6A49A8DE427EB1069DF12207C0422FF1B3CBB5C905C34221`

## Publishing

Export-Source.ps1 uses an allowlist to exclude device logs, identifiers, toolchains and binaries. A source repository is different from a binary release. For binary distribution, include applicable notices and corresponding source/build materials wherever licenses require them. Binary release compliance is not automated by this source export.
