#!/usr/bin/env pwsh
# Sincroniza commands/ de la skill con el directorio que el host realmente lee.
#
# Por que existe: la skill guarda sus comandos en commands/, pero Claude Code solo
# descubre ~/.claude/commands/. Son dos copias y se desincronizan en silencio: el
# sintoma es un comando que "no existe", que no dice nada sobre la causa. Este script
# es el paso de INSTALL.md hecho repetible; los hooks de hooks/ lo disparan solos
# despues de cada pull, merge o checkout.
#
# No borra nada: copia y sobrescribe lo que viene de la skill, y deja intacto
# cualquier otro comando propio que ya viviera en el destino.
[CmdletBinding()]
param([switch]$Quiet)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot

# Comparacion byte a byte con .NET en vez de Get-FileHash: ese cmdlet no esta
# disponible en todos los hosts de PowerShell 5.1 y su ausencia aborta el script.
function Test-FileDiffers {
    param([string]$A, [string]$B)
    $ba = [System.IO.File]::ReadAllBytes($A)
    $bb = [System.IO.File]::ReadAllBytes($B)
    if ($ba.Length -ne $bb.Length) { return $true }
    for ($i = 0; $i -lt $ba.Length; $i++) {
        if ($ba[$i] -ne $bb[$i]) { return $true }
    }
    return $false
}

function Sync-Dir {
    param([string]$Src, [string]$Dest)
    if (-not (Test-Path -LiteralPath $Src)) { return }
    if (-not (Test-Path -LiteralPath $Dest)) {
        New-Item -ItemType Directory -Path $Dest -Force | Out-Null
    }
    foreach ($f in Get-ChildItem -LiteralPath $Src -Filter '*.md' -File) {
        $target = Join-Path $Dest $f.Name
        $differs = (-not (Test-Path -LiteralPath $target)) -or
                   (Test-FileDiffers -A $f.FullName -B $target)
        if ($differs) {
            Copy-Item -LiteralPath $f.FullName -Destination $target -Force
            $f.Name
        }
    }
}

# Variante Claude Code. Destino canonico segun INSTALL.md.
$changed = @(Sync-Dir -Src (Join-Path $repo 'commands') `
                      -Dest (Join-Path $HOME '.claude\commands'))

# Variante opencode: SOLO si ese backend ya esta instalado. Las variantes hablan de
# mecanismos de activacion distintos (plugins vs skills/MCP); mezclarlas rompe las
# rutas de activacion, asi que nunca se crea el directorio si no existia.
$ocDest = Join-Path $HOME '.config\opencode\commands'
if (Test-Path -LiteralPath $ocDest) {
    $changed += @(Sync-Dir -Src (Join-Path $repo 'commands\opencode') -Dest $ocDest |
                  ForEach-Object { "opencode/$_" })
}

if (-not $Quiet) {
    if ($changed.Count -eq 0) {
        Write-Host "comandos del orquestador: ya sincronizados"
    } else {
        Write-Host "comandos del orquestador sincronizados ($($changed.Count)):"
        $changed | ForEach-Object { Write-Host "  $_" }
        Write-Host "Reinicia Claude Code para que los registre."
    }
}
