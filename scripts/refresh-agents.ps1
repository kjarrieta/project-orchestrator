#!powershell
# refresh-agents.ps1
#
# Regenera los .claude/agents/*.md de un proyecto contra los briefs vivos en
# ~/.claude/skills/project-orchestrator/references/, conservando el frontmatter
# YAML original (name, description, tools, model) de cada agente instalado.
#
# El setup del orquestador copia los briefs una sola vez; sin este comando, un
# brief editado en la skill queda invisible para los agentes ya desplegados.
# guard-sync compila reglas; este comando refresca cuerpos de agente. Son dos
# actualizaciones diferentes con dos caminos distintos y ambos deben correr
# cuando cambia una fuente.
#
# Uso:
#   refresh-agents.ps1 -ProjectDir <ruta>
#   refresh-agents.ps1 -All
#   refresh-agents.ps1 -Review
#   refresh-agents.ps1 -ProjectDir <ruta> -Force   # reescribe aunque el hash coincida

[CmdletBinding()]
param(
    [string]$ProjectDir,
    [switch]$All,
    [switch]$Review,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

$skillDir = Join-Path $HOME '.claude/skills/project-orchestrator'
$userMem  = Join-Path $HOME '.claude/project-orchestrator/memory'
$refDir   = Join-Path $skillDir 'references'
$registry = Join-Path $userMem 'guarded-projects.json'

# Briefs instalables (autoridad: setup.md paso 2)
$briefsInstalables = @(
    'feedback', 'architect', 'conventions-reviewer', 'robustness',
    'database', 'api', 'integrations', 'frontend', 'seo', 'performance',
    'sre', 'devops', 'business-rules', 'qa', 'security', 'red-team',
    'policy-compliance', 'documentation', 'learner'
)

function Get-ProjectList {
    if ($All -or $Review) {
        if (-not (Test-Path -LiteralPath $registry)) {
            Write-Host "registro AUSENTE: $registry"
            return @()
        }
        $data = Get-Content -LiteralPath $registry -Raw -Encoding UTF8 | ConvertFrom-Json
        return @($data.proyectos | ForEach-Object { $_.ruta })
    }
    if (-not $ProjectDir) {
        throw "Pasa -ProjectDir <ruta>, -All o -Review."
    }
    return @($ProjectDir)
}

function Get-CuerpoNormalizado {
    param([string]$Contenido)
    # Descarta frontmatter YAML (--- ... ---) y el preambulo "Lee ... evidence-protocol.md"
    # para que la comparacion sea contra el cuerpo real del brief.
    $lineas = $Contenido -split "`r?`n"
    $inicio = 0
    if ($lineas.Count -gt 0 -and $lineas[0] -eq '---') {
        for ($i = 1; $i -lt $lineas.Count; $i++) {
            if ($lineas[$i] -eq '---') { $inicio = $i + 1; break }
        }
    }
    $cuerpo = ($lineas[$inicio..($lineas.Count - 1)] -join "`n")
    # Elimina el preambulo evidence-protocol si esta al inicio del cuerpo
    $cuerpo = $cuerpo -replace '(?m)\A\s*Lee\s+`[^`]*evidence-protocol\.md`\s+y\s+respétalo\.\s*', ''
    return $cuerpo.Trim()
}

function Get-Hash {
    param([string]$Texto)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Texto)
    return -join ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') })
}

function Get-FrontmatterYAML {
    param([string[]]$Lineas)
    if ($Lineas.Count -lt 2 -or $Lineas[0] -ne '---') { return $null }
    for ($i = 1; $i -lt $Lineas.Count; $i++) {
        if ($Lineas[$i] -eq '---') {
            return ($Lineas[0..$i] -join "`n")
        }
    }
    return $null
}

function Refresh-Proyecto {
    param([string]$Ruta)

    Write-Host ""
    Write-Host "=== $Ruta ==="

    $agentsDir = Join-Path $Ruta '.claude/agents'
    if (-not (Test-Path -LiteralPath $agentsDir)) {
        Write-Host "  AUSENTE: no existe .claude/agents/ (no corrió el orquestador aquí)"
        return [ordered]@{ estado='AUSENTE'; refrescados=0; sin_cambio=0; huerfanos=0; faltantes=0 }
    }

    $refrescados = @()
    $sinCambio   = @()
    $huerfanos   = @()
    $faltantes   = @()

    # 1. Recorre los agentes instalados
    $instalados = Get-ChildItem -LiteralPath $agentsDir -Filter '*.md' -File
    $nombresInstalados = @($instalados | ForEach-Object { $_.BaseName })

    foreach ($archivo in $instalados) {
        $nombre = $archivo.BaseName
        $briefSrc = Join-Path $refDir "$nombre.md"

        if (-not (Test-Path -LiteralPath $briefSrc)) {
            $huerfanos += $nombre
            continue
        }

        $contenidoActual = Get-Content -LiteralPath $archivo.FullName -Raw -Encoding UTF8
        $cuerpoActual    = Get-CuerpoNormalizado -Contenido $contenidoActual
        # El brief tambien pasa por Get-CuerpoNormalizado para que la comparacion sea
        # independiente de line endings (CRLF vs LF) y de si el brief lleva o no su
        # propio frontmatter (algunos futuros briefs podrian llevarlo).
        $cuerpoBrief     = Get-CuerpoNormalizado -Contenido (Get-Content -LiteralPath $briefSrc -Raw -Encoding UTF8)

        if (-not $Force -and (Get-Hash $cuerpoActual) -eq (Get-Hash $cuerpoBrief)) {
            $sinCambio += $nombre
            continue
        }

        if ($Review) {
            $refrescados += "$nombre (DESACTUALIZADO, no escrito por --revisar)"
            continue
        }

        # Preserva el frontmatter YAML original
        $lineasActual = $contenidoActual -split "`r?`n"
        $frontmatter  = Get-FrontmatterYAML -Lineas $lineasActual
        if (-not $frontmatter) {
            Write-Host "  ATENCION: $nombre sin frontmatter YAML valido, se salta"
            continue
        }

        $preambulo = "`n`nLee ``$refDir/evidence-protocol.md`` y respétalo."
        $nuevo = $frontmatter + $preambulo + "`n`n" + $cuerpoBrief

        Set-Content -LiteralPath $archivo.FullName -Value $nuevo -Encoding UTF8 -NoNewline
        $refrescados += $nombre
    }

    # 2. Detecta briefs instalables ausentes en este proyecto
    foreach ($brief in $briefsInstalables) {
        if ($brief -notin $nombresInstalados) {
            $faltantes += $brief
        }
    }

    Write-Host "  refrescados: $($refrescados.Count)  sin cambio: $($sinCambio.Count)  huerfanos: $($huerfanos.Count)  faltantes: $($faltantes.Count)"
    if ($refrescados) { Write-Host ("    refrescados : " + ($refrescados -join ', ')) }
    if ($huerfanos)   { Write-Host ("    huerfanos   : " + ($huerfanos -join ', ') + "  (agente instalado sin brief fuente; candidato a borrar)") }
    if ($faltantes)   { Write-Host ("    faltantes   : " + ($faltantes -join ', ') + "  (brief instalable no desplegado; correr /orchestrator setup)") }

    return [ordered]@{
        estado      = if ($Review) { 'REVISADO' } else { 'OK' }
        refrescados = $refrescados.Count
        sin_cambio  = $sinCambio.Count
        huerfanos   = $huerfanos.Count
        faltantes   = $faltantes.Count
    }
}

$proyectos = Get-ProjectList
if ($proyectos.Count -eq 0) { exit 0 }

$totalRefrescados = 0
$totalFaltantes   = 0
$totalHuerfanos   = 0
foreach ($p in $proyectos) {
    $r = Refresh-Proyecto -Ruta $p
    $totalRefrescados += $r.refrescados
    $totalFaltantes   += $r.faltantes
    $totalHuerfanos   += $r.huerfanos
}

Write-Host ""
Write-Host "=== resumen ==="
Write-Host "proyectos: $($proyectos.Count)  agentes refrescados: $totalRefrescados  huerfanos: $totalHuerfanos  faltantes: $totalFaltantes"
if ($Review -and $totalRefrescados -gt 0) {
    Write-Host "modo --revisar: se detectó desactualización. Corre sin --revisar para aplicar."
}
