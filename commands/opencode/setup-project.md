---
description: Prepara las capacidades del proyecto (activa solo las skills/MCP que su stack necesita) y define los agentes responsables por rol — agnóstico de proveedor
---

# Configuración inicial del proyecto

Este comando prepara las **capacidades** (agentes/skills/MCP) que el proyecto necesita y,
con ellas, la **asignación de roles** de la corrida (arquitecto / aplicación / escritura).
El objetivo es que el sistema funcione **con cualquier backend de agentes, sin importar la
licencia** — opencode es la implementación concreta actual, no un requisito.

**Backend actual (opencode):** las capacidades del entorno (skills y MCP) se activan por
proyecto para ahorrar tokens: las skills se colocan en `.agents/skills/` (o se referencian desde las
globales de `~/.agents/skills/`) y los servidores MCP se habilitan en
`.opencode/opencode.json`. Tu tarea es detectar el stack del proyecto actual y generar
esa configuración automáticamente.

Argumentos del usuario (hints extra, puede estar vacío): $ARGUMENTS

## Paso 1 — Detectar el stack

Inspecciona la raíz del directorio de trabajo actual (NO `~`; si el directorio de
trabajo es el home del usuario, detente y pide que abra opencode dentro de un proyecto).
Busca estos marcadores:

| Marcador | Stack |
|---|---|
| `composer.json` con `laravel/framework` | Laravel / PHP |
| `app.json` o `app.config.*` con `expo`, o `expo` en `package.json` | Expo / React Native |
| `package.json` con `react`, `next`, `vue`, `svelte` (sin expo) | Frontend web |
| Migraciones, `prisma/schema.prisma`, `drizzle.config.*`, carpeta `database/`, docker-compose con postgres/mysql | Proyecto con base de datos |
| Colecciones Postman, carpeta `api/` con specs OpenAPI | APIs |
| `tailwind.config.*` o `@tailwindcss` en dependencias | Tailwind (skill global) |

Un proyecto puede tener varios stacks a la vez (ej. Laravel + Tailwind + DB).

## Paso 2 — Mapear stack → capacidades de opencode

Consulta `references/capabilities.md` de la skill `project-orchestrator` como fuente de
verdad del mapa tarea→capacidad, y lista las skills realmente instaladas (`.agents/skills/`,
`.claude/skills/` del proyecto y `~/.agents/skills/` global) y los MCP disponibles en la
config de opencode (`~/.config/opencode/opencode.json`). Mapeo base:

- Laravel/PHP → PHP/Laravel propio (sin skill obligatoria); `db-*` solo si hay esquema relevante
- Expo/React Native → sin skill específica salvo que exista
- Frontend web con Tailwind → `tailwind-best-practices`
- Auditoría de BD → skills `audit` / `db-*` (solo si el proyecto tiene esquema/migraciones Y el usuario suele auditar; si hay duda, no las actives y menciónalo)
- APIs → `postman` MCP u OpenAPI si ya está configurado

Si el usuario pasó argumentos, inclúyelos aunque no haya marcadores. Sé conservador:
el objetivo es ahorrar tokens; ante la duda, menos capacidades y menciona las opcionales
al final.

## Paso 3 — Generar la configuración

1. Si la skill `project-orchestrator` (u otra global de `~/.agents/skills/`) aplica a
   este proyecto, cópiala a `.agents/skills/` del proyecto (activación por proyecto).
2. Si ya existe `.opencode/opencode.json`, léelo y FUSIONA (no sobrescribas claves
   existentes; solo agrega/actualiza los bloques `mcp` de los servidores que el stack
   justifica).
3. Si no existe, crea `.opencode/opencode.json` con solo el bloque `mcp` y los
   servidores que el stack requiere (con `"enabled": true`).
4. No toques `~/.config/opencode/opencode.json` global.

## Paso 4 — Asignar agentes por rol (agnóstico de proveedor)

Con las capacidades ya elegidas, registra en `.orchestrator/agents.json` qué agente cumple
cada rol de la corrida — **arquitecto, aplicación/ejecución y escritura/documentación** —
siguiendo `references/setup.md` (Paso 1.5). Por defecto son los subagentes del backend
actual; si hay otro proveedor, se nombran aquí. Ningún rol queda sin asignar antes de
arrancar la Fase 1.

## Paso 5 — Reportar

Muestra al usuario:
- Stack(s) detectado(s) y la evidencia (archivos encontrados).
- Capacidades activadas en el proyecto (skills copiadas a `.agents/skills/`, MCP en `.opencode/opencode.json`).
- Agentes asignados por rol (arquitecto / aplicación / escritura).
- Capacidades opcionales que NO activaste y por qué.
- Recordatorio: reiniciar opencode (o la sesión) para que las skills/MCP nuevos apliquen.
