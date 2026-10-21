# Taxonomía de tests del agente QA (catálogo global — aplícalo a TODO proyecto)

Este catálogo estandariza **qué tipos de test** debe implementar QA en modo APLICACIÓN
para lograr cobertura completa, en cualquier stack. No sustituye el brief `qa.md` (los
tres lentes: lógica / caja negra / caja blanca) ni `evidence-protocol.md`: los
materializa en categorías repetibles. Deriva los casos de las reglas de negocio y de
los hallazgos de auditoría; cada categoría mapea a un tipo de hallazgo conocido.

Es **agnóstico de lenguaje**: los ejemplos citan PHPUnit/Laravel porque nacieron ahí,
pero cada categoría se traduce a Jest/Vitest, PyTest, JUnit, Go testing, RSpec, etc.
Traduce el mecanismo, no lo copies literal.

## Regla transversal — honestidad del verde (vale para TODAS las categorías)

Un test defiende el comportamiento **correcto/seguro/especificado**, no el que el
código hace hoy. Si el hallazgo aún NO está corregido, el test **fallará**. Nunca
debilites la aserción para que pase. En su lugar:

```
$this->markTestSkipped('VULN|BUG <ID>: <descripción corta>; test listo para activarse al aplicar el fix');
```

Así la suite queda verde **sin ocultar** el hueco: el test es documentación viva del
defecto y se vuelve activo (quitas el skip) en cuanto se aplica la corrección. Reporta
cada skip con su ID de hallazgo y ruta:línea del código atacado. Un test que pasa
afirmando comportamiento inseguro es sabotaje (regla de oro de `qa.md`).

## Las 6 categorías

### 1. Reglas de negocio (funcional vs especificación)
- **Ataca:** cada regla del registro de negocio y de las políticas del proyecto — límites
  (máx N), transiciones de máquina de estado válidas e ilegales, flags derivados,
  invariantes que se rompen en casos borde, doble rol / permisos por pertenencia.
- **Método:** deriva casos de la regla, no del código. Camino feliz + error + abuso.
  Frontera exacta con `config()` (no literales quemados) cuando la regla es parametrizable.
- **Antes de asertar:** verifica **dónde** se hace cumplir la regla —guard en
  Service/Controller (testea el rechazo) vs solo un **flag** expuesto que el frontend
  consume (testea que el flag sea correcto, NO un rechazo inexistente) vs sin
  enforcement (bug → skip-con-ID). Confundir estas tres es el error más común.

### 2. Seguridad — control de acceso (IDOR/BOLA, BFLA, exposición)
- **Ataca:** OWASP API Top 10 #1 (BOLA/IDOR) y #5 (BFLA). Un actor autenticado ajeno
  intenta leer/mutar el recurso de otro por `{id}` → debe recibir **403** y el recurso
  **no** debe cambiar. Función privilegiada invocada por rol que no la tiene → 403.
- **Incluye:** que las respuestas de error **no filtren** stack trace, volcado del
  request, PII ni SQL crudo (envelope amistoso); expiración/rotación de tokens; que un
  campo de propiedad (`owner_id`, `user_id`) **no** se acepte desde el cliente.
- **Método:** patrón dueño-vs-ajeno: crea recurso de A, actúa como B, aserta 403 +
  estado intacto; y el contraste positivo (el legítimo obtiene 200).
- **Dueño del veredicto de aislamiento de tenants:** coordina con el agente Seguridad.

### 3. Concurrencia / integridad (tolerancia a múltiples usuarios — parte testeable)
- **Ataca:** carreras que crean duplicados o pierden escrituras: falta de `UNIQUE` en
  claves naturales, dedup solo en código sin lock, doble-booking de slots, lost update.
- **Método en test unitario/integración:** prueba la **integridad que DEBERÍA atrapar la
  carrera**, no hilos reales: dos inserts de la misma clave natural → esperar violación
  `UNIQUE` (excepción de query); llamar dos veces al método idempotente → esperar 1 fila.
- **LÍMITE HONESTO (documéntalo siempre):** un runner mono-conexión (p. ej. SQLite
  in-memory) **no** mide tolerancia real a carga concurrente. La tolerancia a múltiples
  usuarios simultáneos requiere un **harness de carga separado** (k6, Artillery, JMeter,
  Gatling, o N procesos paralelos golpeando un server real con conexión concurrente).
  Si el proyecto lo necesita, decláralo como entregable aparte, no lo finjas en el unit.
  **Plantilla lista:** `qa-load-test-template.md` (k6) — race de duplicado (thundering
  herd → verificar unicidad) y carga sostenida (ramping-vus + umbrales p95/error).

### 4. Manejo de errores / atomicidad
- **Ataca:** transacciones sin rollback, `catch` demasiado estrecho (captura
  `Exception` pero no `Throwable`/`Error` → escrituras parciales escapan), pasos
  multi-escritura sin transacción, y fuga de errores crudos al cliente.
- **Método:** fuerza un fallo a mitad de la operación (dato que rompe la 2ª escritura,
  mock que lanza) → aserta **cero estado parcial** (rollback completo) y que el cliente
  recibe el envelope amistoso con el código correcto, sin traza.

### 5. Doble-submit / idempotencia de request (doble clic, reenvío)
- **Ataca:** el mismo request enviado dos veces seguidas que crea registros o efectos
  duplicados (doble oferta, doble comisión, doble cita, doble cobro, doble notificación).
- **Método:** autentica al actor legítimo; ejecuta el MISMO request 2 veces; aserta
  **exactamente 1** registro y **0** efectos colaterales duplicados (usa el faker de
  notificaciones para contar envíos, verifica filas de auditoría/timeline).
- **Diagnóstico:** endpoints con `updateOrCreate`/`firstOrCreate`/guard de estado previo
  pasan (protección por diseño); `create` ciego duplica → bug `DUP-<n>` con el endpoint.
- **Relación:** los duplicados por doble-submit y por carrera (cat. 3) se cierran a
  menudo con la MISMA `UNIQUE`/idempotencia; pruébalos por separado porque el disparador
  (un actor haciendo doble clic vs dos actores) y la mitigación (token idempotente vs
  lock) difieren.

### 6. Regresión de contrato (snapshot)
- **Ataca:** cambios no intencionados en la forma de la respuesta de endpoints críticos.
- **Método:** snapshot de la respuesta (con enmascarado de campos dinámicos: ids, fechas,
  tokens) grabado como línea base y comparado en cada corrida. Prioriza endpoints de
  dinero/estado (aceptar oferta, confirmar negocio, pagos), no solo login/perfil.
- **Nota:** la línea base la graba la persona (modo `record`); QA no inventa el baseline.

## Cómo se organiza en el repo
- Una carpeta/clase por categoría y recurso (`Security/IdorXTest`, `Integrity/…Test`,
  `DoubleSubmit/…Test`), nombres únicos para permitir agentes en paralelo sin colisión.
- En corridas multi-agente concurrentes sobre el mismo repo: nombres de clase disjuntos,
  **sin comandos git**, cada agente corre solo su `--filter`.
- Si el framework de test del proyecto está en `.gitignore` (frecuente), los archivos
  quedan locales: avísalo, no asumas que se versionan.

## Checklist de cobertura completa (por alcance auditado)
Para cada recurso/endpoint que el alcance toca, pregúntate si existe test de:
- [ ] cada regla de negocio que le aplica (cat. 1)
- [ ] acceso ajeno por id → 403 (cat. 2)
- [ ] función privilegiada por rol incorrecto → 403 (cat. 2)
- [ ] la respuesta de error no filtra traza/PII (cat. 2/4)
- [ ] clave natural con UNIQUE / dedup lógico (cat. 3)
- [ ] rollback ante fallo a mitad (cat. 4)
- [ ] doble-submit deja 1 registro (cat. 5)
- [ ] contrato bajo snapshot si es endpoint crítico (cat. 6)
- [ ] **prueba de esfuerzo con testigo** si el proyecto tiene usuarios concurrentes (cat. 3 / política de carga)
Una casilla sin test es un [HUECO] a reportar, no un supuesto de que está cubierto.

## Política global: prueba de esfuerzo obligatoria (proyectos con concurrencia)
Además del race de integridad (cat. 3), todo proyecto con usuarios simultáneos requiere
una **prueba de esfuerzo** de carga sostenida hasta saturación, con **testigos**
(artefactos de evidencia persistidos: p95/p99, tasa de error, throughput, VUs al primer
fallo). Plantilla y disciplina en `qa-load-test-template.md`. Un número visto en consola
y no guardado no es testigo. Corre solo contra entorno dedicado, nunca producción.
