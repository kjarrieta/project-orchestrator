# Registro de regresiones e invariantes (contrato exigible)

Este archivo define el **backbone de datos** de la defensa anti-regresión: el mecanismo
que hace que **un aprendizaje ya documentado no se pueda volver a violar en silencio**.
Sin él, la skill ingiere memoria al inicio (Retroalimentación) y la destila al final
(Aprendiz), pero nada **obliga** a respetarla al escribir código. Ese hueco es la causa
raíz de las regresiones: código nuevo reintroduce un bug ya resuelto porque el
invariante vivía como prosa *advisory* en un `.md`, no como un contrato que una máquina
verifica.

> Principio: un invariante conocido no se confía a la memoria de nadie. Se codifica
> como una entrada del registro y, sobre todo, **se materializa como una política
> ejecutable en el propio repositorio** (test de arquitectura o lint) que rompe el
> build. La prosa informa; el registro nombra; la política ejecutable obliga.

## El registro alimenta 4 capas de defensa (ver `anti-regression.md`)

El registro no se hace cumplir solo. Es la fuente única de la que se derivan las cuatro
capas de defensa en profundidad. Cada entrada apunta a su materialización:

- **Capa A — Política ejecutable (la pieza decisiva del "nunca más").** La `senal` de la
  entrada se materializa como un **test de arquitectura** (reglas estructurales) o una
  firma del comando **`policy:lint`** (regex que el test de arquitectura no expresa),
  cableados en `composer test` + pre-commit + CI. Así una regresión documentada **no
  puede mergear**, la escriba un humano, otro agente u otra herramienta.
- **Capa B — Production Readiness Gate** (`production-gate.md`): el gate lee el registro
  para sus `hard_gates` y para exigir el `test_regresion`.
- **Capa C — Surface de política por ruta** (`anti-regression.md`): índice ruta→reglas
  duras que se inyecta al tocar un módulo, y hook `PreToolUse` como guard temprano de lo
  que escribe Claude Code (complementario, no primario).
- **Capa D — Garantía de regresión**: una entrada solo cierra cuando su lección tiene un
  lint (Capa A) o un `test_regresion` que la prueba.

La ejecución **primaria** es Capa A (CI/pre-commit): es la única que atrapa a cualquier
autor. El hook `PreToolUse` (Capa C) es un guard temprano y conveniente, no la red final.

## Dónde vive

- `.orchestrator/project-memory/regression-ledger.md` — legible para la persona.
- `.orchestrator/project-memory/regression-ledger.json` — la forma que consultan el
  hook de escritura y la Fase 5. **Es la fuente de verdad para verificar.**

Es memoria de proyecto: se relee en cada corrida y persiste entre sesiones. Nunca
contiene secretos ni datos de cliente — solo patrones en abstracto y rutas de código.

## Qué entra en el registro

Dos clases de entrada, y **solo** estas:

1. **Regresión** — un bug que ya se corrigió al menos una vez. Existe para que el
   mismo defecto no vuelva. Nace de un hallazgo confirmado (QA, Seguridad, un incidente).
2. **Invariante duro** — una regla que el sistema debe cumplir siempre y cuya violación
   es de las que bloquean producción (ver `production-gate.md`): aislamiento de tenant,
   autorización en el punto de mutación, dinero como decimal, inmutabilidad de snapshot,
   transiciones de estado válidas, idempotencia de jobs, FK sin orfandad.

No entra: preferencias de estilo, mejoras opinables, TODOs. Eso vive en políticas o en
la memoria del Aprendiz, no aquí. El registro es corto a propósito: cada entrada cuesta
una verificación en cada escritura.

## Esquema de una entrada (`regression-ledger.json`)

```json
{
  "id": "REG-014",
  "clase": "regresion | invariante",
  "dominio": "autorizacion | tenant | dinero | estado | concurrencia | integridad | ...",
  "invariante": "Toda acción mutante Livewire autoriza en el punto de ejecución.",
  "origen": "P1 de la auditoría de Refi (2026-08) — BFLA en acción sin Policy",
  "evidencia": "app/Livewire/Commission/Edit.php:84",
  "severidad": "CRITICAL | HIGH | MEDIUM | LOW",
  "gate": "BLOCKING | NON-BLOCKING",
  "senal": {
    "tipo": "grep_prohibido | grep_requerido | test_requerido",
    "alcance_rutas": ["app/Livewire/**/*.php"],
    "patron": "->update\\(|->delete\\(|->save\\(",
    "requiere_ademas": "authorize\\(|Gate::authorize\\(",
    "nota": "Mutación en Livewire sin authorize() en el mismo componente = bloqueo."
  },
  "test_regresion": "CommissionAuthorizationTest::test_user_cannot_update_foreign_commission",
  "estado": "ACTIVO | RESUELTO_CON_TEST"
}
```

Notas del esquema:
- **`senal.tipo`** es lo que vuelve la entrada exigible por máquina:
  - `grep_prohibido` — el patrón NO debe aparecer en el diff (p. ej. `DB::table(` en Livewire).
  - `grep_requerido` — si aparece `patron`, entonces DEBE aparecer también
    `requiere_ademas` en el mismo archivo/cambio (p. ej. mutación ⇒ `authorize`).
  - `test_requerido` — el dominio no se da por bueno sin un test nombrado que lo pruebe.
- **`alcance_rutas`** acota a qué archivos aplica la entrada, para no verificar de más.
- **`test_regresion`** nombra la prueba que demuestra el invariante. Su ausencia es
  `UNVERIFIED`, no `PASS` (ver `production-gate.md`, "PASS requiere evidencia").
- **`gate`**: una entrada `BLOCKING` que se viola impide el GO, sin importar cuántos
  agentes hayan dicho PASS.

## Ciclo de vida

```
Hallazgo confirmado (QA/Seguridad/incidente)
        │  el Aprendiz lo promueve si es regresión o invariante duro
        ▼
Entrada en el registro (con señal de detección y test requerido)
        │
        ├──► Retroalimentación lo carga al inicio y entrega a cada agente su parcela
        ├──► Hook PreToolUse lo ejecuta ANTES de cada Edit/Write (bloqueo en escritura)
        └──► Fase 5 exige el test_regresion por cada invariante que el diff toca
```

- **Promoción (Aprendiz).** Al cerrar sesión, todo hallazgo `CONFIRMED` de clase
  seguridad, integridad de datos, aislamiento de tenant o concurrencia se promueve a
  entrada del registro con su señal y su test requerido. No es opcional: es el paso que
  cierra el ciclo para que el mismo bug no regrese. Ver `learner.md`.
- **Carga (Retroalimentación).** Es la primera memoria que se ingiere; se valida contra
  el código real (una entrada puede haber quedado obsoleta si el archivo cambió) y se
  entrega a cada auditor la parcela de su dominio. Ver `feedback.md`.
- **Cierre.** Una entrada pasa a `RESUELTO_CON_TEST` solo cuando existe y pasa su
  `test_regresion`. Nunca se borra una regresión: se conserva con su test como guardián.

## Cómo lo consume el hook de escritura

El hook `PreToolUse` (matcher `Edit|Write`, ver `automation-hooks.md`) lee por stdin el
JSON del evento —que incluye la ruta y el contenido/`new_string` propuesto—, filtra las
entradas cuyo `alcance_rutas` casa con la ruta editada, y evalúa su `senal`:

- `grep_prohibido` que casa → **bloquea** (exit 2) con el ID, el invariante y la
  corrección esperada.
- `grep_requerido` cuyo `patron` casa pero falta `requiere_ademas` → **bloquea**.
- Cualquier entrada del dominio tocado → **inyecta** al contexto los invariantes
  relevantes (aunque no bloquee), para que quien escribe los vea antes de decidir.

El bloqueo no es censura: el mensaje explica el invariante y cómo cumplirlo, y la
persona puede levantar el guard de forma explícita para un cambio concreto (nunca de
forma silenciosa). Falso positivo justificado ⇒ se documenta la excepción, no se apaga
el registro.

## Regla dura

Una entrada `BLOCKING` del registro que el diff viola es **NO-GO automático**. La
decisión de aceptar esa deuda es de la persona, con una frase explícita de aceptación de
riesgo — nunca del silencio de un informe que dice "nada bloquea". El registro existe
precisamente para que ese silencio sea imposible.
