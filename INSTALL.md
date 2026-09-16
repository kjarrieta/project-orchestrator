# Instalación — project-orchestrator

Orquestador de proyectos de software (implementación actual sobre Claude Code, agnóstico
de proveedor): dirige un **equipo de agentes senior**
(arquitectura, BD, APIs, seguridad, QA, frontend, documentación…) en fases de
**auditoría paralela de solo lectura → compuerta de aprobación humana → aplicación**.
Regla innegociable: **cero suposiciones** (evidencia `ruta:línea` + doc oficial) y
**nada con impacto se aplica sin tu aprobación**.

## Instalación

**Windows (PowerShell):**
```powershell
git clone https://github.com/kjarrieta/project-orchestrator "$HOME\.claude\skills\project-orchestrator"
Copy-Item "$HOME\.claude\skills\project-orchestrator\commands\*.md" "$HOME\.claude\commands\" -Force
# Reiniciá Claude Code
```

**macOS / Linux:**
```bash
git clone https://github.com/kjarrieta/project-orchestrator ~/.claude/skills/project-orchestrator
mkdir -p ~/.claude/commands && cp ~/.claude/skills/project-orchestrator/commands/*.md ~/.claude/commands/
# Reiniciá Claude Code
```

### Otro backend de agentes (opencode)

Los comandos existen en **dos variantes** porque el procedimiento es agnóstico de
proveedor pero los mecanismos de activación no lo son: `commands/*.md` habla de plugins y
`.claude/settings.json`; `commands/opencode/*.md` habla de skills en `.agents/skills/` y
MCP en `.opencode/opencode.json`. **No las mezcles**: copiar la variante de Claude Code
sobre la de opencode rompe las rutas de activación.

```bash
mkdir -p ~/.config/opencode/commands
cp ~/.claude/skills/project-orchestrator/commands/opencode/*.md ~/.config/opencode/commands/
```

Lo que cambia entre variantes es solo el backend (plugins vs skills/MCP, y el frontmatter
propio de cada host). Las fases, las compuertas y la ley de cero suposiciones son idénticas:
al mejorar el procedimiento hay que portar el cambio a **ambas**.

## Uso

Abrí Claude Code **dentro de tu proyecto** y corré:

```
/orchestrator setup            # instala subagentes y propone hooks (primera vez)
/orchestrator auditar          # auditoría de solo lectura → plan (no toca nada)
/orchestrator                  # flujo completo hasta la compuerta de aprobación
```

Otros modos: `aplicar` (aplica el plan aprobado), `nuevo` (proyecto greenfield),
`verificar`, `estado`, `cerrar`. Detalle completo en `README.md` y `COMMANDS.md`.

> 💡 Empezá siempre por `/orchestrator auditar`: es de solo lectura y te muestra cómo
> razona antes de darle permiso de escritura.

## Actualizar a la última versión

```bash
git -C ~/.claude/skills/project-orchestrator pull
# Windows: git -C "$HOME\.claude\skills\project-orchestrator" pull
```

## Nota sobre la memoria

Este repo **no** incluye ninguna memoria de aprendizajes: la memoria global vive en el
ámbito de usuario de cada instalación (`memory-snapshot/` está en `.gitignore`) y no se
publica. La skill arranca sin ella — la Fase R simplemente no encuentra memorias previas
que ingerir y las va construyendo con tu uso.
