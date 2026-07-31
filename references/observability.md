# Observabilidad del flujo agéntico

Esto no audita el proyecto: audita a **los agentes mientras trabajan**. El director lo
usa para saber cuándo un agente se desvía, por qué falla, y para dejar rastro de cada
decisión, de modo que el sistema se corrija solo dentro de sus límites y se pueda
mejorar con el tiempo. Se apoya en el bucle de validación del `SKILL.md` y lo extiende.

## Tres piezas

### 1. Trazabilidad de decisiones (bitácora)

Cada decisión relevante de la corrida se registra en `.orchestrator/trace.md` como una
línea compacta: **quién** (agente), **qué** decidió, **por qué** (evidencia: ruta:línea
o cita oficial), **en qué fase**, y **resultado de validación** (pasó / reintento /
hueco). No es prosa: es un log append-only. Sirve para tres cosas —analizar la corrida,
retroalimentar al Aprendiz, y reconstruir cómo se llegó a un cambio si algo sale mal.

Regla: si una decisión no se puede trazar hasta su evidencia, no debió tomarse.

### 2. Sensores de falla (cuándo y por qué falla un agente)

El director vigila señales objetivas de que un agente se desvió, y registra la causa:

- **Sin evidencia**: afirma algo sin ruta:línea ni cita → falla de protocolo.
- **Fuera de alcance**: tocó o propuso algo que no estaba en su encargo.
- **Suposición**: usó "probablemente/asumo/suele" en vez de un [HUECO].
- **Autocomplacencia**: reportó "todo bien" sin pruebas, o hizo pasar un test
  debilitándolo.
- **Contradicción**: su salida choca con la de otro agente o con la memoria de proyecto.
- **Parche**: resolvió el síntoma, no la raíz.

Cada disparo se anota en la traza con el agente, la señal y la evidencia del desvío.

### 3. Feedback loop (corrección cuando se desvía)

Ante un sensor disparado, el director no avanza:

```
sensor dispara → señalar el desvío concreto al agente → reintentar UNA vez
   corrige  → continuar, anotando en la traza
   no corrige → registrar [HUECO], escalar a la persona, no consolidar esa salida
```

Un mismo agente que dispara el mismo sensor repetidamente es una señal de que su brief
o su modelo no encajan con la tarea: se reporta para revisión, no se insiste en bucle.

## Cierre del ciclo

Al terminar, la traza alimenta al **Aprendiz**: los desvíos recurrentes y sus causas se
destilan en mejoras a los briefs, al proceso o a la selección de modelo, y —si
generalizan— a la memoria global. Así el flujo agéntico mismo mejora corrida a corrida,
con evidencia, no por intuición.

## Límite

La observabilidad detecta y corrige desvíos **de proceso**; no reemplaza la compuerta
humana. Un agente "sano" según los sensores igual no aplica nada en producción sin
aprobación.
