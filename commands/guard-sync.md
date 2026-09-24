---
description: Instala o actualiza el guard anti-regresión de escritura en un proyecto (o en todos los que ya corrieron el orquestador) y recompila el contrato de política — ejecútalo cada vez que se anexe conocimiento o normativa a la skill
argument-hint: "[ruta del proyecto | --all | revisar] [--force]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, PowerShell
---

# Sincronizar el guard de escritura

Pone al día la **Capa C** —lo único de la skill que actúa *mientras* se escribe código— en
proyectos que ya corrieron el orquestador. Dos cosas que no son lo mismo y este comando
hace ambas:

1. **Instalar el cableado** (hook `PreToolUse` en el `.claude/settings.json` del proyecto).
   Se hace una vez por proyecto; es idempotente.
2. **Recompilar el contrato** (`.orchestrator/guard-rules.json`) desde las cuatro fuentes
   de política. Se hace **cada vez que cambia una fuente**: normativa nueva, aprendizaje
   promovido, entrada al registro de regresiones, o una versión nueva de la skill.

Lee `references/anti-regression.md` (las cuatro capas), `references/automation-hooks.md`
(contrato del hook y convención de firma) y `references/behavioral-journey-tracing.md`
(los 10 patrones A–J y el trigger UNVERIFIED) antes de operar.

> **Contrato: cada regla compilada lleva su etiqueta de patrón.** El
> `.orchestrator/guard-rules.json` que emite este comando incluye `pattern:
> A|B|C|D|E|F|G|H|I|J|—` por regla (heredado de la destilación). Cuando recompiles,
> verifica que ninguna regla con `pattern: —` en realidad encaja en A–J: si aparece un
> agrupamiento nuevo de reglas `—` sobre el mismo comportamiento, reclasifícalo antes de
> compilar. También reporta al final del run cuántas reglas del contrato están cubiertas
> por cada patrón — un patrón que dejó de tener reglas activas puede ser señal de
> obsolescencia; un patrón sobre-representado es señal de que la protección real está
> ahí y no en donde el equipo cree.

Argumento: $ARGUMENTS

## Cuándo ejecutarlo

| Disparador | Argumento | Por qué |
|---|---|---|
| Un proyecto viejo que nunca tuvo guard | `<ruta>` | Retrofit: corrió el orquestador antes de que existiera la Capa C ejecutable |
| Cargaste normativa con `/policy-update` | `--all` | La política nueva no bloquea nada hasta recompilar |
| Promoviste aprendizaje con `/learn-from` | `--all` | Idem: la memoria nueva es prosa hasta que se compila |
| El Aprendiz añadió entradas al registro | `<ruta>` | Ese proyecto tiene invariantes nuevos que aún no bloquean |
| Actualizaste la skill | `--all --force` | Los scripts cambiaron; el cableado puede haber quedado viejo |
| Solo quieres saber la cobertura | `revisar` | No escribe nada; reporta qué es exigible y qué no |

**La regla que resume todas:** *anexar conocimiento no lo hace exigible. Compilarlo, sí.*
Una política cargada y no compilada es exactamente el caso que hace que la auditoría de
rama encuentre lo que la ejecución debió impedir.

## Procedimiento

### Paso 1 — Resolver el alcance

- **Ruta explícita o vacío:** el proyecto indicado, o el directorio de trabajo actual. Si
  el directorio de trabajo es el home del usuario, **detente**: pide que abra Claude Code
  dentro de un proyecto o que pase la ruta.
- **`--all`:** lee el registro `~/.claude/project-orchestrator/memory/guarded-projects.json`
  (lo mantiene este mismo comando). Para cada entrada, verifica que la ruta siga existiendo
  y que conserve su `.orchestrator/`; las que no, se marcan `AUSENTE` y se reportan — no se
  borran solas del registro.
- **`revisar`:** modo lectura, ver más abajo.

Un proyecto **sin `.orchestrator/`** nunca corrió el orquestador. No lo instales: repórtalo
y sugiere `/orchestrator` primero. El guard sin registro de regresiones no protege nada.

### Paso 2 — Compilar el contrato (siempre, antes que el cableado)

```powershell
& "$HOME/.claude/skills/project-orchestrator/scripts/compile-guard-rules.ps1" -ProjectDir "<ruta>"
```

Produce `.orchestrator/guard-rules.json`. Su salida trae el dato que importa:

```
reglas: N  (bloqueantes: B, recordatorios: R)
sin firma: S  <- estas NO se pueden hacer cumplir al escribir
```

**Compila primero y cablea después.** Un hook activo apuntando a un contrato inexistente no
rompe nada (el guard sale en silencio), pero da la falsa sensación de estar protegido.

### Paso 3 — Cablear el hook

Fusiona en el `.claude/settings.json` **del proyecto** (nunca el global: la protección es
por proyecto y se versiona con él):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "pwsh -NoProfile -File \"$HOME/.claude/skills/project-orchestrator/scripts/anti-regression-guard.ps1\"",
            "timeout": 60
          }
        ]
      }
    ]
  }
}
```

Reglas de fusión, en orden:

1. **Si el archivo no existe**, créalo con solo este bloque.
2. **Si existe**, léelo entero y conserva todo lo demás. `enabledPlugins`, permisos y otros
   hooks se respetan intactos.
3. **Si ya hay un `PreToolUse` con otro matcher**, añade el grupo nuevo al array; no
   reemplaces el existente.
4. **Si ya hay un manejador de este mismo guard** (su `command` menciona
   `anti-regression-guard`), actualiza ese manejador en su sitio en vez de duplicarlo.
   Duplicarlo haría que cada edición se evalúe dos veces y reporte el bloqueo dos veces.
5. **Nunca escribas sin mostrar el diff** del `settings.json` y obtener el visto bueno. Un
   hook es código que corre solo con los privilegios de shell de la persona
   (`automation-hooks.md`, «Advertencia de seguridad»). Esa compuerta no se salta ni con
   `--force`.

`--force` solo significa "reescribe el manejador aunque ya parezca al día" (útil tras
actualizar la skill). **No** significa "escribe sin preguntar".

### Paso 4 — Verificar que bloquea de verdad

Un hook cableado que no bloquea es peor que ninguno: da confianza falsa. Verifica con una
regla real del proyecto, sin tocar el código del proyecto:

1. Toma una entrada `BLOCKING` de `guard-rules.json` y su `alcance_rutas`.
2. Construye un evento de prueba en un archivo temporal (fuera del repo) y pásalo por
   stdin al guard como proceso real:

```powershell
$evt = @{ tool_name='Write'
          tool_input=@{ file_path="<ruta>/<archivo que casa el glob>"
                        content='<fragmento que viola la firma>' } } |
       ConvertTo-Json -Depth 8 -Compress
Set-Content "$env:TEMP\guard-probe.json" $evt -Encoding UTF8 -NoNewline
$env:CLAUDE_PROJECT_DIR = "<ruta>"
cmd /c "pwsh -NoProfile -File `"$HOME/.claude/skills/project-orchestrator/scripts/anti-regression-guard.ps1`" < `"$env:TEMP\guard-probe.json`" 2>&1"
$LASTEXITCODE   # debe ser 2
```

**Una tubería de PowerShell no alimenta `[Console]::In`.** Si invocas el script con
`$json | & guard.ps1` siempre saldrá 0 y creerás que no funciona. Tiene que ser un proceso
con stdin real, como lo invoca el hook.

Si el exit no es 2, no reportes éxito: el guard está mal cableado o el glob no casa.

### Paso 5 — Registrar y reportar

Anota el proyecto en `~/.claude/project-orchestrator/memory/guarded-projects.json`, que es
lo que hace posible el `--all` de la próxima vez:

```json
{
  "schema_version": 1,
  "proyectos": [
    {
      "ruta": "C:/ruta/al/proyecto",
      "instalado": "2026-09-15",
      "ultima_sincronizacion": "2026-09-15",
      "reglas": 7,
      "bloqueantes": 2,
      "sin_firma": 171
    }
  ]
}
```

Y reporta, por proyecto:

- Reglas compiladas, cuántas bloquean y cuántas son recordatorio.
- **`sin_firma`: el número de políticas que siguen siendo prosa** y por tanto nadie puede
  hacer cumplir al escribir. Este es el dato que la persona necesita ver, no el de reglas
  activas: mide la superficie que seguirá cayendo en auditoría humana.
- Si el hook se creó, se actualizó o ya estaba al día.
- El resultado de la prueba del Paso 4.

## Modo `revisar`

No escribe nada. Para cada proyecto del registro reporta:

- **Desincronización:** `guard-rules.json` más viejo que su registro de regresiones, que el
  `index.md` del corpus, o que los archivos de memoria de lenguaje. Es el fallo silencioso
  más común: se cargó normativa y nadie recompiló.
- **Cableado roto:** hook ausente, duplicado, o apuntando a una ruta de script que ya no
  existe (típico tras mover o reinstalar la skill).
- **Cobertura:** bloqueantes vs. `sin_firma`, y las entradas `sin_firma` de severidad alta,
  que son las candidatas obvias a destilar a firma.
- **Bypass acumulado:** entradas de `.orchestrator/guard-bypass.log`. Un bypass repetido
  sobre la misma regla no es un falso positivo puntual: o la firma está mal escrita, o el
  invariante ya no aplica. Ambas cosas se resuelven, no se toleran.

## Reglas

- **Compilar no es opinar.** El compilador no inventa firmas: traduce las que existen. Si
  una política no declara su bloque ```` ```senal ````, sale en `sin_firma` y ahí se queda
  hasta que alguien la destile con evidencia. Inventar una regex para "cubrirla" produce
  falsos positivos que terminan con el guard apagado — el peor resultado posible.
- **Nunca instales el hook en `~/.claude/settings.json`.** Global significa que bloquea en
  proyectos cuyo contrato no existe y cuyas reglas no aplican.
- **Nunca apagues el guard para avanzar.** El bypass es por ID, declarado y registrado. Si
  hay que apagarlo entero, es un problema del contrato que se arregla en el contrato.
- **El guard no sustituye la Capa A.** Cubre lo que escribe Claude Code. Que ningún autor
  —humano u otra herramienta— mergee una regresión lo sigue garantizando el lint en CI.
