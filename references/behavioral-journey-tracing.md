# Behavioral Journey Tracing — método obligatorio de auditoría

Auditar artefactos no basta. Cada auditor de Fase 1 (auditoría paralela, solo lectura)
**debe** reconstruir el comportamiento del sistema tocado por el cambio, seguirlo por sus
boundaries y verificar coherencia extremo-a-extremo. Este protocolo es contractual, no
supletorio: es lo que separa un veredicto `PASS` legítimo de un falso negativo.

## Por qué existe

Post-mortem 2026-09-24: un auditor externo encontró 24 defectos en
`backend-sincronizador` que la corrida original marcó como `PASS`. Los 24 comparten un
método común — el externo siguió invariantes, contratos, estados y efectos a través de
sus boundaries; la corrida original siguió artefactos. Este protocolo codifica ese
método para que el mismo blind spot no se repita.

Los 24 hallazgos históricos y sus patrones generalizados están en
`references/cross-layer-seams.md` (pattern library). Aquí vive **el método**; allá vive
**la evidencia** que lo justifica.

## Principio operativo

> **Sigue el comportamiento, no el archivo.**
> Un artefacto localmente correcto puede participar en un defecto sistémico. Sólo puedes
> emitir `PASS` sobre una interacción cuando has verificado que las suposiciones de un
> extremo coinciden con las garantías del otro.

## 1. Derivar el conjunto de journeys — obligatorio antes de auditar

Un journey es una unidad de comportamiento observable: input → recorrido → resultado
persistido o expuesto. El conjunto no se inventa; se deriva del cambio bajo auditoría:

| Señal en el diff/MR | Journey a trazar |
|---|---|
| Campo nuevo persistido | write → read → API/UI/consumidor |
| Endpoint nuevo o modificado | request → authz → service → response → cliente |
| Transición de estado nueva | estado previo → guardas → efecto → estado final → efecto lateral |
| Constraint/CHECK/trigger de BD nuevo | UI → request → service → BD → presentación del error |
| Permiso nuevo o cambiado | menú/CTA → route middleware → policy → filtro de datos |
| Operación transaccional | happy path → cada punto de fallo → estado remanente |
| Upload/side effect externo | intent → sesión/ledger → efecto externo → confirmación → fallo → limpieza |
| Job/cola nueva | despacho → ejecución → reintento → duplicación → idempotencia |
| Migración | expand → deploy → contract; reversibilidad |
| Cambio en identificador que cruza cliente↔servidor | productor JS → validador servidor → consumidor de storage |

Si el diff no produce ningún journey por estas señales, el auditor debe declararlo
explícitamente (`JOURNEYS DERIVED: NONE — <justificación>`); no puede simplemente omitir
la sección.

## 2. Los 10 patrones cognitivos

Aplica el patrón cuya pregunta encaja al journey. La pregunta va primero; el artefacto
es su instrumento.

- **A. Contract mismatch.** *¿El valor que produce A satisface el contrato que consume
  B?* Cliente↔servidor, request↔service, service↔repository, DB↔resource. Un productor
  válido + consumidor válido + boundary desalineada = defecto.
- **B. Invariant propagation.** *¿Dónde se define este invariante y dónde se hace
  cumplir?* Si sólo se aplica en la capa más profunda, el usuario recibe un error
  genérico en vez de validación accionable arriba.
- **C. Distributed atomicity.** *Si el paso N tiene éxito y N+1 falla, ¿qué queda
  cambiado?* Toda operación que toca DB + FS/S3 + queue + browser + external API tiene
  que responderla. La transacción SQL sólo protege la DB.
- **D. Failure-path tracing.** *Además del happy path, ¿qué le pasa al estado en cada
  punto de fallo?* Incluye recovery que restaura demasiado (sobrescribe input reciente
  no persistido) o demasiado poco (deja estado huérfano).
- **E. Read-after-write continuity.** *¿Quién consume el dato que acabamos de
  introducir/modificar?* Un campo escrito correctamente pero nunca consumido —o
  consumido por su predecesor— es un defecto.
- **F. Authorization symmetry.** *¿El permiso que controla la visibilidad es el mismo
  que controla el acceso efectivo?* Menú, ruta, policy, filtro de datos: mismo capability
  boundary o diferencia explícita.
- **G. Mechanism presence vs coverage.** *¿Qué operación protege realmente este lock /
  esta transacción / esta idempotencia?* `lockForUpdate` sin `DB::transaction` no cubre
  el read-modify-write; `catch(\Throwable)` no acumula = éxito reportado sobre fallo.
- **H. State-machine completeness.** *¿Están todas las transiciones representadas
  coherentemente en UI, service, constraint y efecto lateral?* CHECK que prohíbe una
  combinación mientras la UI la ofrece = QueryException al usuario.
- **I. Sibling consistency.** *¿Existe otro código que resuelve el mismo problema con
  reglas distintas?* Filtros hermanos que sí resetean paginación y uno que no; utils
  hermanas con validaciones desalineadas; recursos hermanos con distinta autorización.
- **J. Change vs ecosystem.** *¿La infraestructura acompaña el uso previsto del cambio?*
  Columna nueva usada para filtrar/ordenar sin índice; enum nuevo sin migración de datos;
  evento nuevo sin consumidor; feature flag sin telemetría.

## 3. Salida obligatoria del auditor

Antes de emitir cualquier finding, el auditor produce esta declaración (parte de su
evidencia, no opcional):

```
JOURNEYS DERIVED
J1 <nombre corto> — <señal del diff que lo originó>
J2 …

JOURNEYS TRACED
J1  artefactos recorridos: A → B → C → D
J2  artefactos recorridos: …

COVERAGE
J1  COMPLETE | PARTIAL — <artefacto que faltó> | UNVERIFIED — <razón>
J2  …

PATTERNS APPLIED
J1  A, D
J2  F
…
```

- `COMPLETE` sólo si se leyeron efectivamente todos los artefactos participantes.
- `PARTIAL` si faltó al menos uno accesible (el auditor debe justificar por qué no lo leyó).
- `UNVERIFIED` si al menos un artefacto participante no era accesible o requería runtime
  (llamada a MCP en vivo, log de producción, respuesta de terceros).

## 4. Veredictos

Este protocolo NO define veredictos propios. Reusa la escala de confianza ya establecida
en `references/evidence-protocol.md` (`CONFIRMED | LIKELY | UNVERIFIED | DESIGN-DEBT |
OBSERVATION`) y su tratamiento en la compuerta descrito en
`references/production-gate.md`.

Lo que este protocolo añade es un **trigger nuevo** para `UNVERIFIED`:

> **Journey no recorrido completo ⇒ `UNVERIFIED`.** Cuando `COVERAGE` de un journey no
> es `COMPLETE` — porque el auditor no leyó todos los artefactos participantes, o porque
> un artefacto requiere runtime que Fase 1 no tiene — el veredicto sobre ese journey es
> `UNVERIFIED`, nunca `PASS`. El Orquestador puede disparar inspección dirigida (Fase
> 1.5) o dejarlo para la Meta-auditoría/Red Team; en la compuerta se comporta como
> `UNVERIFIED` de cualquier otro origen (bloqueante hasta cerrar, salvo excepción
> documentada).

Esto convierte el falso negativo silencioso ("no vi nada malo en `Stepper.php`") en un
`UNVERIFIED` explícito ("no tracé el journey `Publish rental` completo — faltó
`RentalPublishRequirementsValidator`"). La honestidad de la salida sube; la escala de
confianza no cambia.

## 5. Regla de deslinde (evitar duplicación entre auditores)

Cuando dos auditores tracen el mismo journey desde extremos distintos, ambos van a ver
el seam. La regla:

1. Cada auditor reporta el finding con la etiqueta `seam-candidate:<slug>` en vez de
   `FINDING` cuando el defecto vive en la unión, no en su lado.
2. La Meta-auditoría/Red Team (`references/red-team.md`) consolida los `seam-candidate`
   con el mismo slug en un único finding canónico que cite evidencia de ambos lados.
3. El auditor que detecta el seam desde su lado mantiene la evidencia parcial en su
   reporte; no se le exige cerrar el otro lado — sí se le exige nombrarlo con precisión
   (ruta:línea del artefacto contraparte que sospecha).

Un seam sin cerrar en Fase 2 (consolidación) queda como `FINDING` a la compuerta.

## 6. Anti-scope

- No convertir este protocolo en un check-de-cajas por artefacto. La pregunta es la
  primera línea de defensa; los ejemplos son ilustrativos, no exhaustivos.
- No proponer fixes durante Fase 1 (sigue siendo solo lectura). Los fixes cruzan la
  compuerta humana como cualquier cambio R2+.
- No inventar journeys que el diff no toca. Auditar es responsivo al cambio, no
  exploración libre del repositorio.
- No delegar este protocolo a un agente único (ej. "cross-layer auditor"). Todos los
  auditores de Fase 1 lo aplican dentro de su dominio; centralizarlo recrea el mismo
  blind spot para todo journey fuera del scope de ese agente.

## 7. Evolución

Cuando un post-mortem identifique una clase de defecto que no encaje en ninguno de los
10 patrones, se añade como patrón K y se actualiza `cross-layer-seams.md` con la
evidencia. Editar aquí es raro; editar la pattern library es esperable.
