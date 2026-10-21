---
description: Prepara las capacidades del proyecto (activa solo los plugins/agentes que su stack necesita) y define los agentes responsables por rol — agnóstico de proveedor
argument-hint: '[capacidades/plugins extra opcionales, ej. "postman figma"]'
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, PowerShell
---

# Configuración inicial del proyecto

Este comando prepara las **capacidades** (agentes/plugins) que el proyecto necesita y, con ellas, la **asignación de roles** de la corrida (arquitecto / aplicación / escritura). El objetivo es que el sistema funcione **con cualquier backend de agentes, sin importar la licencia** — Claude Code es la implementación concreta actual, no un requisito.

**Backend actual (Claude Code):** los plugins están desactivados globalmente para ahorrar tokens; cada proyecto activa solo los que necesita vía su `.claude/settings.json` (la precedencia proyecto > global lo permite). Detecta el stack del proyecto y genera esa configuración automáticamente. Si el entorno usa otro proveedor de agentes, omite los pasos de plugins y solo registra la asignación de roles (ver `references/setup.md`, Paso 1.5, `.orchestrator/agents.json`).

Argumentos del usuario (plugins o hints extra, puede estar vacío): $ARGUMENTS

## Paso 1 — Detectar el stack

Inspecciona la raíz del directorio de trabajo actual (NO `~`; si el directorio de trabajo es el home del usuario, detente y pide que abra Claude Code dentro de un proyecto). Busca estos marcadores:

| Marcador | Stack |
|---|---|
| `composer.json` con `laravel/framework` | Laravel / PHP |
| `app.json` o `app.config.*` con `expo`, o `expo` en `package.json` | Expo / React Native |
| `package.json` con `react`, `next`, `vue`, `svelte` (sin expo) | Frontend web |
| Migraciones, `prisma/schema.prisma`, `drizzle.config.*`, carpeta `database/`, docker-compose con postgres/mysql | Proyecto con base de datos |
| Colecciones Postman, carpeta `api/` con specs OpenAPI | APIs |
| `tailwind.config.*` o `@tailwindcss` en dependencias | Tailwind (no requiere plugin, la skill es global) |

Un proyecto puede tener varios stacks a la vez (ej. Laravel + Tailwind + DB).

## Paso 2 — Mapear stack → plugins

Lee `~/.claude/plugin-profiles.md` como fuente de verdad de los nombres exactos de plugins. Mapeo base:

- Laravel/PHP → `laravel-boost@claude-plugins-official`, `playwright@claude-plugins-official`
- Expo/React Native → `expo@claude-plugins-official`, `context7@claude-plugins-official`
- Frontend/diseño → `frontend-design@claude-plugins-official` (agrega `figma@claude-plugins-official` solo si el usuario lo pide)
- Auditoría de BD → `claude-db@claude-db` (solo si el proyecto tiene esquema/migraciones relevantes Y el usuario suele auditar; si hay duda, no lo actives y menciónalo)
- APIs/Analytics → `postman@claude-plugins-official`, `amplitude@claude-plugins-official` (solo con evidencia clara o si el usuario lo pide)
- TDD/planes → `superpowers@claude-plugins-official` (solo si el usuario lo pide)

Si el usuario pasó argumentos, inclúyelos aunque no haya marcadores. Sé conservador: el objetivo es ahorrar tokens; ante la duda, menos plugins y menciona los opcionales al final.

## Paso 3 — Generar la configuración

1. Si ya existe `.claude/settings.json` en el proyecto, léelo y FUSIONA (no sobrescribas claves existentes; solo agrega/actualiza `enabledPlugins`).
2. Si no existe, crea `.claude/settings.json` con solo el bloque `enabledPlugins` y los plugins detectados en `true`.
3. No toques `~/.claude/settings.json` global ni pongas plugins en `false` en el proyecto (ya lo están globalmente).

## Paso 4 — Asignar agentes por rol (agnóstico de proveedor)

Con las capacidades ya elegidas, registra en `.orchestrator/agents.json` qué agente cumple cada rol de la corrida — **arquitecto, aplicación/ejecución y escritura/documentación** — siguiendo `references/setup.md` (Paso 1.5). Por defecto son los subagentes de Claude Code; si hay otro proveedor, se nombran aquí. Ningún rol queda sin asignar antes de arrancar la Fase 1.

## Paso 5 — Reportar

Muestra al usuario:
- Stack(s) detectado(s) y la evidencia (archivos encontrados).
- Capacidades/plugins activados en el proyecto.
- Agentes asignados por rol (arquitecto / aplicación / escritura).
- Capacidades opcionales que NO activaste y por qué (ej. "claude-db disponible si vas a auditar la BD: agrégalo con `/setup-project claude-db`").
- Recordatorio (backend Claude Code): reiniciar Claude Code o ejecutar `/reload-plugins` para que apliquen.
