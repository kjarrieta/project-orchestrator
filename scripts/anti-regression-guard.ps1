#Requires -Version 5.1
<#
.SYNOPSIS
  Guard anti-regresion en tiempo de escritura (Capa C). Hook PreToolUse sobre Edit|Write.

.DESCRIPTION
  Lee por stdin el JSON del evento PreToolUse, resuelve las reglas de
  .orchestrator/guard-rules.json cuyo alcance_rutas casa con el archivo editado, y:

    - grep_prohibido   : el patron NO debe aparecer en el contenido propuesto -> BLOQUEA
    - grep_requerido   : si aparece `patron`, debe aparecer tambien `requiere_ademas`
                         en el contenido resultante -> BLOQUEA si falta
    - test_requerido   : no bloquea la escritura; se inyecta como recordatorio y la
                         Fase 5 lo exige
    - recordatorio     : politica en prosa sin firma verificable; se inyecta al contexto

  Bloquear = exit 2 con el motivo por stderr (contrato PreToolUse). No bloquear pero
  tener algo que decir = exit 0 con hookSpecificOutput.additionalContext por stdout.

  Si no existe guard-rules.json, sale en silencio (exit 0): un proyecto que aun no
  corrio la skill no debe quedar bloqueado.

.NOTES
  El bypass NO es silencioso. Se activa por variable de entorno con los IDs exactos:
      $env:ORCH_GUARD_BYPASS = "REG-014,EMP-APIS-03"
  y queda registrado en .orchestrator/guard-bypass.log con fecha, ruta y regla.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Un guard que revienta no debe bloquear el trabajo: cualquier fallo inesperado sale 0.
# La red final es la Capa A en CI, no este script.
trap {
    Write-Host "[guard] error interno, no se bloquea: $($_.Exception.Message)"
    exit 0
}

# ---------------------------------------------------------------- entrada del evento

$raw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }

$evt = $raw | ConvertFrom-Json
$toolName = if ($evt.PSObject.Properties['tool_name']) { $evt.tool_name } else { '' }
if ($toolName -notin @('Edit', 'Write', 'MultiEdit', 'NotebookEdit')) { exit 0 }

$ti = $evt.tool_input
if (-not $ti) { exit 0 }

$filePath = if ($ti.PSObject.Properties['file_path']) { [string]$ti.file_path } else { '' }
if ([string]::IsNullOrWhiteSpace($filePath)) { exit 0 }

# El contenido que se va a escribir. Write trae `content`; Edit trae `new_string`;
# MultiEdit trae `edits[]`. Se concatena todo lo que entra al archivo.
$propuesto = New-Object System.Text.StringBuilder
foreach ($campo in @('content', 'new_string')) {
    if ($ti.PSObject.Properties[$campo] -and $ti.$campo) {
        [void]$propuesto.AppendLine([string]$ti.$campo)
    }
}
if ($ti.PSObject.Properties['edits'] -and $ti.edits) {
    foreach ($e in $ti.edits) {
        if ($e.PSObject.Properties['new_string'] -and $e.new_string) {
            [void]$propuesto.AppendLine([string]$e.new_string)
        }
    }
}
$textoPropuesto = $propuesto.ToString()
if ([string]::IsNullOrWhiteSpace($textoPropuesto)) { exit 0 }

# ---------------------------------------------------------------- reglas del proyecto

$projectDir = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR }
              elseif ($evt.PSObject.Properties['cwd'] -and $evt.cwd) { [string]$evt.cwd }
              else { (Get-Location).Path }

$rulesPath = Join-Path $projectDir '.orchestrator/guard-rules.json'
if (-not (Test-Path -LiteralPath $rulesPath)) { exit 0 }

$rules = (Get-Content -LiteralPath $rulesPath -Raw -Encoding UTF8 | ConvertFrom-Json)
if (-not $rules.PSObject.Properties['reglas'] -or -not $rules.reglas) { exit 0 }

# Ruta relativa al proyecto y normalizada a separador POSIX: los globs del ledger y del
# policy-index se escriben siempre con "/", en Windows tambien.
$rutaRel = $filePath
try {
    $full = [System.IO.Path]::GetFullPath($filePath)
    $base = [System.IO.Path]::GetFullPath($projectDir).TrimEnd('\', '/')
    if ($full.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) {
        $rutaRel = $full.Substring($base.Length).TrimStart('\', '/')
    }
} catch { }
$rutaRel = $rutaRel -replace '\\', '/'

function Test-GlobMatch {
    param([string]$Glob, [string]$Path)
    # ** cruza separadores; * no. Se traduce a regex anclada, insensible a mayusculas
    # porque el sistema de archivos de Windows tampoco distingue.
    $rx = [System.Text.RegularExpressions.Regex]::Escape($Glob)
    $rx = $rx -replace '\\\*\\\*/', '(?:.*/)?'   # "**/" -> cualquier prefijo de carpetas
    $rx = $rx -replace '\\\*\\\*', '.*'          # "**"  -> cualquier cosa
    $rx = $rx -replace '\\\*', '[^/]*'           # "*"   -> dentro de un segmento
    $rx = $rx -replace '\\\?', '[^/]'
    return [System.Text.RegularExpressions.Regex]::IsMatch(
        $Path, "^$rx$", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
}

$aplicables = @()
foreach ($r in $rules.reglas) {
    if (-not $r.PSObject.Properties['alcance_rutas'] -or -not $r.alcance_rutas) { continue }
    foreach ($g in $r.alcance_rutas) {
        if (Test-GlobMatch -Glob ([string]$g) -Path $rutaRel) { $aplicables += $r; break }
    }
}
if ($aplicables.Count -eq 0) { exit 0 }

# ---------------------------------------------------------------- bypass declarado

$bypass = @()
if ($env:ORCH_GUARD_BYPASS) {
    $bypass = $env:ORCH_GUARD_BYPASS -split ',' | ForEach-Object { $_.Trim() } |
              Where-Object { $_ }
}

function Write-BypassLog {
    param([string]$Id, [string]$Ruta, [string]$Invariante)
    $log = Join-Path $projectDir '.orchestrator/guard-bypass.log'
    $dir = Split-Path -Parent $log
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    Add-Content -LiteralPath $log -Encoding UTF8 `
        -Value "$stamp  BYPASS $Id  $Ruta  |  $Invariante"
}

# ---------------------------------------------------------------- evaluacion

# El contenido resultante importa para grep_requerido: en un Edit, `requiere_ademas`
# puede estar ya en el archivo fuera del fragmento editado. Se evalua sobre
# archivo-actual + fragmento propuesto, no solo sobre el fragmento.
$textoResultante = $textoPropuesto
if (Test-Path -LiteralPath $filePath) {
    try {
        $actual = Get-Content -LiteralPath $filePath -Raw -Encoding UTF8
        if ($actual) { $textoResultante = "$actual`n$textoPropuesto" }
    } catch { }
}

$bloqueos = @()
$avisos = @()

foreach ($r in $aplicables) {
    $id = if ($r.PSObject.Properties['id']) { [string]$r.id } else { 'SIN-ID' }
    $inv = if ($r.PSObject.Properties['invariante']) { [string]$r.invariante } else { '' }
    $fuente = if ($r.PSObject.Properties['fuente']) { [string]$r.fuente } else { '' }
    $correccion = if ($r.PSObject.Properties['correccion']) { [string]$r.correccion } else { '' }
    $gate = if ($r.PSObject.Properties['gate']) { [string]$r.gate } else { 'BLOCKING' }

    if (-not $r.PSObject.Properties['senal'] -or -not $r.senal) {
        if ($inv) { $avisos += "- [$id] ($fuente) $inv" }
        continue
    }
    $s = $r.senal
    $tipo = if ($s.PSObject.Properties['tipo']) { [string]$s.tipo } else { '' }
    $patron = if ($s.PSObject.Properties['patron']) { [string]$s.patron } else { '' }

    $viola = $false
    switch ($tipo) {
        'grep_prohibido' {
            if ($patron -and $textoPropuesto -match $patron) { $viola = $true }
        }
        'grep_requerido' {
            $extra = if ($s.PSObject.Properties['requiere_ademas']) {
                [string]$s.requiere_ademas
            } else { '' }
            if ($patron -and $extra -and
                $textoPropuesto -match $patron -and
                $textoResultante -notmatch $extra) { $viola = $true }
        }
        default {
            # test_requerido y recordatorio: no bloquean la escritura.
            if ($inv) { $avisos += "- [$id] ($fuente) $inv" }
        }
    }

    if (-not $viola) { continue }

    if ($bypass -contains $id) {
        Write-BypassLog -Id $id -Ruta $rutaRel -Invariante $inv
        $avisos += "- [$id] BYPASS DECLARADO por el operador. Registrado en guard-bypass.log. $inv"
        continue
    }

    if ($gate -eq 'NON-BLOCKING') {
        $avisos += "- [$id] ($fuente) VIOLADO, no bloqueante: $inv"
        continue
    }

    $detalle = "[$id] $inv"
    if ($fuente) { $detalle += "`n    Fuente: $fuente" }
    if ($correccion) { $detalle += "`n    Correccion esperada: $correccion" }
    if ($tipo -eq 'grep_requerido') {
        $extra = [string]$s.requiere_ademas
        $detalle += "`n    Detectado: /$patron/ sin /$extra/ en el archivo resultante."
    } else {
        $detalle += "`n    Detectado: /$patron/ en el contenido propuesto."
    }
    $bloqueos += $detalle
}

# ---------------------------------------------------------------- salida

if ($bloqueos.Count -gt 0) {
    $msg = @()
    $msg += "BLOQUEADO por el guard anti-regresion (Capa C) en $rutaRel"
    $msg += ""
    $msg += "Esta escritura viola $($bloqueos.Count) invariante(s) ya documentado(s):"
    $msg += ""
    foreach ($b in $bloqueos) { $msg += "  $b"; $msg += "" }
    $msg += "No reescribas el guard ni lo rodees. Corrige el codigo para cumplir el"
    $msg += "invariante. Si el hallazgo es un falso positivo justificado, el operador"
    $msg += "levanta el guard de forma explicita para esos IDs:"
    $msg += '    $env:ORCH_GUARD_BYPASS = "' + (($bloqueos | ForEach-Object {
                if ($_ -match '^\[([^\]]+)\]') { $Matches[1] } }) -join ',') + '"'
    $msg += "y queda registrado en .orchestrator/guard-bypass.log."
    [Console]::Error.WriteLine(($msg -join "`n"))
    exit 2
}

if ($avisos.Count -gt 0) {
    $ctx = @("Invariantes vigentes para $rutaRel (registro anti-regresion):") + $avisos
    $out = @{
        hookSpecificOutput = @{
            hookEventName    = 'PreToolUse'
            additionalContext = ($ctx -join "`n")
        }
    }
    $out | ConvertTo-Json -Depth 6 -Compress
}

exit 0
