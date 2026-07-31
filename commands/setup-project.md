---
description: Genera la configuración inicial del proyecto (.claude/settings.json) activando solo los plugins que su stack necesita
argument-hint: [plugins extra opcionales, ej. "postman figma"]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, PowerShell
---

# Configuración inicial del proyecto

Los plugins de Claude Code están desactivados globalmente para ahorrar tokens; cada proyecto debe activar solo los que necesita vía su `.claude/settings.json` (la precedencia proyecto > global lo permite). Tu tarea es detectar el stack del proyecto actual y generar esa configuración automáticamente.

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

## Paso 4 — Reportar

Muestra al usuario:
- Stack(s) detectado(s) y la evidencia (archivos encontrados).
- Plugins activados en el proyecto.
- Plugins opcionales que NO activaste y por qué (ej. "claude-db disponible si vas a auditar la BD: agrégalo con `/setup-project claude-db`").
- Recordatorio: reiniciar Claude Code o ejecutar `/reload-plugins` para que apliquen.
