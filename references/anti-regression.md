# Defensa anti-regresión en profundidad (4 capas)

Esta es la **solución de raíz** al problema que originó todo: en un desarrollo nuevo no
se usa lo ya documentado, y reaparecen bugs que una política del proyecto ya prohibía.
Causa raíz confirmada: **la política es prosa pasiva** — nadie la relee al escribir y
nada falla cuando el anti-patrón vuelve; la auditoría es el único punto de captura y
llega tarde y cara.

La respuesta no es "auditar mejor": es hacer que **lo documentado se ejecute**. Cuatro
capas, cada una tapando el hueco de la anterior. El registro de regresiones
(`regression-ledger.md`) es el backbone que las alimenta a todas.

```
Lección / política con firma detectable
        │
        ▼
Registro de regresiones (backbone)  ── regression-ledger.md
        │
        ├─ A ─► Política ejecutable en el repo (rompe el build)   ← la pieza decisiva
        ├─ B ─► Production Readiness Gate (la auditoría re-clasifica el riesgo)
        ├─ C ─► Surface de política por ruta (aparece al tocar el módulo)
        └─ D ─► Suite de regresión (lo que no es estático se prueba)
```

Cobertura: **A + D** hacen que nada documentado se cuele; **B + C** evitan que nazca y
que la auditoría vuelva a subestimar un bloqueante.

---

## Capa A — Políticas ejecutables ("policies as tests") · la pieza decisiva

Convierte cada política con **firma detectable** en un gate que rompe el build ante una
regresión. Es la única capa que atrapa a **cualquier autor** —humano, otro agente, otra
herramienta— porque vive en el repo y corre en CI, no depende de que alguien recuerde
releer nada. Dos mecanismos complementarios:

1. **Tests de arquitectura** para reglas **estructurales** (las que un DSL de
   arquitectura expresa): p. ej. sin `catch(\Throwable)` en `Livewire/**`; sin ORM
   directo en la capa de presentación; modelos multi-tenant con su trait de scoping.
   En Laravel/PHP: tests Pest de arquitectura o equivalente del stack.
2. **Un linter de políticas** (`policy:lint`) para firmas **regex** que el DSL no
   expresa: `throw` dentro de `catch` en un canal de notificación; `->enum(` en una
   migración; `DECIMAL(5,4)` donde debe ser mayor precisión; mutador de UI sin
   `authorize()`/`abort_unless(can())`; `firstOrFail()` sobre un modelo de settings;
   índice sin la columna de tenant como líder.

**Cableado (obligatorio para que "obligue"):** `composer test`/suite del stack +
**pre-commit hook** + **CI**. Con eso, una regresión documentada **no puede mergear**.

**Ratchet por baseline.** Un proyecto existente tiene deuda: se congela la deuda actual
en un `baseline` (conteo de violaciones conocidas por regla) y el gate **solo falla ante
una violación nueva**. Cada corrección baja el baseline; la deuda solo disminuye, nunca
crece. Así la capa se adopta sin bloquear el desarrollo el primer día.

> Nota de estado: en el proyecto Refi esta capa **ya está construida y probada** (motor
> de lint puro, CLI, comando artisan, test de arquitectura en `composer test`,
> pre-commit, job de CI y baseline congelado). Al detectar Capa A ya presente, el
> orquestador **no la reconstruye**: la reutiliza y solo baja el baseline al corregir.

Genera Capa A por stack en la instalación (ver `setup.md`), acotando las reglas a las
firmas reales del proyecto — no inventes reglas sin una política que las respalde.

**La Capa A también cubre artefactos, no solo código.** Un comando, un instalador o un
README que existe en varias copias regresa igual que una función: una copia se mejora, las
otras quedan atrás y nada falla. Los dos invariantes de esa familia —copias declaradas y
hechos derivables que no se escriben a mano— viven en **`source-of-truth.md`** con sus
firmas, y su compuerta es el momento de distribuir (empaquetar, publicar, instalar), no el
de compilar.

## Capa B — La auditoría es un Production Readiness Gate

Detalle en `production-gate.md`. Resumen: veredicto GO/NO-GO con `hard_gates`; cada
hallazgo con **severidad + gate + confianza**; "PASS requiere evidencia"; y una
**Fase 2.5 de Cross-Audit + Meta-Audit (Red Team, Opus)** que reconcilia
contradicciones y puede anular un PASS (`red-team.md`). Evita que la auditoría vuelva a
cerrar con "nada bloquea" teniendo bloqueantes abiertos.

## Capa C — Surface de política por ruta

Que la lección relevante **aparezca al tocar el módulo**, no enterrada en mil líneas de
`CLAUDE.md`.

- **Artefacto:** `.claude/policy-index.md` — mapa `ruta/glob → políticas duras
  aplicables`. Ej.:
  - `app/Livewire/**` → [autorización en acciones, sin ORM directo, `wire:key`, sin `catch(\Throwable)`]
  - `database/migrations/**` → [sin enum nativo, DECIMAL con precisión suficiente, CHECK de dominio, columna de tenant líder en el índice]
  - `app/NotificationChannels/**` → [canal resiliente, no re-lanzar]
- **Enganche del orquestador (Fase 4 / desarrollo):** antes de escribir en un módulo, el
  agente carga **su rebanada** del índice y produce un checklist de cumplimiento con las
  mismas claves que las reglas de Capa A. Cierra el loop "documentado → aplicado".
- **Guard temprano (hook):** un `PreToolUse` sobre `Edit|Write` inyecta esas políticas
  como recordatorio al editar un archivo bajo el glob, y puede **bloquear** (exit 2) una
  firma dura (ver `automation-hooks.md`). Es complementario: cubre lo que escribe Claude
  Code; la red final sigue siendo Capa A en CI.

### El objetivo "aparece al tocar el módulo" tiene un mecanismo nativo: `paths:` (VINCULANTE)

Claude Code ya implementa "que la lección aparezca al tocar el módulo y no antes": los
`*.md` bajo **`.claude/rules/`** se cargan como instrucción de proyecto, y un archivo se
vuelve **condicional** —se carga solo cuando el archivo editado coincide— si y solo si trae
frontmatter YAML con la clave **`paths:`** (lista de globs, semántica `.gitignore` relativa
a la raíz del repo; `foo/**` cubre el directorio, `foo/x.php` la ruta exacta). Verificado en
el binario 2.1.267 (parser de frontmatter YAML real; el walk de rules filtra por presencia
de `globs`).

**El anti-patrón que lo invierte todo.** Un archivo en `.claude/rules/` **sin** `paths:`
(o con `paths: **`) NO es condicional: se carga en **todas** las sesiones como instrucción
always-on, igual que `CLAUDE.md`. Si se materializa la Capa C como un árbol de reglas por
entidad/módulo (`.claude/rules/<módulo>/<Entidad>.md`) y se olvida el `paths:`, la surface
diseñada para *reducir* contexto se convierte en el **piso de contexto permanente** — el
"enterrado en mil líneas" exacto que la Capa C quería evitar, ahora multiplicado por cada
archivo. Y el fallo es de arranque, no de trabajo largo: el banner rojo `Context limit
reached · /compact o /clear` **no** es un contador local, se dibuja solo cuando la API
responde `Prompt is too long`; si el piso supera la ventana del modelo (200.000 tokens por
defecto), el **primer** request de una sesión recién creada ya falla y **ni `/clear` ni
`/compact` lo arreglan** — el piso se reconstruye antes del primer mensaje.

**Reglas al materializar la Capa C como `.claude/rules/`:**
- Cada regla ligada a una clase/módulo lleva `paths:` con el glob de lo que gobierna
  (extraíble de las `ruta:línea` que ya cita). Solo las políticas **transversales cortas**
  que aplican a todo el código (p. ej. una política de comentarios o de capas) quedan
  always-on, y son la excepción, no la regla.
- El mapa `.claude/policy-index.md` **no** sufre esto: Claude Code autocarga `CLAUDE.md` y
  `.claude/rules/`, pero no los archivos sueltos de `.claude/`; el `policy-index` lo leen el
  guard y los agentes bajo demanda.
- Medir el piso real: leer el attachment `type: "instructions"` del `.jsonl` de la sesión en
  `~/.claude/projects/<proyecto>/`.

> Regresión que fija la regla (2026-09-29, proyecto app-saas): 82 archivos en
> `.claude/rules/` **sin** `paths:` sumaban ~110k tokens de piso; el primer request tras
> `/clear` pesaba 215.601 tokens contra una ventana de 200.000 y fallaba antes de escribir
> nada. Cura: `paths:` en las 80 reglas por entidad (piso del bloque rules 110k → ~2.7k
> tokens, −98%); 2 políticas transversales quedaron always-on. Cruza [[token-budget]]
> (`rules_surface`).

## Capa D — Garantía de regresión

Lo que **no es una firma estática** (una fuga cross-tenant, un cálculo con decimales, una
transición de estado) no lo atrapa un lint: se cierra con un **test de regresión**.

Regla que se documenta en `CLAUDE.md` del proyecto y que el Aprendiz hace cumplir:

> **Toda lección con firma de runtime cierra con un lint (Capa A) o un test de regresión
> (Capa D). Ninguna queda solo como prosa.**

El Aprendiz (`learner.md`), al destilar la sesión, no da por cerrada una lección de
seguridad/integridad/tenant/concurrencia hasta que tiene su lint o su test. QA y
Seguridad reciben ese backlog de tests como entrada de la Fase 5.

---

## Cómo encaja en el flujo del orquestador

- **Fase R (Retroalimentación):** carga el registro de regresiones y el `policy-index`;
  entrega a cada agente su rebanada por dominio/ruta.
- **Fase 0 (Intake):** detecta si Capa A ya existe; si no, la propone en el plan de setup.
- **Fase 2.5 (Red Team):** meta-audita y recalcula BLOCKING.
- **Fase 3 (Compuerta):** emite `20-production-gate.md` (GO/NO-GO) antes de preguntar.
- **Fase 4 (Aplicación):** cada agente carga su rebanada del `policy-index` (Capa C) y no
  escribe contra una regla dura; al corregir un hallazgo, baja el baseline de Capa A.
- **Fase 5 (Verificación):** exige el `test_required`/lint de cada entrada del registro
  que el diff tocó (Capa D). Sin él, el hallazgo queda UNVERIFIED, no PASS.
- **Cierre (Aprendiz):** promueve los hallazgos confirmados a entradas del registro y las
  materializa como lint (A) o test (D).
- **Distribución (empaquetar/publicar/instalar):** compuerta de `source-of-truth.md` —
  paridad de inventario entre copias, diff acotado a las diferencias declaradas y firma de
  hechos derivables. Si falla, no se distribuye.
