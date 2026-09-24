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
- **Veredicto no declarado**: entregó informe pero su `veredicto.json` falta, o
  `status`/`alcance_respetado`/`evidencia_chequeada` no se sostienen contra el `.md`.
- **Alcance no declarado**: un archivo en `git status` que no figura en el
  `cambios.json` del agente de APLICACIÓN.
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

Al reintentar, inyecta al agente su informe/veredicto previos y lo ya confirmado como
**contexto histórico, no ground truth**: apunta al defecto sin obligarlo a re-explorar
lo cubierto (mismo principio que el digest determinista: la evidencia previa viaja, no
se re-descubre).

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

## Un cambio no explicado en el repo no es evidencia de corrupción — es evidencia de que alguien más está trabajando ahí

En un proyecto donde el director no tiene visibilidad total (repo compartido, terminal
compartida, otra sesión del mismo orquestador corriendo en paralelo sobre la misma rama),
un archivo que aparece modificado sin que el propio director lo haya editado **no se
revierte ni se ignora por default**. La respuesta correcta es verificar cada cambio contra
el código/comportamiento real (releer el diff completo, confirmar cada afirmación contra
la fuente de verdad correspondiente — un enum de base de datos, una migración, un test
que pase) antes de commitear, descartar o dar por bueno el cambio.

**Por qué:** revertir a ciegas destruye trabajo válido de otra sesión; asumir que es
"ruido del editor" y commitear sin revisar arriesga meter un cambio no verificado al
historial. Ninguna de las dos reacciones automáticas es segura — la única que lo es es
tratar el cambio ajeno con el mismo rigor de evidencia que un hallazgo propio (ver
`evidence-protocol.md`).

**Señal de que esto está pasando:** varios archivos en dominios relacionados cambian entre
turnos sin que el director los haya tocado; los cambios, al revisarlos, resultan
coherentes y bien formados (no truncados ni a medio escribir) — eso es más indicio de otra
sesión trabajando que de una corrupción de archivo.

**Procedencia:** proyecto un proyecto cliente, 2026-09-16/17 (sesión
`aprendizaje2`) — durante una sesión manual de 18 fixes, aparecieron repetidas veces
ediciones no explicadas en archivos que el director no había tocado (dos métodos
eliminados en un service, una corrección de columna ya aplicada, un refactor completo de
validación con `FormRequest` en 6 archivos). Cada una se verificó contra el código real
(incluido un enum de base de datos contra su migración) antes de integrarla; ninguna se
revirtió. Al cerrar la sesión se confirmó la causa: otra corrida de este mismo
orquestador auditaba y aplicaba fixes sobre la misma rama en paralelo, en otra
sesión/ventana (ver aprendizaje 25 y 30 en `90-aprendizajes.md` del proyecto).
