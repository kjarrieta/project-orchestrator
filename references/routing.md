# Enrutamiento: de la tarea a los agentes

Este es el cerebro del orquestador. El catálogo de agentes **no** decide qué corre; lo
decide la tarea. La regla rectora de toda la skill:

> **La evidencia y la incertidumbre determinan qué agentes se necesitan, no el catálogo
> de agentes.** No agregues un agente porque existe; agrégalo porque hay incertidumbre
> no resuelta que solo esa capacidad resuelve.

El flujo es siempre el mismo, y precede a lanzar cualquier subagente:

```
Pedido → Descomponer en subtareas → Capacidades requeridas por subtarea
       → ¿Delegar reduce incertidumbre? → Seleccionar agente + modelo + herramientas
       → Ejecutar → Medir confianza → ¿Escalar?
```

## 1. Descomposición de la tarea

Antes de seleccionar agentes, parte el pedido en subtareas con sus dependencias. Sin
esto, activas agentes "por proyecto" en vez de "por subtarea", que es la fuente
principal de gasto.

Ejemplo — "Migra la autenticación de JWT a OAuth2":

```
1. Análisis del auth actual      (lectura)      → depende de nada
2. Modelo de amenazas            (seguridad)    → depende de 1
3. Contrato de API afectado      (APIs)         → depende de 1
4. Impacto en BD                 (BD)           → depende de 1
5. Estrategia de migración       (arquitectura) → depende de 2,3,4
6. Implementación                (aplicación)   → depende de 5 + compuerta
7. Tests                         (QA)           → depende de 6
8. Reversa                       (DevOps)       → depende de 5
```

De aquí salen: qué es paralelizable (1 solo; 2/3/4 en paralelo tras 1), qué capacidades
entran, y dónde está la compuerta. Los agentes se activan **por subtarea**, no por el
tamaño del proyecto.

## 2. Resolución de capacidades

Por cada subtarea, pregunta "¿qué capacidad la resuelve?" y consulta el
`capability-registry.md` para saber qué agente la provee. Piensa en capacidades, no en
nombres de agente: así el roster puede crecer sin cambiar esta lógica.

- "Cambiar una migración PostgreSQL" necesita: `database`, `migration-safety`,
  `testing`, `git`. **No** necesita: `frontend`, `seo`, `api`.
- "Corregir un bug de CSS" necesita: `frontend`, `browser`. **No** necesita:
  `database`, `security`, `devops`, `red-team`.

Una capacidad que ninguna subtarea usa no se activa. Un agente cuya capacidad no fue
requerida se omite **con justificación** en la ficha (la regla de "justifica los
omitidos" del `SKILL.md`).

## 3. Regla don't-delegate (eficiencia de tokens)

No todo merece un subagente. Antes de lanzar uno, el director se pregunta: **¿delegar
reduce de verdad la incertidumbre o el trabajo?** Si no, no delega.

```
Pregunta simple / hecho verificable   → el director responde, sin subagente.
Cambio trivial (1 archivo, R0–R1)     → el agente principal, sin equipo.
Cambio complejo o multi-dominio       → especialista(s).
Riesgo crítico (R3–R4)                → especialista + verificador independiente.
```

Lanzar un subagente cuesta un contexto entero. Un subagente que solo confirma lo que el
director ya sabe con evidencia es token quemado. La medida no es cuántos agentes
corren, sino cuánta incertidumbre resolvió cada uno.

## 4. Selección de modelo y herramientas

Cada agente recibe el **mínimo** modelo y el **mínimo** conjunto de herramientas que su
subtarea exige:

- **Modelo por coste del trabajo** (ya en `SKILL.md`): exploración → modelo medio; el
  modelo grande se reserva para consolidación, veredictos críticos y Red Team. Jamás
  todo el equipo en el modelo máximo. Los IDs concretos de modelo se nombran en un solo
  lugar (la ficha de la corrida), no dispersos por los briefs — así cambiar de modelo
  no toca los agentes.
- **Herramientas por subtarea (tool routing).** Un agente de solo diagnóstico recibe
  `Read, Grep, Glob` y nada más. Un agente de performance de PostgreSQL necesita
  `filesystem, git, psql, EXPLAIN ANALYZE`; **no** necesita `browser` ni herramientas
  de diseño. Cargar una herramienta que la subtarea no usa infla el contexto y amplía
  la superficie de error. El enrutamiento de herramientas sigue la misma lógica que el
  de agentes: por necesidad demostrada, no por defecto.

## 5. Confidence Gate y escalamiento por incertidumbre

La confianza no es solo por hallazgo (eso ya está en `evidence-protocol.md`): es
también una propiedad **global de la corrida**. Tras la primera pasada, el director
estima la confianza por dimensión y escala solo donde falta:

```
confidence:
  architecture: 0.91   → suficiente, no escalar
  security:     0.96   → suficiente
  performance:  0.54   → por debajo del umbral → lanzar especialista de performance
```

La regla:

```
Pregunta simple → 1 agente barato → confianza alta → STOP.
Zona con confianza < umbral → agregar la capacidad que la resuelve → re-medir.
```

Esto invierte el default peligroso ("para arquitectura, lanzar siempre 5 agentes") por
uno económico ("lanza 1; agrega agentes solo donde la confianza no alcanza"). El umbral
no es una fórmula rígida: es un criterio — un boundary crítico (seguridad, integridad,
tenant, concurrencia) exige confianza alta y escala agresivo; una preferencia estética
no escala nada.

Enlaza con el bucle de validación del `SKILL.md`: una salida que no pasa validación es
confianza baja por definición y dispara reintento acotado o [HUECO], nunca avance a
ciegas.

## Regla final

El orquestador es **evidence-first**, no **agent-first**. La secuencia correcta es:
tenemos una tarea → qué sabemos → qué desconocemos → qué evidencia falta → qué
capacidad resuelve esa incertidumbre → qué agente la posee → qué modelo basta. Nunca:
tenemos N agentes → ejecutémoslos.
