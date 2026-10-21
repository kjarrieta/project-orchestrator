---
description: Investiga cómo implementar el manejo de archivos (subida, límites, proveedor de almacenamiento) — en proyectos propios ya construidos, en la doc oficial del proveedor y en buenas prácticas — y cierra por entrevista los parámetros de negocio que el proyecto activo no tenga definidos
---

# Investigar e implementar la política de manejo de archivos

Ejecuta esta investigación apoyándote en tres agentes de la skill `project-orchestrator`:
el de **Integraciones Externas y Archivos** (`references/integrations.md`, que fija el
criterio de seguridad y trae la política de negocio de manejo de archivos), el de
**Retroalimentación** (`references/feedback.md`, cómo descubrir memoria aprovechable) y el
**Aprendiz** (`references/learner.md`, a dónde promueve lo que generaliza). Localiza la
skill en `.agents/skills/project-orchestrator/`, `.claude/skills/project-orchestrator/` del
proyecto, o `~/.claude/skills/project-orchestrator/`, y lee esos archivos antes de operar.
No inventa ningún límite ni proveedor: los investiga y, si no hay estándar, los pregunta.

Argumento (ruta de un proyecto propio a inspeccionar, o el proveedor ya elegido si solo
falta afinar parámetros): $ARGUMENTS

## Por qué existe

`integrations.md` deja explícito qué es innegociable en seguridad de archivos (magic
bytes, renombrado con UUID, fuera del webroot) pero los **parámetros de negocio**
—¿parametrizable o fijo?, ¿cuántos archivos?, ¿qué extensiones?, ¿qué peso?, ¿qué
proveedor?— varían por proyecto. Sin este comando, esos parámetros se copian a ciegas de
memoria o de otro proyecto, que es exactamente el tipo de suposición sin evidencia que la
skill prohíbe.

## Procedimiento

1. **Barre proyectos propios ya construidos** (si se pasó una ruta, o los que aparezcan en
   `~/.claude/project-orchestrator/memory/guarded-projects.json` y en memoria global) con el
   mismo criterio de `/learn-from`: busca dónde configuran subida de archivos
   (`config/filesystems.php`, validadores de request/form, middlewares de tamaño,
   políticas de almacenamiento) y **extrae el patrón con evidencia `ruta:línea`**, nunca
   una impresión. Cada hallazgo lleva su procedencia (archivo + fecha).
2. **Consulta la documentación oficial vigente del proveedor** en uso o candidato (S3,
   Google Drive, Azure Blob, GCS, disco local, FTP/SFTP propio…): límites de tamaño por
   objeto, límites de tasa, política de nombres de clave, expiración de URLs firmadas.
   Cítala con versión/fecha — nunca de memoria. Si no hay acceso a red para consultarla,
   decláralo como hueco explícito; no se inventa un límite.
3. **Reúne buenas prácticas de programación** aplicables: OWASP File Upload Cheat Sheet y
   la sección "Manejo seguro de archivos subidos por usuarios" de `integrations.md`.
   Sepáralas en dos columnas: lo innegociable (seguridad) frente a lo que es decisión de
   negocio de este proyecto.
4. **Cierra cada decisión de negocio por entrevista**, nunca por defecto asumido. Si el
   proyecto activo ya tiene un estándar detectable (código, `CLAUDE.md`, ADR), preséntalo
   como propuesta a confirmar con su evidencia; si no lo tiene, pregunta explícitamente:
   - **¿Parametrizable o fijo?** — configurable en runtime/admin (por tenant, por tipo de
     documento) vs. constante fija en código/config, y por qué.
   - **Cantidad mínima y máxima** de archivos por carga (¿0 archivos es válido?, ¿tope
     duro o soft-limit con confirmación?).
   - **Extensiones permitidas** como allow-list explícita, y si varía por tipo de
     documento o módulo.
   - **Peso máximo y peso mínimo permitido** por archivo (y acumulado por carga, si
     aplica).
   - **Proveedor o servidor de carga**, con la razón de la elección y sus
     credenciales/mínimo privilegio ya resueltos según `integrations.md`.
5. **Registra la decisión como estándar del proyecto**, con procedencia completa (qué se
   investigó, qué se preguntó, quién respondió, cuándo). Se escribe en `CLAUDE.md`/`docs/`
   del proyecto activo. Si el patrón encontrado **generaliza más allá de este proyecto**
   (una regla de un proveedor, no una cifra de negocio de este cliente), se propone al
   Aprendiz para su pipeline de promoción (`learner.md`) — nunca se auto-promueve a
   memoria global.
6. **Compuerta**: presenta el resumen completo (qué se encontró en otros proyectos, qué
   dijo la doc oficial, qué se preguntó y qué se decidió) antes de dejarlo como estándar
   vigente del proyecto.

## Reglas

- Solo lectura sobre cualquier proyecto ajeno/propio inspeccionado: este comando nunca
  modifica el proyecto del que aprende.
- Cantidad, peso y extensiones son del dominio de negocio de **este** proyecto; nunca se
  asumen como convención universal solo porque otro proyecto los usó así.
- Optimiza tokens: barre con Glob/Grep dirigidos, no leas árboles completos; resume por
  archivo, no lo transcribas.
- Si la entrevista produjo una regla exigible (p. ej. tope de tamaño en validación de
  servidor), cierra con `/guard-sync --all`: la política nueva no bloquea nada hasta
  compilarse.
