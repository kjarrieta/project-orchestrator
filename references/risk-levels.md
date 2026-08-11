# Niveles de riesgo y aprobación

"Ningún cambio con impacto se aplica sin aprobación" sigue siendo la ley para lo que
tiene impacto. Pero tratar un `README` corregido igual que una migración destructiva
es fricción inútil que gasta la paciencia de la persona y empuja a saltarse la
compuerta. Este documento **gradúa** la aprobación por riesgo, sin abrir la puerta a
que algo peligroso pase sin ojos humanos.

> **Principio.** Automatiza el disparo, nunca la decisión de riesgo. Los niveles bajos
> ganan autonomía; los altos conservan la compuerta humana explícita e innegociable.

## La escala

| Nivel | Qué es | Ejemplos | Aprobación |
|---|---|---|---|
| **R0** | Solo lectura | auditar, mapear, explicar, medir, diseñar (ADR sin código) | Automática. No toca archivos. |
| **R1** | Cambios sin efecto en comportamiento | formato, comentarios, docs, nombres locales privados, agregar un test | Automática, pero **declarada** en la traza. |
| **R2** | Implementación local acotada | feature/fix dentro de un módulo, sin tocar contrato público, esquema ni seguridad | Aprobación **opcional**: se aplica en rama dedicada con commit atómico y se muestra el diff; la persona puede revertir. |
| **R3** | Comportamiento observable externo | contrato de API, esquema de BD, autorización, config de seguridad, dependencia nueva | Aprobación **requerida** antes de aplicar. Pasa por la compuerta con evidencia y reversa. |
| **R4** | Irreversible o de producción | migración destructiva, mutación de datos, borrado, cambio en producción, rotación de credenciales | Aprobación **explícita** e inequívoca, con plan de reversa aprobado. Nunca automática, nunca "asumida". |

## Cómo se asigna el nivel

1. El **modo** (`modes.md`) fija un riesgo por defecto, pero el nivel real lo determina
   el **cambio concreto**, no el modo. Un `REFACTOR` que toca una firma pública es R3,
   no R2.
2. Ante la duda entre dos niveles, **elige el más alto**. Subestimar el riesgo es el
   error caro; sobrestimarlo solo cuesta una confirmación.
3. Un cambio que combina niveles toma el **máximo**. Un fix R2 que además altera el
   esquema es R3 en su totalidad.
4. Los `hard_gate` y los boundaries críticos (seguridad, integridad financiera,
   aislamiento de tenant, concurrencia) son **siempre R3 o R4**, sin importar cuán
   pequeño parezca el diff. Un `hard_gate` abierto es NO-GO (ver `production-gate.md`).

## Interacción con la compuerta y el Production Gate

- Los niveles **no reemplazan** el Production Gate: lo alimentan. El gate sigue emitiendo
  GO/NO-GO por dimensión; los niveles solo gradúan cuánta ceremonia de aprobación exige
  aplicar cada cambio individual una vez que hay GO.
- R0/R1 no necesitan pasar por la compuerta humana para aplicarse, pero **sí** se
  registran (traza, `cambios.json`) — autonomía no es opacidad.
- R2 se aplica con diff visible y reversa trivial (revert del commit atómico); si la
  persona no lo quería, se revierte sin costo.
- R3/R4 **no se aplican** sin el veredicto humano. Aquí la ley original manda íntegra.

## Lo que este documento NO relaja

- La separación lectura/escritura por modo (agentes de diagnóstico sin herramientas de
  escritura) se mantiene: un nivel bajo no le da a un auditor permiso de escribir.
- El anti-regresión (Capas A–D) aplica a todos los niveles: bajar el baseline, correr
  el lint/test de cada regresión tocada, no depende del nivel de riesgo.
- La regla "lo nuevo descubierto vuelve a la compuerta": un R2 que destapa un problema
  R4 se detiene y escala, no se resuelve de más.

## Regla final

El objetivo es autonomía donde es segura y ceremonia donde importa. Un nivel mal
asignado se corrige subiéndolo, nunca bajándolo en silencio para evitar la compuerta.
Ante cualquier ambigüedad sobre si algo es reversible, es R4 hasta demostrar lo
contrario.
