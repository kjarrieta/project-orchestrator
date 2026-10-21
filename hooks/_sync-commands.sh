#!/bin/sh
# Cuerpo compartido de los hooks post-*. Elige el PowerShell disponible y sale
# siempre con 0: una sincronizacion fallida no debe abortar un pull ni un checkout.
root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
script="$root/scripts/sync-commands.ps1"
[ -f "$script" ] || exit 0

if command -v pwsh >/dev/null 2>&1; then
  shell=pwsh
elif command -v powershell >/dev/null 2>&1; then
  shell=powershell
else
  echo "sync-commands: no hay PowerShell; corre el script a mano" >&2
  exit 0
fi

"$shell" -NoProfile -ExecutionPolicy Bypass -File "$script" || true
exit 0
