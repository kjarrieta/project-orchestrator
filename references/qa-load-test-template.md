# Plantilla de harness de carga (k6) — tolerancia real a múltiples usuarios

Complemento de `qa-test-taxonomy.md` cat. 3. El unit/integration con runner
mono-conexión NO mide tolerancia a carga concurrente real; esto sí. Herramienta por
defecto: **k6** (Grafana), scripts en JavaScript, sin dependencia del stack del backend
→ sirve para cualquier proyecto (Laravel, Node, Python, Go…). Alternativas equivalentes:
Artillery, JMeter, Gatling, o N procesos paralelos. Traduce el mecanismo si usas otra.

Dos objetivos distintos, no los mezcles:

1. **Race de duplicado / integridad** — muchos VUs disparan el MISMO request de creación
   a la vez; después se verifica que quedó **1 solo** registro. Prueba que exista la
   `UNIQUE`/idempotencia (cat. 3/5) bajo concurrencia real, no simulada.
2. **Tolerancia / rendimiento** — carga sostenida creciente sobre endpoints de lectura y
   escritura; se miden umbrales (p95 de latencia, tasa de error, throughput) para
   conocer el punto de saturación.

## Requisitos y disciplina
- Corre contra un **entorno dedicado** (staging o local con datos de prueba), **NUNCA
  producción**: genera escrituras reales. Siémbralo antes.
- La **aserción de "1 solo registro"** k6 no la ve desde el cliente: exponla vía un
  endpoint de conteo de solo-lectura (admin/test) o compárala en `teardown()` /
  manualmente en la BD tras la corrida. Documenta cuál usaste.
- Credenciales y URL por variable de entorno (`__ENV`), nunca quemadas.

## Plantilla genérica — race de duplicado (cat. 3/5)
Copia y reemplaza los TODO. `setup()` autentica y crea el recurso padre; el default
lanza el MISMO POST desde todos los VUs a la vez; `teardown()` verifica unicidad.

```javascript
// duplicate-submit-race.js  —  k6 run -e BASE_URL=http://localhost:8000 -e USER=.. -e PASS=.. duplicate-submit-race.js
import http from 'k6/http';
import { check } from 'k6';

const BASE = __ENV.BASE_URL;

export const options = {
  scenarios: {
    // Todos los VUs ejecutan 1 iteración lo más simultáneo posible = doble-clic masivo.
    thundering_herd: { executor: 'shared-iterations', vus: 50, iterations: 50, maxDuration: '30s' },
  },
  // Bajo integridad correcta, los duplicados deben ser rechazados (409/422), no 500.
  thresholds: { 'http_req_failed{expected_response:true}': ['rate<0.01'] },
};

export function setup() {
  // TODO: login para token (ajusta ruta y forma del payload/campo del token).
  const res = http.post(`${BASE}/api/auth/login`, JSON.stringify({ email: __ENV.USER, password: __ENV.PASS }),
    { headers: { 'Content-Type': 'application/json' } });
  const token = res.json('body.token'); // TODO: ruta real del token en el envelope
  // TODO: crear/obtener el recurso padre (pairing, carrito, etc.) y su id fijo compartido.
  const parentId = /* TODO */ 1;
  return { token, parentId };
}

export default function (data) {
  const headers = { 'Content-Type': 'application/json', Authorization: `Bearer ${data.token}` };
  // TODO: MISMO payload en todos los VUs (misma clave natural) para forzar el duplicado.
  const payload = JSON.stringify({ /* TODO: campos idénticos + data.parentId */ });
  const res = http.post(`${BASE}/api/TODO-endpoint-de-creacion`, payload, { headers });
  // Un backend correcto: 1 crea (2xx) y el resto rebota (409/422). NUNCA 500 ni 2xx múltiples.
  check(res, { 'no 5xx': (r) => r.status < 500 });
}

export function teardown(data) {
  // TODO: consultar el conteo real y afirmar UNICIDAD (endpoint de conteo o revisión en BD).
  const res = http.get(`${BASE}/api/TODO-conteo?parent=${data.parentId}`,
    { headers: { Authorization: `Bearer ${data.token}` } });
  const count = res.json('body.count');
  if (count !== 1) {
    console.error(`FALLO INTEGRIDAD: ${count} registros creados por 50 requests simultáneos (esperado 1). Falta UNIQUE/idempotencia.`);
  }
}
```

## Plantilla genérica — tolerancia sostenida (rendimiento)
```javascript
export const options = {
  scenarios: {
    ramp: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 50 },   // subida
        { duration: '1m',  target: 50 },    // meseta
        { duration: '2m',  target: 200 },   // estrés
        { duration: '30s', target: 0 },     // bajada
      ],
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<800'],   // TODO: SLA real del proyecto
    http_req_failed:   ['rate<0.02'],
  },
};
// default(): mezcla realista de endpoints (lectura pesada + alguna escritura idempotente).
```

## Política: prueba de esfuerzo con TESTIGOS obligatorios
Todo proyecto con usuarios concurrentes debe tener una **prueba de esfuerzo** (carga
sostenida creciente hasta saturación) que **emita artefactos de evidencia** — los
"testigos". En k6 se logra con `handleSummary()` devolviendo `stress-summary.json`
(métricas crudas) y `stress-report.txt` (resumen legible), además del `stdout`. Sin
testigo persistido, la prueba de esfuerzo no cuenta: el número (p95, p99, tasa de error,
throughput, VUs al primer fallo) debe quedar guardado y citado en el informe, no solo
verse una vez en consola. El testigo es el que permite comparar contra futuras corridas
y detectar regresión de rendimiento.

## Salida esperada del agente QA
- Script(s) k6 en `tests/load/` (o equivalente) del proyecto, parametrizados por `__ENV`.
- En el informe: qué endpoints de dinero/estado se cargaron, el resultado del race
  (¿unicidad respetada?), y los umbrales p95/error observados vs el SLA. Si no hubo
  entorno dedicado para correrlo, entrega el script + instrucciones y márcalo PENDIENTE
  de ejecución por la persona (no lo corras contra producción).
```
