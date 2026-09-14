# Presupuesto de tokens — catálogo de fugas y sus curas

Referencia del director y de cualquier agente que dimensione una corrida. El
`SKILL.md` fija las reglas vinculantes; aquí está el porqué, el diagnóstico y las
curas medidas.

Origen del catálogo: taxonomía de *token sinks* de `caveman learn`
(`proxy/internal/store/learn.go`, repo `JuliusBrussee/caveman`, verificado 2026-09-01),
contrastada contra el setup real de este equipo.

## Cómo leer esto

Una fuga es **estructural** (se paga en cada turno, exista o no trabajo) o
**conductual** (se paga por cómo se trabaja). Las estructurales son las que más
compensan cerrar: su coste se multiplica por cada turno de cada sesión de cada
proyecto. Ninguna cifra de abajo prueba que una lectura o un subagente concreto
sobraran; miden agregados, y se usan para decidir dónde mirar, no para acusar.

## Fugas estructurales (se pagan en cada turno)

### `config_surface` — superficie de configuración siempre cargada
Skills, plugins, servidores MCP y salida de hooks `SessionStart`/`UserPromptSubmit`
inyectan su descripción o su salida en cada turno. El **frontmatter de una skill es
su token más caro**: se paga aunque la skill nunca se invoque.

**Cura:** desactivar por defecto (`enabledPlugins: false`, `skillOverrides: "off"`) y
activar por proyecto. Nunca dejar copias sueltas de skills que ya trae un plugin.

### `config_growth` — el archivo siempre cargado que crece
`CLAUDE.md`, `AGENTS.md` y `MEMORY.md` crecen por acumulación y nunca se podan. Cada
línea añadida se paga en todos los turnos futuros.

**Cura:** antes de añadir una línea, comprobar que aún gana su lugar. Al añadir una
política, comprimir el resto para que el archivo no crezca neto.

### `mcp_surface` — esquemas de servidores MCP sin uso
El esquema de cada herramienta de cada servidor habilitado viaja en el prefijo de
todos los turnos, se use o no.

**Cura:** habilitar servidores por proyecto. Preferir herramientas diferidas.

### `cache_churn` — rotura del caché de prefijo
Cualquier contenido que cambie por turno (timestamps, salida de hooks, estado
dinámico) colocado **cerca del inicio** del prompt invalida el caché de prefijo y
obliga a re-facturar todo lo que va detrás. Cambiar de modelo o de nivel de esfuerzo
a mitad de sesión tiene el mismo efecto.

**Cura:** contenido volátil al final, no al principio. Fijar modelo y esfuerzo al
arrancar la corrida.

### Cuerpo de skill que duplica su propia referencia
El peor desperdicio de una skill no es la longitud, sino que el cuerpo **resuma en
prosa lo que ya vive casi verbatim en `references/`**: el agente paga el resumen y
además la referencia que acaba leyendo.

**Cura:** el cuerpo lleva un puntero de una línea; el detalle vive solo en
`references/`. Se aplicó a esta skill (cuerpo 26.510 → 19.647 chars, frontmatter
974 → 577 chars).

## Fugas conductuales (se pagan por cómo se trabaja)

### `context_dumbzone` — trabajar en la zona tonta
La calidad de las respuestas cae **bastante antes** de llegar al límite de la ventana.
Llenar la ventana no es aprovecharla: es degradarse y pagar por ello.

**Cura:** los umbrales relativos del `SKILL.md` (60-75 % resumir, 75-90 % checkpoint
obligatorio, >90 % cerrar la ejecución) existen por esto. Dividir antes, no al tope.

### `compaction_churn` — coste de pasarse de la ventana
La compactación forzada es el precio medido de no haber dividido a tiempo: se re-emite
un resumen y se pierde detalle que luego hay que re-derivar.

**Cura:** checkpoint por umbral, no por evento. Es el fundamento de P-CHECKPOINT-01.

### `subagent_overuse` / `subagent_spend` — subagentes como reflejo
Cada subagente arrastra **su propio contexto completo**, y ese gasto es invisible en la
conversación principal: por eso sorprende al medirlo. Para una consulta de un archivo,
leerlo directo sale más barato que delegar.

**Cura:** delegar por **incertidumbre**, no por comodidad (regla de corte del
`SKILL.md`). El techo por corrida y el "DELEGATION EXHAUSTED" son el freno duro.
Contar subagentes no prueba que alguno sobrara; obliga a justificar el siguiente.

### `reread_waste` — re-lecturas completas del mismo archivo
Releer entero un archivo ya leído es la fuga conductual más repetida en corridas
largas, y crece con el número de auditores.

**Cura:** el `00-mapa.md` y las parcelas por auditor existen para esto. Dentro de una
parcela, releer por rango (`sed -n`, `offset`/`limit`), nunca el archivo entero, y
citar por `ruta:línea` para no tener que volver.

### `tool_output_portfolio` — ruido de comandos y búsquedas
Las salidas de herramientas dominan lo que vuelve a entrar en contexto: instaladores,
suites de test verbosas, `grep` sin acotar, listados recursivos completos.

**Cura:** comandos callados por defecto (`-q`, `--quiet`, `--no-ansi`, `| tail -n`),
`grep` con `-c` u `-o` cuando basta el conteo, listados filtrados. Un hallazgo
repetido se reporta como **conteo + un ejemplo**, nunca como lista completa.

## Disciplina de escritura de los informes

Aplica a todo informe de agente, ficha de hechos y entrada de ledger.

**Sí ahorra:** eliminar relleno, cortesías, narración de herramientas ("ahora voy a
leer…"), preámbulos, recapitulaciones de lo ya dicho y tablas decorativas.

**No ahorra —medido, no intuido—:**

- **Abreviaturas inventadas** (`cfg`, `impl`, `req`, `res`, `fn`): el tokenizador las
  parte igual que la palabra completa. Cero tokens ahorrados y peor lectura.
- **Flechas `→`** usadas como compresor: la flecha es su propio token. Como notación
  de pipeline (`Fase 1 → 2`) es legítima; como sustituto de "produce" o "luego", no
  ahorra nada.
- **Gramática mutilada** para "sonar comprimido": la forma correcta suele costar los
  mismos tokens y se lee mejor.

**Nunca comprimir:** negaciones (`no`, `nunca`, `solo`, `salvo` — invertir el sentido
cuesta más que cualquier token ahorrado), números, unidades, rutas, `ruta:línea`,
código, comandos y cadenas de error, que van verbatim.

**Nunca comprimir tampoco:** advertencias de seguridad, confirmaciones de acciones
irreversibles y los pasos de una secuencia donde el orden importa. En la compuerta
humana y en los veredictos del Production Gate, la claridad manda sobre la brevedad.

## Antes de consolidar para ahorrar

Antes de fusionar skills satélite o mover contenido a `references/`, buscar **quién
las invoca por nombre**. Una skill referida explícitamente por un agente deja de ser
alcanzable al moverla, y el ahorro se paga con una capacidad rota.
