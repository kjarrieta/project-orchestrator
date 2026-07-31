# Instalación — project-orchestrator

Orquestador de proyectos de software para **Claude Code**: dirige **12 agentes senior**
(arquitectura, BD, APIs, seguridad, QA, frontend, documentación…) en fases de
**auditoría paralela de solo lectura → compuerta de aprobación humana → aplicación**.
Regla innegociable: **cero suposiciones** (evidencia `ruta:línea` + doc oficial) y
**nada con impacto se aplica sin tu aprobación**.

## Instalación

**Windows (PowerShell):**
```powershell
git clone https://github.com/kjarrieta/project-orchestrator "$HOME\.claude\skills\project-orchestrator"
Copy-Item "$HOME\.claude\skills\project-orchestrator\commands\*" "$HOME\.claude\commands\" -Force
# Reiniciá Claude Code
```

**macOS / Linux:**
```bash
git clone https://github.com/kjarrieta/project-orchestrator ~/.claude/skills/project-orchestrator
mkdir -p ~/.claude/commands && cp ~/.claude/skills/project-orchestrator/commands/* ~/.claude/commands/
# Reiniciá Claude Code
```

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

Este repo **no** incluye la memoria global de aprendizajes (`memory-snapshot/` está en
`.gitignore`): esa memoria es personal y puede contener referencias a proyectos propios.
La skill funciona sin ella — la Fase R simplemente no encuentra memorias previas que
ingerir y las va construyendo con tu uso.
