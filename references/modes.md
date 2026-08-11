# Modos de operación

La auditoría es **un** modo, no el centro de la skill. El pedido de la persona
determina qué modo se activa, y el modo determina qué fases del modelo de ejecución
corren, qué capacidades se necesitan y qué nivel de riesgo asume la aplicación. Elegir
el modo es lo primero que hace el director tras leer el pedido (Fase 0), antes de
seleccionar equipo.

> **Principio.** No fuerces el pipeline completo de auditoría cuando el pedido es
> "diseña esto", "arregla este bug" o "documenta". Cada modo carga solo lo que su
> trabajo necesita. Correr las siete fases para un cambio trivial es gasto de tokens y
> un desvío que se anota en la traza.

## Cómo se elige el modo

1. Lee el pedido y clasifícalo contra la tabla de abajo. Un pedido puede combinar
   modos (p. ej. "migra y endurece"): encadénalos en el orden de dependencia, no los
   corras en paralelo.
2. Escribe el modo elegido y su justificación en `00-ficha-de-hechos.md`.
3. El modo fija tres cosas: **qué fases** del modelo de ejecución corren, **qué
   capacidades** entran al router (`routing.md` + `capability-registry.md`) y **qué
   nivel de riesgo** por defecto tiene la aplicación (`risk-levels.md`).

Ante la duda entre dos modos, elige el más acotado y escala si la incertidumbre lo
pide (`routing.md`, escalamiento por incertidumbre). No infles el modo "por si acaso".

## Catálogo de modos

| Modo | Cuándo | Fases que corren | Capacidades núcleo | Riesgo típico |
|---|---|---|---|---|
| **DISCOVER** | "¿Qué hace este proyecto?", primer contacto, mapear antes de decidir | R, 0 (+ mapa único) | Orquestador | R0 (solo lectura) |
| **ARCHITECT** | "Diseña la arquitectura", greenfield, decisión de diseño relevante | R, 0, decomposición → Arquitecto (+ especialistas por incertidumbre) → **ADR** → compuerta | Arquitecto, (Seguridad/BD si aplica) | R0 hasta ADR; sin código |
| **IMPLEMENT** | "Construye X", feature nueva sobre plan aprobado | 0, decomposición, aplicación acotada, verificación | según subtareas | R2–R3 |
| **REFACTOR** | "Limpia/reorganiza sin cambiar comportamiento" | 0, auditoría acotada, aplicación, verificación (comportamiento idéntico) | Arquitecto, Convenciones, QA | R2 (comportamiento invariante) |
| **DEBUG** | "Hay un bug", síntoma reportado | 0, reproducción → causa raíz → fix mínimo → test de regresión | según dominio del síntoma | R2–R3 |
| **MIGRATE** | "Pasa de A a B" (framework, motor, protocolo, auth) | 0, decomposición, estrategia expand-contract, aplicación por pasos, verificación + reversa | Arquitecto, BD/DevOps, Seguridad | R3–R4 |
| **AUDIT** | "Revisa/audita/¿está listo para producción?" | R, 0, 1 (paralela), 2, 2.5, 3 (Production Gate) — el pipeline completo de solo lectura | equipo condicional | R0 (no aplica nada) |
| **HARDEN** | "Asegura/blinda", cerrar hallazgos de seguridad/robustez | 0, auditoría de seguridad+robustez, aplicación, verificación anti-regresión | Seguridad, Robustez, Red Team | R3–R4 |
| **DOCUMENT** | "Documenta X" (automático al editar código) | Documentación | Documentación | R1 |
| **LEARN** | Cierre de sesión (automático) | Aprendiz → pipeline de promoción | Aprendiz | R1 (propone, no aplica) |

`AUDIT` es el modo que corre el modelo de ejecución completo descrito en `SKILL.md`;
los demás son subconjuntos. Todos comparten las leyes comunes: cero suposiciones
(`evidence-protocol.md`), compuerta antes de aplicar cambios con impacto
(`risk-levels.md`), y el conocimiento se ancla a versión (`knowledge-system.md`).

## Relación con las fases

Los modos no reemplazan las fases: las **seleccionan**. La Fase R (retroalimentación)
y la Fase 0 (intake) corren en casi todos porque sin contexto y sin las reglas ya
documentadas no se decide nada. Lo que varía es el cuerpo:

- Modos de solo lectura (`DISCOVER`, `AUDIT`) nunca reciben herramientas de escritura.
- Modos que aplican (`IMPLEMENT`, `REFACTOR`, `DEBUG`, `MIGRATE`, `HARDEN`) pasan por
  la compuerta con el nivel de riesgo que fija `risk-levels.md` — no todos exigen
  aprobación humana explícita, pero todos declaran su riesgo.
- `ARCHITECT` produce decisiones (ADR), no código: su entregable va al
  `decision-ledger.md`, no a `apply/`.

## Regla final

El modo es un contrato de alcance: dice qué se va a hacer y qué **no**. Un modo mal
elegido se corrige declarándolo, no ampliando el trabajo a escondidas. Si a mitad de
un modo aparece trabajo de otro modo, vuelve a la compuerta y decláralo — no cambies
de modo en silencio.
