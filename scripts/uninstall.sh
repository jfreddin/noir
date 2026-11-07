#!/usr/bin/env bash
set -euo pipefail
prefix="${1:-$HOME/.local}"
rm -f -- "$prefix/bin/noir" "$prefix/share/applications/noir.desktop" "$prefix/share/icons/hicolor/scalable/apps/noir.svg" "$prefix/share/icons/hicolor/512x512/apps/noir.png"
if command -v gtk-update-icon-cache >/dev/null; then gtk-update-icon-cache -f -t "$prefix/share/icons/hicolor"; fi
rm -rf -- "$prefix/lib/noir" "$prefix/share/licenses/noir"
if command -v update-desktop-database >/dev/null; then update-desktop-database "$prefix/share/applications"; fi
printf 'Noir removed. Your library and settings were kept.\n'
