---
description: Ingiere documentación de políticas entregada por la empresa al corpus normativo del orquestador — anexa con procedencia, nunca sobrescribe
argument-hint: "<ruta del documento o carpeta> [--dominio <dominio>]"
---

# Actualizar las políticas de la empresa

Carga documentación normativa entregada por la empresa al **corpus de políticas** que el
agente de Cumplimiento Corporativo consulta en la Fase 6. Lee primero
`~/.claude/skills/project-orchestrator/references/policy-compliance.md`: define el esquema
de entrada, los niveles de exigencia y cómo se usa cada campo.

Argumento (ruta del documento, carpeta, o `revisar` para auditar el corpus sin cargar
nada): $ARGUMENTS

## Esto NO es `/learn-from`

La distinción es el punto entero del comando y no se puede difuminar:

| | `/learn-from` | `/policy-update` |
|---|---|---|
| Qué ingiere | Aprendizaje técnico observado | Norma corporativa entregada |
| Estatus | **Evidencia**: se discute, se valida contra el código | **Autoridad**: se acata, no se valida contra el código |
| Al contradecir | Se marca `[HUECO]` con ambas fuentes | La norma manda; el conflicto se escala |
| Destino | `memory/<lenguaje>/`, `memory/global/` | `memory/company-policies/` |
| Se deduplica | Sí, contra la memoria existente | **No.** Se versiona y se supersede |

Nunca mezcles los dos corpus. Una práctica técnica ascendida a "política de empresa" sin
documento de la empresa detrás es una norma inventada.

## Dónde vive el corpus

```
~/.claude/project-orchestrator/memory/company-policies/
├── index.md          índice de todas las entradas
├── <dominio>.md      seguridad.md, datos.md, desarrollo.md, operaciones.md, legal.md, …
└── source/           el documento original, tal cual llegó, sin editar
```

Repositorio **privado** (`project-orchestrator-memory`). El contenido es confidencial de la
empresa: no se replica al repo público de la skill, no se cita fuera de `.orchestrator/` del
proyecto, y `source/` conserva los documentos íntegros para poder auditar la procedencia.

## Procedimiento

1. **Inventaría** lo que se entregó: archivos, formato, fecha, versión declarada y quién lo
   emitió. Si el documento no dice versión ni fecha, anótalo como `[HUECO]` — una norma sin
   fecha no se puede superseder después.

2. **Copia el original a `source/`** antes de tocar nada, con nombre
   `<AAAA-MM-DD>-<slug>.<ext>`. El original nunca se edita ni se resume en su sitio: es la
   procedencia. Si es un formato que no se puede versionar en texto (PDF, DOCX), guárdalo
   igual y deja junto a él un `.md` con el texto extraído.

3. **Normaliza a entradas.** Cada política discreta del documento se convierte en una
   entrada con este esquema:

   ```markdown
   ### EMP-<DOMINIO>-<NN> — <título corto>

   - **Nivel:** OBLIGATORIA | RECOMENDADA | INFORMATIVA
   - **Ámbito:** a qué aplica (todos los proyectos | un stack | un tipo de dato | un cliente)
   - **Estado:** VIGENTE | SUPERSEDIDA por <ID> | DEROGADA (<fecha>)
   - **Procedencia:** `source/<archivo>` §<sección>, emitido <fecha> por <área>
   - **Verificable como:** qué evidencia concreta demuestra cumplimiento (un lint, un test,
     una cláusula en un contrato de API, una configuración). `[HUECO]` si la norma no es
     verificable — es información útil, no un defecto que debas rellenar.

   > Texto literal de la norma, citado sin parafrasear.

   Notas de interpretación (opcional, claramente separadas del texto literal).
   ```

   **El texto de la norma va literal.** Parafrasear una política es alterarla. Tu redacción
   solo aparece bajo «Notas de interpretación» y marcada como tal.

4. **Anexa, jamás sobrescribas.** Una política nueva que reemplaza a una vieja **no borra la
   vieja**: la vieja pasa a `Estado: SUPERSEDIDA por <ID nuevo>` y se queda. El histórico
   normativo es lo que permite explicar por qué una decisión pasada fue correcta en su
   momento. Nada se elimina del corpus; se deroga.

5. **Detecta choques dentro del corpus.** Si la entrada nueva contradice una vigente, no
   elijas tú: marca ambas y preséntalo. Dos normas vigentes contradictorias son un problema
   de la empresa, no un problema de redacción que debas arreglar.

6. **Actualiza `index.md`** con una línea por entrada:

   ```
   | ID | Dominio | Nivel | Estado | Ámbito | Procedencia | Actualizada |
   ```

   y sella arriba la fecha de última actualización (la lee el agente de Cumplimiento para
   reportar `corpus_version`).

7. **Compuerta.** Presenta el resumen —qué entradas se crearon, cuáles se supersedieron, qué
   choques aparecieron, qué quedó `[HUECO]`— y escribe **solo tras el visto bueno**. Una
   política mal cargada se convierte en `NO-GO` en todos los proyectos.

8. **Commitea en el repo privado:**

   ```bash
   git -C ~/.claude/project-orchestrator/memory add -A company-policies
   git -C ~/.claude/project-orchestrator/memory commit -m "policies: <qué se cargó>"
   git -C ~/.claude/project-orchestrator/memory push
   ```

## Modo `revisar`

Con `revisar` como argumento no carga nada: audita el corpus existente y reporta entradas
sin nivel declarado, sin procedencia, sin fecha, contradicciones entre vigentes, entradas
`SUPERSEDIDA` sin sucesora existente, y políticas cuyo `Verificable como` sigue en `[HUECO]`.

## Reglas

- **Nunca inventes una política.** Si el documento es ambiguo, la entrada se crea con el
  texto literal y la ambigüedad anotada como `[HUECO]`, no resuelta.
- **Nunca subas de nivel por tu cuenta.** Si el documento no dice que algo es obligatorio,
  no es obligatorio. `RECOMENDADA` es el default de lo no clasificado.
- **Nunca cruces al corpus técnico.** Ni en un sentido ni en el otro: `/learn-from` no
  escribe en `company-policies/`, y este comando no escribe en `memory/<lenguaje>/`.
- **Secretos fuera.** Si el documento entregado trae credenciales, endpoints internos o
  datos personales, no entran al corpus: se anota que existen en el original y se recorta.
  `source/` es privado, pero no es un almacén de secretos.
