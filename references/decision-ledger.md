# Registro de decisiones (Decision Ledger / ADR)

El `regression-ledger.md` recuerda **bugs** que no deben volver. El decision-ledger
recuerda **decisiones** que no deben re-litigarse. Sin él, el equipo vuelve a proponer
mañana algo que se rechazó ayer, y gasta tokens re-razonando un camino ya cerrado.

Es la materialización de la clase **Memory** del `knowledge-system.md`: no "qué es el
proyecto" (eso son Facts), sino "por qué el proyecto es así".

## Qué registra

Toda decisión arquitectónica o de diseño con consecuencias — y, con igual importancia,
**las alternativas rechazadas y por qué**. Una memoria senior no recuerda solo lo que se
eligió; recuerda lo que se descartó, para no reabrir el ciclo.

```
ADR-001
Título:        Persistencia de metadatos de comisión
Estado:        Aceptada | Propuesta | Superada por ADR-0NN | Rechazada
Fecha:         2026-08-11
Contexto:      qué problema forzó la decisión (con evidencia ruta:línea / requisito)
Decisión:      qué se eligió — "Usar PostgreSQL JSONB para el bloque de metadatos"
Alternativas:  qué más se consideró
Why not:       por qué NO cada alternativa
  - Tabla EAV → consultas ilegibles, sin integridad de tipos
  - MongoDB    → añade un motor más que operar sin ganancia sobre JSONB para este volumen
Consecuencias: qué gana y qué cuesta esta decisión (operabilidad, lock-in, evolución)
Evidencia:     fuente(s) con nivel de jerarquía (knowledge-system.md) + doc oficial de versión
Riesgo:        nivel (risk-levels.md) si la decisión implica un cambio
```

## El campo "Why not" es obligatorio

Registrar solo "elegimos PostgreSQL" pierde la mitad del valor. Lo que evita ciclos de
razonamiento repetidos es "rechazamos MongoDB porque...". Cuando un agente futuro
proponga MongoDB, el orquestador lo intercepta con el ADR y su "why not" — la decisión
no se reabre salvo que cambie el contexto que la justificó.

Una alternativa sin "why not" no está evaluada, está ignorada: el ADR queda incompleto.

## Dónde vive

- Preferentemente en el propio repo del proyecto (`docs/adr/`), que es la convención
  estándar y viaja con el código. El agente de Documentación lo mantiene.
- Si el proyecto no tiene esa convención, en `.orchestrator/project-memory/decisions/`.
- El agente Aprendiz **propone** ADRs al cerrar sesión (ver `learner.md`); no los
  escribe sin compuerta. Una decisión arquitectónica es demasiado influyente para
  colarse sin aprobación.

## Cómo se consume

- **Al planificar (Fase 0 / modo ARCHITECT):** el director lee los ADR existentes antes
  de proponer diseño. Una propuesta que contradice un ADR Aceptado debe **citar el ADR y
  argumentar por qué el contexto cambió** — no puede ignorarlo.
- **En el modo ARCHITECT (`modes.md`):** el entregable no es código, es un ADR. Una
  decisión arquitectónica relevante exige el análisis de trade-offs completo (Opción
  A/B: pros, contras, coste, riesgo → Decisión → alternativas rechazadas). Ver
  `architect.md`.
- **Ante una propuesta repetida:** si alguien propone algo que un ADR ya rechazó, el
  orquestador responde con el ADR, no re-audita el camino cerrado.

## Relación con los otros registros

| Registro | Recuerda | Formato | Cierra con |
|---|---|---|---|
| `decision-ledger` | decisiones y descartes | ADR + "why not" | evidencia + trade-offs |
| `regression-ledger` | bugs que no deben volver | invariante + `test_required` | lint (Capa A) o test (Capa D) |

Un ADR no necesita test; un invariante sí. No los confundas: rechazar MongoDB es un ADR;
"no usar `catch(\Throwable)` que traga el error" es una regresión con lint.

## Regla final

Una decisión sin su "why not" registrado se vuelve a discutir. El decision-ledger es
barato de escribir y caro de no tener: cada ciclo de razonamiento repetido que evita
paga su costo muchas veces.
