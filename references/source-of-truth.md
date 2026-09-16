# Fuente única: copias declaradas y hechos derivados

Dos invariantes de una misma familia. Los dos nacen del mismo hueco que
`anti-regression.md` ya diagnostica —**la política es prosa pasiva**— aplicado esta vez no
al código del proyecto sino a **los artefactos que describen el sistema**: comandos,
documentación, instaladores, paquetes distribuibles, snapshots de memoria.

El patrón es siempre el mismo y siempre pasa en silencio:

- Un artefacto existe en **más de una copia**. Alguien mejora una. Las otras se quedan
  atrás. Nada falla. La copia vieja sigue ejecutándose en algún host hasta que alguien
  la lee y descubre que describe un procedimiento que ya no existe.
- Un **hecho contable** («12 agentes», «3 fases», la lista de comandos) se escribe a mano
  en la prosa. El inventario real cambia. La prosa no. Nada falla. La cifra se vuelve
  mentira y se propaga a cada copia.

Ninguno de los dos es un bug de código: son regresiones de artefacto. La auditoría no los
mira porque no están en `app/`, y el build no los rompe porque no se compilan. Por eso
necesitan su propia firma detectable y su propia compuerta.

---

## INV-SOT-01 — Copia declarada, nunca sincronizada a ciegas

> Todo artefacto que exista en más de una copia **declara** sus copias. Ninguna copia se
> actualiza sobrescribiendo otra. La divergencia se detecta por máquina antes de
> distribuir, no por lectura casual después.

### Lo que obliga

1. **Declaración de copias.** Donde viven las instrucciones de instalación o de
   empaquetado del artefacto, una tabla declara: `fuente | copias | diferencias legítimas
   | quién sincroniza`. Una copia sin declarar es una copia que va a derivar.
2. **Diferencias legítimas explícitas.** Una copia puede diferir a propósito —un port a
   otro backend, un frontmatter propio del host, una traducción. Esas diferencias se
   nombran en la declaración. Lo que **no** está declarado como legítimo es deriva.
3. **Prohibido sincronizar por sobrescritura entre copias de distinta variante.** `cp A B`
   entre dos ports destruye el port. Una mejora de procedimiento **se porta a mano a cada
   variante**; solo las copias declaradas como idénticas se sincronizan copiando.
4. **Paridad de inventario.** El conjunto de nombres de archivo debe ser idéntico entre
   copias. Un nombre presente en una y ausente en otra es un artefacto que ese destino
   nunca va a tener: se reporta, **no se rellena copiando la otra variante**.

### Firma detectable

```json
{
  "id": "INV-SOT-01",
  "clase": "invariante",
  "dominio": "integridad-de-artefacto",
  "invariante": "Copias del mismo artefacto no divergen en inventario ni en procedimiento sin declararlo.",
  "senal": {
    "tipo": "paridad_inventario + diff_declarado",
    "alcance_rutas": ["<cada conjunto de copias declarado>"],
    "patron": "nombres de archivo simétricos entre copias; diff de contenido (ignorando fin de línea) acotado a las diferencias declaradas legítimas",
    "nota": "Divergencia en fases, compuertas, pasos, rutas de artefacto o reglas = deriva real. Divergencia en backend o frontmatter del host = legítima si está declarada."
  },
  "severidad": "HIGH",
  "gate": "BLOCKING para distribuir · NON-BLOCKING para producción"
}
```

Ignorar el fin de línea al comparar es parte de la firma: sin eso, un archivo CRLF frente
a su gemelo LF se reporta como 100 % divergente y la compuerta se vuelve ruido que nadie
lee.

---

## INV-SOT-02 — Un hecho derivable no se escribe a mano

> Si un dato se puede **contar o listar desde su registro**, no se duplica en prosa. Se
> deriva, o se nombra de forma que no caduque.

### Lo que obliga

1. **Nada de cifras de inventario en la prosa.** El número de agentes, de comandos, de
   módulos o de reglas vive en su registro y en ningún otro lugar. En la prosa se escribe
   la categoría, no el conteo: «el equipo de agentes», no «los N agentes».
2. **Una lista se referencia, no se transcribe.** Un segundo lugar que enumera lo que un
   registro ya enumera es un segundo lugar que va a quedar incompleto. Se apunta al
   registro.
3. **La herramienta da candidatos, no veredictos.** Igual que en dead code y DRY
   (`conventions-reviewer.md`), una coincidencia se confirma leyendo la frase: ¿el número
   afirma cuántos elementos hay, o es una cantidad cualquiera? Reportar sin ese triaje
   convierte la política en ruido, y el ruido en política ignorada.
4. **Excepción explícita — el conteo de diseño cerrado.** Un número es legítimo cuando
   **sus elementos están enumerados en el mismo documento** y el conjunto es cerrado por
   diseño, no por inventario: «cuatro capas A–D» es el nombre de la arquitectura, no un
   censo. La prueba: si el número puede cambiar porque alguien *agregó* algo a un
   registro, está prohibido; si solo puede cambiar rediseñando, es legítimo.

### Firma detectable

La firma solo mira **dígitos**: incluir los números en palabras (`dos`, `tres`, `cuatro`)
la vuelve inservible, porque la prosa técnica los usa todo el tiempo para cantidades
genéricas. Medido sobre esta misma skill, la variante con palabras daba una violación real
por cada cinco coincidencias; la de solo dígitos, una por cada dos. Una firma que produce
más ruido que señal no se desactiva: se ignora, que es peor.

```json
{
  "id": "INV-SOT-02",
  "clase": "invariante",
  "dominio": "integridad-de-artefacto",
  "invariante": "Ningún hecho derivable de un registro se duplica como literal en la prosa.",
  "senal": {
    "tipo": "grep_prohibido",
    "alcance_rutas": ["**/*.md"],
    "patron": "\\b(\\d{1,3})\\s+(agentes|comandos|fases|capacidades|módulos|reglas|plugins|skills)\\b",
    "requiere_ademas": "que el número afirme el tamaño de un inventario",
    "nota": "La coincidencia es un CANDIDATO, no un veredicto: se confirma solo si el número afirma cuántos elementos hay. No son violaciones una cantidad genérica en prosa, un anti-patrón citado, ni un conteo de diseño cerrado con sus elementos enumerados al lado."
  },
  "severidad": "MEDIUM",
  "gate": "NON-BLOCKING, pero se corrige en la misma corrida que lo detecta"
}
```

---

## Dónde se hace cumplir

La ejecución primaria es la misma de la Capa A de `anti-regression.md`: **una compuerta
mecánica antes de distribuir**, no la memoria de quien edita.

| Ámbito | Compuerta | Quién |
|---|---|---|
| Artefactos de la propia skill (comandos por backend, `INSTALL.md`, paquete, snapshot de memoria) | `/pack-skill` verifica paridad de inventario, diff entre variantes y firma de INV-SOT-02 **antes** de comprimir; con `--verify` reporta sin empaquetar. Falla la compuerta = no se empaqueta | Orquestador |
| Artefactos duplicados del proyecto auditado (config por entorno, docs paralelas, contratos replicados, README que repite un registro) | Hallazgo de auditoría con su firma; entra al inventario de copias del proyecto | Revisor de Convenciones (`conventions`, ya dueño de DRY y duplicación) |
| Documentación viva | No se escribe un hecho derivable: se apunta al registro que lo tiene | Documentación (`documentation`) |
| Cierre | Promueve la entrada al registro de regresiones y la materializa como firma de `policy:lint` (Capa A) o test (Capa D) | Aprendiz (`learning`) |

En un proyecto, la declaración de copias de INV-SOT-01 vive en
`.orchestrator/project-memory/copias.md`, junto al registro de regresiones, y se relee en
Fase R como cualquier otra memoria de proyecto.

## Qué NO es una violación

El registro es corto a propósito y esta política se muere el día que produzca falsos
positivos:

- Una diferencia **declarada** entre variantes de backend o de host. Es el diseño.
- Un fin de línea distinto entre copias.
- Un conteo de diseño cerrado con sus elementos enumerados al lado (la excepción de
  INV-SOT-02).
- Dos artefactos que se parecen pero tienen dueños y ciclos de vida distintos: no son
  copias, y forzarlos a una fuente única los acopla sin razón.

## Origen

Ambos invariantes nacen de regresiones observadas, no de teoría:

- **INV-SOT-01:** los comandos compañeros portados a un segundo backend quedaron atrás en
  procedimiento (les faltaban una fase de meta-auditoría, la compuerta de producción y un
  paso completo de asignación de roles) porque el flujo de instalación copiaba una sola
  variante a los dos destinos y reintroducía la deriva en cada equipo nuevo. En la misma
  revisión, un comando viajaba dentro del paquete y no estaba instalado en **ningún**
  destino: presente en el inventario, ausente en las dos copias.
- **INV-SOT-02:** una cifra de agentes escrita a mano quedó obsoleta y sobrevivía
  replicada en varios archivos, incluido el encabezado público del instalador, mientras
  el resto de la documentación ya usaba la forma sin número.
