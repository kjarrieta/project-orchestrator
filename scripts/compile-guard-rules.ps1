#Requires -Version 5.1
<#
.SYNOPSIS
  Compila las cuatro fuentes de politica en .orchestrator/guard-rules.json.

.DESCRIPTION
  El guard de escritura (anti-regression-guard.ps1) solo puede evaluar firmas. Este
  script produce el contrato que consume, fusionando:

    1. regression-ledger.json      (proyecto)  -- ya trae `senal`, se copia tal cual
    2. company-policies/*.md       (usuario)   -- corpus corporativo
    3. memory/<lenguaje>.md        (usuario)   -- politicas de lenguaje y globales
    4. .claude/policy-index.md     (proyecto)  -- mapa ruta -> reglas duras

  Las fuentes 2-4 son prosa. Una entrada solo se vuelve exigible si declara un bloque
  de firma; el resto se emite en `sin_firma`, que es el inventario explicito de lo que
  NINGUNA maquina puede hacer cumplir y por tanto seguira cayendo en auditoria humana.

  Convencion de firma en prosa: bloque cercado ```senal con JSON, bajo el encabezado
  de la politica.

      ### EMP-APIS-03 - Toda respuesta de error usa el envelope estandar

      ```senal
      {
        "tipo": "grep_requerido",
        "alcance_rutas": ["app/Http/Controllers/**/*.php"],
        "patron": "response\\(\\)->json\\(",
        "requiere_ademas": "ErrorEnvelope|ApiResponse::",
        "gate": "BLOCKING",
        "correccion": "Usa ApiResponse::error(); no construyas el JSON a mano."
      }
      ```

.PARAMETER ProjectDir
  Raiz del proyecto. Por defecto $env:CLAUDE_PROJECT_DIR o el directorio actual.

.PARAMETER Lenguajes
  Lenguajes cuya memoria se compila (php, typescript, python, dart, javascript).
  Por defecto se detectan por los archivos del proyecto.
#>

[CmdletBinding()]
param(
    [string]$ProjectDir = $(if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR }
                           else { (Get-Location).Path }),
    [string[]]$Lenguajes,

    # Raiz de la memoria de usuario (corpus + memoria de lenguaje). Se parametriza para
    # poder verificar el compilador contra un corpus de prueba sin tocar el real.
    [string]$UserMemory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$userMem = if ($UserMemory) { $UserMemory }
           else { Join-Path $env:USERPROFILE '.claude/project-orchestrator/memory' }
$outPath = Join-Path $ProjectDir '.orchestrator/guard-rules.json'

$reglas = New-Object System.Collections.ArrayList
$sinFirma = New-Object System.Collections.ArrayList
$fuentes = New-Object System.Collections.ArrayList

function Add-Fuente {
    param([string]$Ruta, [string]$Estado, [int]$Reglas, [int]$SinFirma)
    [void]$fuentes.Add([ordered]@{
        ruta = $Ruta; estado = $Estado; reglas = $Reglas; sin_firma = $SinFirma
    })
}

# ------------------------------------------------- 1. registro de regresiones

$ledgerPath = Join-Path $ProjectDir '.orchestrator/project-memory/regression-ledger.json'
if (Test-Path -LiteralPath $ledgerPath) {
    $ledger = Get-Content -LiteralPath $ledgerPath -Raw -Encoding UTF8 | ConvertFrom-Json
    # Acepta un array plano, {entradas:[...]} (esquema canonico) o {entries:[...]}
    # (volcado en ingles, p.ej. de una sesion de code-review sin promover por el Aprendiz).
    $entradas = if ($ledger -is [array]) { $ledger }
                elseif ($ledger.PSObject.Properties['entradas']) { $ledger.entradas }
                elseif ($ledger.PSObject.Properties['entries']) { $ledger.entries }
                else { @($ledger) }
    $n = 0
    foreach ($e in $entradas) {
        if (-not $e.PSObject.Properties['senal'] -or -not $e.senal) {
            $idEntrada = if ($e.PSObject.Properties['id']) { [string]$e.id } else { '(sin-id)' }
            [void]$sinFirma.Add([ordered]@{
                id = $idEntrada; fuente = 'regression-ledger'
                motivo = 'entrada sin senal: no exigible por maquina'
            })
            continue
        }
        if (-not $e.senal.PSObject.Properties['alcance_rutas'] -or -not $e.senal.alcance_rutas) {
            $idEntrada = if ($e.PSObject.Properties['id']) { [string]$e.id } else { '(sin-id)' }
            [void]$sinFirma.Add([ordered]@{
                id = $idEntrada; fuente = 'regression-ledger'
                motivo = 'senal sin alcance_rutas: no se sabe a que archivos aplica'
            })
            continue
        }
        # Una entrada ya RESUELTO_CON_TEST conserva su guardian: sigue bloqueando.
        # Tolera tanto el esquema canonico (dominio/invariante/severidad) como un volcado
        # en ingles (domain/title/severity, p.ej. de una sesion de code-review).
        $dominio = if ($e.PSObject.Properties['dominio']) { [string]$e.dominio }
                   elseif ($e.PSObject.Properties['domain']) { [string]$e.domain }
                   else { '' }
        $invariante = if ($e.PSObject.Properties['invariante']) { [string]$e.invariante }
                      elseif ($e.PSObject.Properties['title']) { [string]$e.title }
                      else { '' }
        $severidadVal = if ($e.PSObject.Properties['severidad']) { [string]$e.severidad }
                        elseif ($e.PSObject.Properties['severity']) { [string]$e.severity }
                        else { 'HIGH' }
        [void]$reglas.Add([ordered]@{
            id            = $(if ($e.PSObject.Properties['id']) { [string]$e.id } else { '(sin-id)' })
            fuente        = "regression-ledger:$dominio"
            invariante    = $invariante
            gate          = $(if ($e.PSObject.Properties['gate']) { [string]$e.gate } else { 'BLOCKING' })
            severidad     = $severidadVal
            correccion    = $(if ($e.senal.PSObject.Properties['nota']) { [string]$e.senal.nota } else { '' })
            alcance_rutas = @($e.senal.alcance_rutas)
            senal         = $e.senal
        })
        $n++
    }
    Add-Fuente -Ruta $ledgerPath -Estado 'OK' -Reglas $n -SinFirma ($entradas.Count - $n)
} else {
    Add-Fuente -Ruta $ledgerPath -Estado 'AUSENTE' -Reglas 0 -SinFirma 0
}

# ------------------------------------------------- firmas embebidas en prosa

function Import-FirmasDeMarkdown {
    param([string]$Path, [string]$Etiqueta)

    if (-not (Test-Path -LiteralPath $Path)) {
        Add-Fuente -Ruta $Path -Estado 'AUSENTE' -Reglas 0 -SinFirma 0
        return
    }
    $texto = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $conFirma = 0
    $sin = 0

    # Cada encabezado ### o ## abre una politica. El ID es lo primero del titulo
    # cuando tiene forma de ID (EMP-APIS-03, PHP-SEC-02...); si no, se usa el titulo.
    $bloques = [regex]::Split($texto, '(?m)^(?=#{2,3}\s)') | Where-Object { $_ -match '\S' }
    foreach ($b in $bloques) {
        if ($b -notmatch '(?m)^#{2,3}\s+(.+?)\s*$') { continue }
        $titulo = $Matches[1].Trim()
        $id = if ($titulo -match '^([A-Z][A-Z0-9]+(?:-[A-Z0-9]+){1,3})') { $Matches[1] }
              else { "$Etiqueta::" + ($titulo -replace '[^\w]+', '-').Trim('-').ToLower() }

        $matches_ = [regex]::Matches($b, '```senal\s*\r?\n(.*?)\r?\n```', 'Singleline')
        if ($matches_.Count -eq 0) {
            [void]$sinFirma.Add([ordered]@{
                id = $id; fuente = $Etiqueta
                motivo = 'politica en prosa sin bloque ```senal```: no exigible por maquina'
            })
            $sin++
            continue
        }
        $idx = 0
        foreach ($m in $matches_) {
            $idx++
            # Sufijo -a, -b, -c... cuando hay mas de una senal en la misma entrada.
            # Con una sola senal se conserva el ID limpio para no romper compatibilidad.
            $ruleId = if ($matches_.Count -eq 1) { $id } else { "$id-" + [char]([int][char]'a' + $idx - 1) }
            try { $s = $m.Groups[1].Value | ConvertFrom-Json }
            catch {
                [void]$sinFirma.Add([ordered]@{
                    id = $ruleId; fuente = $Etiqueta
                    motivo = "bloque senal con JSON invalido: $($_.Exception.Message)"
                })
                $sin++
                continue
            }
            if (-not $s.PSObject.Properties['alcance_rutas'] -or -not $s.alcance_rutas) {
                [void]$sinFirma.Add([ordered]@{
                    id = $ruleId; fuente = $Etiqueta
                    motivo = 'senal sin alcance_rutas: no se sabe a que archivos aplica'
                })
                $sin++
                continue
            }
            [void]$reglas.Add([ordered]@{
                id            = $ruleId
                fuente        = $Etiqueta
                invariante    = $titulo
                gate          = $(if ($s.PSObject.Properties['gate']) { [string]$s.gate } else { 'BLOCKING' })
                severidad     = $(if ($s.PSObject.Properties['severidad']) { [string]$s.severidad } else { 'HIGH' })
                correccion    = $(if ($s.PSObject.Properties['correccion']) { [string]$s.correccion } else { '' })
                alcance_rutas = @($s.alcance_rutas)
                senal         = $s
            })
            $conFirma++
        }
    }
    Add-Fuente -Ruta $Path -Estado 'OK' -Reglas $conFirma -SinFirma $sin
}

# ------------------------------------------------- 2. corpus corporativo

$corpus = Join-Path $userMem 'company-policies'
if (Test-Path -LiteralPath $corpus) {
    Get-ChildItem -LiteralPath $corpus -Filter '*.md' -File |
        Where-Object { $_.Name -notin @('index.md', 'README.md') } |
        ForEach-Object { Import-FirmasDeMarkdown -Path $_.FullName -Etiqueta "corpus:$($_.BaseName)" }
} else {
    Add-Fuente -Ruta $corpus -Estado 'SIN-CORPUS' -Reglas 0 -SinFirma 0
}

# ------------------------------------------------- 3. memoria de lenguaje y global

if (-not $Lenguajes -or $Lenguajes.Count -eq 0) {
    $det = New-Object System.Collections.ArrayList
    $sondas = @{
        php        = @('composer.json', 'artisan')
        typescript = @('tsconfig.json')
        javascript = @('package.json')
        python     = @('pyproject.toml', 'requirements.txt', 'setup.py')
        dart       = @('pubspec.yaml')
    }
    foreach ($k in $sondas.Keys) {
        foreach ($f in $sondas[$k]) {
            if (Test-Path -LiteralPath (Join-Path $ProjectDir $f)) { [void]$det.Add($k); break }
        }
    }
    $Lenguajes = $det | Select-Object -Unique
}

# global siempre: aplica a todo proyecto, no depende del stack
Import-FirmasDeMarkdown -Path (Join-Path $userMem 'global/practices.md') -Etiqueta 'global'
foreach ($l in $Lenguajes) {
    $dir = Join-Path $userMem $l
    if (Test-Path -LiteralPath $dir) {
        Get-ChildItem -LiteralPath $dir -Filter '*.md' -File | ForEach-Object {
            Import-FirmasDeMarkdown -Path $_.FullName -Etiqueta "$l/$($_.BaseName)"
        }
    } else {
        Import-FirmasDeMarkdown -Path (Join-Path $userMem "$l.md") -Etiqueta $l
    }
}

# ------------------------------------------------- 4. policy-index (Capa C por ruta)

# El policy-index es prosa por glob. No bloquea: se inyecta como recordatorio al tocar
# la ruta, que es exactamente su proposito declarado en anti-regression.md.
$pIndex = Join-Path $ProjectDir '.claude/policy-index.md'
if (Test-Path -LiteralPath $pIndex) {
    $n = 0
    foreach ($linea in (Get-Content -LiteralPath $pIndex -Encoding UTF8)) {
        # Formato:  `ruta/glob/**` -> [regla, regla, regla]
        if ($linea -match '`([^`]+)`\s*(?:->|→)\s*\[(.+)\]\s*$') {
            $glob = $Matches[1].Trim()
            foreach ($regla in ($Matches[2] -split ',')) {
                $r = $regla.Trim().Trim('`')
                if (-not $r) { continue }
                [void]$reglas.Add([ordered]@{
                    id            = 'PIDX::' + ($r -replace '[^\w]+', '-').Trim('-').ToLower()
                    fuente        = 'policy-index'
                    invariante    = $r
                    gate          = 'NON-BLOCKING'
                    severidad     = 'MEDIUM'
                    correccion    = ''
                    alcance_rutas = @($glob)
                    senal         = [ordered]@{ tipo = 'recordatorio' }
                })
                $n++
            }
        }
    }
    Add-Fuente -Ruta $pIndex -Estado 'OK' -Reglas $n -SinFirma 0
} else {
    Add-Fuente -Ruta $pIndex -Estado 'AUSENTE' -Reglas 0 -SinFirma 0
}

# ------------------------------------------------- salida

$outDir = Split-Path -Parent $outPath
if (-not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$bloqueantes = @($reglas | Where-Object { $_.gate -eq 'BLOCKING' }).Count

$doc = [ordered]@{
    schema_version = 1
    generado       = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
    proyecto       = $ProjectDir
    lenguajes      = @($Lenguajes)
    resumen        = [ordered]@{
        reglas_totales = $reglas.Count
        bloqueantes    = $bloqueantes
        recordatorios  = $reglas.Count - $bloqueantes
        sin_firma      = $sinFirma.Count
    }
    fuentes        = @($fuentes)
    reglas         = @($reglas)
    sin_firma      = @($sinFirma)
}

$doc | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $outPath -Encoding UTF8

Write-Host "guard-rules.json -> $outPath"
Write-Host "  reglas: $($reglas.Count)  (bloqueantes: $bloqueantes, recordatorios: $($reglas.Count - $bloqueantes))"
Write-Host "  sin firma: $($sinFirma.Count)  <- estas NO se pueden hacer cumplir al escribir"
if ($sinFirma.Count -gt 0) {
    Write-Host ""
    Write-Host "  Huecos de exigibilidad (caeran en auditoria humana):"
    $sinFirma | Select-Object -First 10 | ForEach-Object {
        Write-Host "    - $($_.id)  [$($_.fuente)]  $($_.motivo)"
    }
    if ($sinFirma.Count -gt 10) { Write-Host "    ... y $($sinFirma.Count - 10) mas" }
}
