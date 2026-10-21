# Aprender de una auditoría externa (meta-aprendizaje de cobertura)

Método que ejecuta `/learn-from-audit`. La entrada es uno o varios `.md` con hallazgos,
observaciones o fixes que **un agente externo** encontró en un proyecto que la skill ya
auditó (o pudo auditar). El objetivo **no** es aplicar esos fixes ni copiarlos como checks:

> Si un agente externo detectó una clase de problema, la skill debe aprender **qué patrón
> de razonamiento, qué evidencia y qué recorrido** lo revelaron, para detectar esa misma
> clase de forma autónoma en proyectos futuros — aunque el bug concreto sea otro.

Cada hallazgo externo es la señal de una **brecha de cobertura de nuestra propia
metodología de auditoría**, no un parche pendiente. Esto es la versión repetible del
post-mortem 2026-09-24 que produjo `behavioral-journey-tracing.md` (el método) y
`cross-layer-seams.md` (la evidencia). Todo lo que este proceso aprenda alimenta esos dos
archivos, el `regression-ledger` y la memoria por lenguaje/universal — nunca los
sobrescribe (P-NO-CLOBBER: leer completo y anexar).

## Anti-objetivo

No produzcas `Fix #1 → check #1; Fix #2 → check #2`. Eso convierte la skill en una
colección creciente de parches. Produce, por hallazgo, la cadena:

```
hallazgo externo → ¿qué permitió descubrirlo? → patrón de fallo →
¿por qué nuestra skill no lo vio? → brecha metodológica →
nueva capacidad → owner + seam → regla generalizable →
evidencia PASS/FAIL → regresión → knowledge base permanente
```

## 1 · Por cada hallazgo: reconstruye el descubrimiento

No aceptes "la corrida anterior no lo revisó". Reconstruye la cadena que siguió el externo
y nómbrala con evidencia (`ruta:línea` del `.md` y, cuando el proyecto esté accesible, del
código real — cero suposiciones, `evidence-protocol.md`):

```
entrada → hipótesis → trazabilidad → evidencia → contradicción → hallazgo → fix → validación
```

- **entrada**: qué información tenía el auditor.
- **hipótesis**: qué pregunta de auditoría lo llevó ahí.
- **trazabilidad**: qué archivos, clases, endpoints, tablas, eventos, jobs, configs tuvo
  que **correlacionar** (no qué archivo miró: qué relación siguió).
- **contradicción**: qué comportamiento real rompió el contrato esperado.
- **fix / validación**: qué cambió y cómo se demostró que quedó resuelto.

## 2 · Clasifica la brecha metodológica (obligatorio)

Por qué **nuestra** skill no lo detectó. Usa esta taxonomía; crea una categoría nueva si
la evidencia lo exige:

`scope` (fuera de alcance) · `traversal` (en alcance, no se recorrió entero) ·
`cross-layer` (requería correlacionar capas) · `cross-artifact` (comparar artefactos
distintos) · `contract` (no se verificó el contrato extremo-a-extremo) · `negative-path`
(solo happy path) · `state` (no se analizaron transiciones) · `failure-mode` (no se vieron
fallos parciales) · `persistence` (no se comprobó el efecto real en persistencia) ·
`integration` · `evidence` (conclusión sin evidencia suficiente) · `heuristic` (faltaba la
heurística para la clase) · `validation` (se detectaba pero no se podía demostrar) ·
`regression` (sin protección contra reaparición) · `ownership` (ningún agente/fase era
dueño del seam) · `duplication` (varios podían verlo sin regla de ownership) ·
`assumption` (se asumió cierta una condición sin verificarla) · `tooling` (la evidencia
estaba disponible pero la metodología no la usó).

## 3 · Aprende el recorrido, no el hallazgo

Identifica el **journey completo** que el externo tuvo que atravesar (método en
`behavioral-journey-tracing.md`). Si el defecto solo aparece recorriendo
`UI → API → Service → DB → Event → Job → sistema externo → estado persistido → UI`, la
auditoría futura debe incorporar ese recorrido como obligatorio — no basta con
`Controller → Service`. Un journey que el externo **validó como correcto** también es
conocimiento: registra qué recorrió y qué invariante demostró, para no perder cobertura
existente al añadir la nueva.

## 4 · Abstrae a regla generalizable

Por cada patrón, una regla reutilizable. Rechaza la regla pegada al caso
(❌ "verificar que `foo()` llame a `bar()`") a favor de la que describe el fenómeno
(✅ "cuando un flujo depende de una operación obligatoria downstream, verificar el
contrato completo productor↔consumidor: existencia, propagación de estado, manejo de
error, persistencia del resultado y comportamiento ante fallo parcial"). Cada regla lleva:

`id` estable · `nombre` corto del patrón · `intención` (riesgo que detecta) ·
`cuándo aplicar` (tipo de flujo/arquitectura) · `pregunta de auditoría` ·
`evidencia requerida` · `trazabilidad` (componentes a seguir) ·
`condición de fallo` (qué convierte la observación en hallazgo) ·
`casos positivos` y `casos negativos` (qué NO marcar) · `severidad` (por evidencia) ·
`validación` (cómo confirmar que es real) · `prevención` · `regresión`.

Agrupa hallazgos que comparten causa en un solo patrón; no fusiones problemas distintos
solo para reducir el número de reglas.

## 5 · Convierte el patrón en capacidad de la skill

Por cada aprendizaje, di **concretamente qué cambia en la metodología** y dónde:

- **fase** afectada (R/0/1/2/2.5/4/5/6) y **agente owner** de detectarlo
  (`capability-registry.md`).
- **seam** que debe verificarse y su regla de ownership: **quién detecta, quién aporta
  evidencia, quién consolida, cómo se evita el doble reporte, qué lo pone PASS y qué FAIL**.
  Un contrato roto que el auditor de BD y el de Frontend pueden ver por igual necesita
  owner, no un "ambos lo revisan".
- **evidencia mínima** para emitir PASS y criterio FAIL explícito.
- necesidad de **escalamiento** y riesgo de **duplicación** con otros agentes.

## 6 · Busca variantes no identificadas

Los fixes son evidencia, no verdad. Con cada patrón haz una búsqueda **conceptual**, no
literal: la pregunta es "¿dónde más puede existir este patrón?", no "¿dónde más aparece
este bug exacto?". Verifica además si cada fix ataca la causa raíz, si deja variantes
abiertas, si introduce efectos secundarios o rompe otro flujo. Sin evidencia suficiente,
marca `[HUECO]`; no inventes validaciones que el `.md` no trae.

## 7 · Prueba de transferencia

Imagina un proyecto distinto (otro framework, otros nombres). Pregunta: "¿la skill
detectaría esta clase de problema aunque todo el andamiaje fuera diferente?". Si la
respuesta es NO, la regla sigue pegada al caso: generalízala hasta que describa el
fenómeno. Demuestra la transferencia con un ejemplo hipotético por patrón.

## 8 · No degrades la cobertura existente (crítico)

Al incorporar controles nuevos, **no elimines ni simplifiques los existentes** solo porque
aparezcan reglas nuevas. Compara `cobertura actual + cobertura aprendida = cobertura
futura` y nombra cualquier control que una regla nueva pudiera afectar; si una regla
reemplaza a otra, demuestra por qué la cobertura no baja.

## Entregable

Un solo documento propuesta (bajo compuerta humana, nada se aplica sin aprobación),
en este orden:

1. Resumen ejecutivo — qué aprendimos de la auditoría externa.
2. Hallazgos analizados — problema · evidencia · flujo · causa · fix · validación.
3. Brechas de la skill — la clasificación del punto 2, por hallazgo.
4. Patrones generalizados.
5. Nuevas reglas de auditoría (esquema del punto 4).
6. Nuevos recorridos obligatorios (journeys).
7. Auditoría transversal — seams, owners, reglas de consolidación.
8. Matriz de cobertura — anterior vs nueva:
   `| patrón | hallazgo | ¿la skill lo detectaba? | brecha | regla nueva | owner | seam | evidencia | regresión |`
9. Matriz de no-regresión — `| riesgo | regla | dónde se valida | evidencia | qué impide la reaparición |`.
10. Riesgos similares aún no auditados (variantes del punto 6).
11. Cambios propuestos a la skill — nuevos principios / checks / recorridos / seams /
    owners / evidencias obligatorias / regresiones / criterios de escalamiento.
12. Knowledge base reutilizable.
13. Prueba de transferencia (punto 7).
14. Checklist de aprendizaje (abstraje el patrón; identifiqué la brecha; conservé la
    cobertura existente; definí owner, evidencia, PASS/FAIL y regresión; busqué variantes;
    evité reglas específicas del caso).

## Dónde aterriza cada aprendizaje (solo tras la compuerta)

Aprobado el documento, cada pieza va a su destino **anexando, nunca sobrescribiendo**
(leer el archivo completo primero — P-NO-CLOBBER):

- **Seed patterns nuevos** → `references/cross-layer-seams.md` (biblioteca de evidencia),
  nombrados por la pregunta cognitiva, con la evidencia que los originó.
- **Cambios al método** (nuevo recorrido/seam obligatorio) → `references/behavioral-journey-tracing.md`.
- **Invariantes con señal de runtime** (seguridad, integridad, tenant, concurrencia) →
  entrada en `regression-ledger` con su bloque ` ```senal ``` ` (esquema en
  `references/regression-ledger.md`). Lo que no tenga firma clara queda como prosa y como
  hueco de exigibilidad declarado — no inventes una regex para aparentar cobertura.
- **Cierto del lenguaje/framework** → memoria por lenguaje acotada a versión;
  **universal** → `memory/global/`. Reglas de nivel y fusión en `references/feedback.md` y
  `references/language-memory.md`.
- **Aprendizajes recurrentes que merecerían norma** → se **proponen** como candidatas a
  política (el alta solo por `/policy-update`, con documento de la empresa detrás).
- **Recompila**: `/guard-sync --all`. Anexar conocimiento no lo hace exigible; compilarlo
  sí. Hasta recompilar, lo aprendido no detiene ninguna escritura en ningún proyecto.
