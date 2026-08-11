# Sistema de conocimiento

El conocimiento que gobierna las decisiones del equipo no es una sola cosa. Mezclar un
hecho del proyecto con una recomendación de framework y con una lección aprendida es la
fuente principal de conocimiento contaminado o caducado. Este documento separa las
cuatro clases, les pone procedencia y caducidad, y define la jerarquía de fuentes y el
enrutamiento por versión. Léelo junto con `evidence-protocol.md` (la ley de evidencia)
y `language-memory.md` (el almacén global por lenguaje).

## Las cuatro clases (no se mezclan)

```
FACTS      → lo que sabemos de ESTE proyecto        (verificado leyendo el repo)
KNOWLEDGE  → conocimiento técnico externo           (doc oficial, RFC, OWASP)
MEMORY     → decisiones previas de este proyecto     (por qué se hizo así)
LEARNINGS  → errores aprendidos                      (qué no repetir y por qué)
```

- **Facts** — `PHP 8.4`, `Laravel 12`, `PostgreSQL 17`, "el módulo de facturación usa
  Repository→Service". Vive en `00-ficha-de-hechos.md` y `project-memory/`. Se obtiene
  leyendo, nunca suponiendo.
- **Knowledge** — cómo se hace algo según la autoridad externa. Vive citado, no
  copiado: la afirmación se ancla a la fuente y a la versión. No es del proyecto; es del
  lenguaje/framework/estándar.
- **Memory** — decisiones que este proyecto ya tomó ("usamos Repository→Service",
  "rechazamos MongoDB por X"). Vive en `decision-ledger.md` y `project-memory/`.
- **Learnings** — patrones de fallo con causa raíz. Viven en el `regression-ledger.md`
  (invariantes duros) y en la memoria global por lenguaje (`language-memory.md`).

La prueba de fuego: si nombrar el proyecto cambia la afirmación, es Fact o Memory; si
sería idéntica en otro proyecto del mismo stack, es Knowledge; si nació de un tropiezo,
es Learning.

## Jerarquía de fuentes (Source Hierarchy)

"Doc oficial" es correcto pero insuficiente: hay grados. Cuando dos fuentes se
contradicen, gana la de nivel más bajo (más cercana a la verdad ejecutable).

```
L0  Código ejecutado / tests / runtime observado en ESTE proyecto
L1  Documentación oficial de la versión exacta
L2  RFC / especificación formal (W3C/WHATWG, WCAG, estándar SQL del motor, OWASP ASVS)
L3  Repositorio oficial / notas de versión / changelog
L4  Documentación mantenida por el vendor (no la de referencia de versión)
L5  Fuentes secundarias reputadas
L6  Comunidad (foros, blogs, tutoriales)
```

Reglas de uso por tipo de afirmación:

| Afirmación | Nivel exigido |
|---|---|
| Comportamiento de seguridad | L0–L2 preferente; nunca por debajo de L2 sin marca de riesgo |
| Comportamiento de framework/lenguaje | L1–L3 |
| Recomendación de arquitectura | evidencia (L0–L3) + razonamiento de ingeniería explícito |
| Cualquier cosa | **L6 jamás es canónico**: orienta para *buscar*, nunca respalda una decisión |

Esto extiende `evidence-protocol.md`: lo que ese documento llama "fuente oficial" son
los niveles L0–L3 de aquí. Un agente que cita comunidad (L6) como verdad arquitectónica
comete el mismo error que inventar.

## Version Intelligence (conocimiento anclado a versión)

El conocimiento de frameworks **caduca**. Lo que vale en Laravel 12 puede ser un error
en Laravel 10. Por eso el orquestador no busca "qué recomienda Laravel" sino "qué
recomienda Laravel **12.x**".

Al detectar el stack (Fase 0), construye la ficha de versiones exactas desde los
lockfiles:

```yaml
stack:
  language:   { name: php,        version: "8.4" }
  framework:  { name: laravel,    version: "12.x" }
  database:   { name: postgresql, version: "17" }
  runtime:    { name: ..., version: ... }
```

El **Knowledge Resolver** usa esa ficha para buscar solo conocimiento compatible con
esas versiones. Una versión no confirmada desde el lockfile es un `[HUECO]`, no una
suposición. Nunca se aplica la sintaxis de una versión que el proyecto no usa.

## Procedencia y caducidad de la memoria

"Nada ingerido se vuelve canónico sin compuerta" es correcto pero se queda corto. Cada
entrada de memoria/knowledge lleva metadatos que permiten invalidarla cuando el mundo
cambia:

```yaml
source:            # de dónde salió (con nivel de la jerarquía)
confidence:        # qué tan segura es
verified_at:       # cuándo se verificó por última vez
verified_against:  # contra qué versión exacta
scope:             # project | team | language | framework | general
version:           # rango de versiones donde es cierta
expires:           # cuándo debe re-verificarse (el conocimiento de framework caduca)
```

Ejemplo:

```yaml
fact: "Laravel soporta X de forma nativa"
source:           { type: official, level: L1, url: "..." }
verified_against: { framework: laravel, version: "12.20" }
scope: framework
expires: "2027-01-01"
```

Reglas:
- Una entrada **expirada** no se aplica a ciegas: se re-verifica contra la versión
  actual antes de usarse, o se marca `[HUECO]`.
- `verified_against` distinto de la versión del proyecto actual ⇒ re-verificar, no
  reutilizar.
- Sin `source` con nivel de jerarquía, la entrada no es canónica.

## Cómo encaja con lo existente

- `evidence-protocol.md` — la ley de evidencia por afirmación (OBSERVADO/RECOMENDADO/
  HUECO). Este documento le añade **grados de fuente** (L0–L6) y **caducidad**.
- `language-memory.md` — el almacén físico del conocimiento global por lenguaje/versión.
  Este documento define las **clases** (Facts/Knowledge/Memory/Learnings) y los
  **metadatos** que cada entrada de ese almacén debería llevar.
- `decision-ledger.md` — donde vive la clase **Memory** (decisiones + "why not").
- `regression-ledger.md` — donde viven los **Learnings** con firma de runtime.

## Regla final

Conocimiento sin procedencia, sin versión y sin fecha de caducidad no es conocimiento:
es una suposición con buena presentación. La disciplina que hace a la skill confiable no
es tener mucha memoria, sino tener memoria **validada, versionada, con alcance y con
fecha**.
