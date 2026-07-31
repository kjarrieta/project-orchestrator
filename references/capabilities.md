# Capacidades del entorno (plugins, skills y comandos)

El entorno donde corre la skill ya trae capacidades instaladas: plugins de Claude
Code, skills globales y comandos nativos que pueden hacer parte del trabajo mejor y
más barato que un subagente reinventándolo. Pero cada plugin activo inyecta sus
descripciones en **todas** las sesiones del proyecto: capacidad encendida que no se
usa es token quemado. Este protocolo gobierna cómo el director las evalúa, activa y
usa.

## Principios (no negociables)

1. **Apagado por defecto.** Ninguna capacidad se activa "por si acaso". Se activa
   solo si una tarea concreta de esta corrida la va a usar.
2. **Activación por proyecto, jamás global.** Los plugins se encienden en el
   `.claude/settings.json` del proyecto (`enabledPlugins`), nunca en
   `~/.claude/settings.json`. El comando `/setup-project` y las plantillas de
   `~/.claude/plugin-profiles.md` ya hacen esto: úsalos en vez de editar a mano.
3. **Uso bajo demanda.** Una skill se invoca cuando llega su tarea, no se precarga.
   El subagente que la necesite la recibe nombrada en su encargo.
4. **Justificación en la ficha.** Cada capacidad activada se registra en
   `00-ficha-de-hechos.md` con la tarea que la justifica. Sin tarea, no se activa.
5. **Desactivación al cerrar.** Si la capacidad era para un trabajo puntual (p. ej.
   una auditoría de BD única), al cerrar la corrida propone quitarla del
   `settings.json` del proyecto.
6. **Ante la duda, no actives.** Menciona la capacidad como opcional en la compuerta
   y deja que la persona decida. Reactivar un plugin globalmente no se sugiere nunca.
7. **No dupliques lo nativo.** Claude Code ya trae `/code-review`, `/simplify`,
   `/security-review` y `/verify`: ningún agente reimplementa esas revisiones ni se
   activa un plugin que las duplique.

## Procedimiento (Fase 0, paso 7)

1. **Inventario:** lista las skills disponibles en el contexto de la sesión y lee
   `~/.claude/plugin-profiles.md` para conocer los plugins instalados y sus perfiles.
   No asumas que un plugin existe: si no está en el perfil ni en el inventario, es un
   [HUECO].
2. **Mapeo tarea → capacidad:** por cada tarea del pedido, consulta el mapa de abajo
   y decide si una capacidad instalada la cubre mejor que un subagente genérico.
3. **Activación:** si requiere un plugin apagado, propón el bloque `enabledPlugins`
   para el `.claude/settings.json` del proyecto (o ejecutar `/setup-project <plugin>`)
   y **avisa que requiere reiniciar la sesión o `/reload-plugins`** — planifica la
   corrida para que esa activación ocurra antes de la fase que la usa.
4. **Asignación:** en el encargo del subagente, nombra la capacidad y su uso esperado
   ("usa la skill X para Y; no reimplementes Y").

## Mapa tarea → capacidad

| Tarea de la corrida | Capacidad | Tipo | Quién la usa |
|---|---|---|---|
| Auditar/diseñar/migrar base de datos, seed de datos | plugin `claude-db` (skills: audit, migrate, seed, explain, design, checklist) | plugin por proyecto | agente de BD: **delega en el plugin**, no rehace la auditoría |
| Citar doc oficial de la versión exacta (protocolo de evidencia) | plugin `context7` | plugin por proyecto | cualquier agente que deba anclar un RECOMENDADO |
| Proyecto Laravel | plugin `laravel-boost` | plugin por proyecto | Arquitecto, BD, APIs |
| Proyecto Expo / React Native | plugin `expo` | plugin por proyecto | Arquitecto, Frontend |
| Verificar en navegador / E2E / capturas | plugin `playwright`; skill nativa `/verify` | plugin + nativo | QA (Fase 5) |
| Contratos y colecciones de API | plugin `postman` | plugin por proyecto | agente de APIs (solo con evidencia de uso de Postman en el equipo) |
| Diseño de UI / tokens de diseño | plugin `frontend-design`; `figma` solo si lo piden | plugin por proyecto | Frontend |
| Estilos Tailwind | skill global `tailwind-best-practices` | ya global, costo cero extra | Frontend |
| Revisión de diff / simplificación / seguridad del diff | `/code-review`, `/simplify`, `/security-review` | nativo | director en Fase 5 |
| Analytics de producto | plugin `amplitude` | plugin por proyecto | solo si el pedido lo nombra |
| Flujo TDD estricto / planes | plugin `superpowers` | plugin por proyecto | solo si la persona lo pide |
| Configuración inicial del proyecto | comando `/setup-project` | comando global | director (Fase 0) |
| Plugins nuevos instalados sin auditar / mapa desactualizado | comando `/sync-capabilities` | comando global | director: audita el plugin y fusiona este mapa sin perder lo existente |

Si el entorno de la persona difiere (otros plugins, otros nombres), el inventario del
paso 1 manda: este mapa es la guía, no la verdad — verifica contra lo instalado.

## Regla final

La capacidad correcta ahorra tokens dos veces: el subagente no reinventa el trabajo y
la sesión no carga descripciones que nadie usa. La medida del éxito es la misma de
toda la skill: ni una capacidad activa sin tarea que la justifique, ni una tarea
reimplementada cuando ya existía la herramienta.
