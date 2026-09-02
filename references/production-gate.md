# Production Readiness Gate (Capa B)

La compuerta de la skill deja de ser un "resumen de hallazgos" y pasa a ser un **gate de
listo-para-producción** con veredicto **GO / NO-GO**. Nace de un defecto metodológico
real: una corrida cerró con *"nada bloquea la operación actual"* pese a tener hallazgos
de seguridad confirmados y un boundary crítico sin evidencia. Un gate de producción
**no puede permitir eso**. Este documento fija el criterio de decisión que usan todas
las auditorías.

> Regla madre: el gate automático es un **complemento que informa la compuerta humana,
> no la decisión final**. La persona sigue siendo la autoridad última (regla innegociable
> de la skill). Lo que el gate garantiza es que la *clasificación* del riesgo no se delega
> ni se ablanda: el usuario puede aceptar una deuda, pero el gate la declara como **riesgo
> asumido**, nunca como "nada bloquea". La compuerta pregunta *qué corregir* **después** de
> emitir el veredicto, no en su lugar.

## Los tres ejes de todo hallazgo (no solo severidad)

Cada hallazgo se clasifica en tres ejes independientes. Severidad sola engaña: un
MEDIUM sobre aislamiento de tenant es más peligroso que un HIGH de un Service gordo.

- **Severidad:** `CRITICAL | HIGH | MEDIUM | LOW | INFO`.
- **Gate:** `BLOCKING | NON-BLOCKING`.
- **Confianza (evidencia):** `CONFIRMED | LIKELY | UNVERIFIED | DESIGN-DEBT | OBSERVATION`.

| Confianza | Significado |
|---|---|
| CONFIRMED | Vulnerabilidad/bug demostrado con evidencia ruta:línea o test que falla. |
| LIKELY | Evidencia fuerte, falta la confirmación final. |
| UNVERIFIED | No existe evidencia suficiente (ni a favor ni en contra). |
| DESIGN-DEBT | Problema arquitectónico, no un fallo activo. |
| OBSERVATION | Mejora no obligatoria. |

## Reglas duras del gate

1. **`hard_gates` — cualquiera abierto ⇒ NO-GO**, sin importar cuántos PASS haya ni
   cuántos agentes aprobaron. La lista mínima:
   ```yaml
   hard_gates:
     - cross_tenant_access
     - unauthorized_mutation
     - privilege_escalation
     - sensitive_data_exposure
     - broken_foreign_key
     - invalid_state_transition
     - financial_double_processing
     - lost_update
     - confirmed_race_condition
     - non_idempotent_retry
     - destructive_migration_without_strategy
     - missing_required_audit
   ```
   Estas claves coinciden con las `clase`/`dominio` del registro de regresiones
   (`regression-ledger.md`): un `hard_gate` abierto suele mapear a una entrada BLOCKING
   del registro.

2. **PASS requiere evidencia.** Ningún eje se marca `PASS` sin **listar** su evidencia
   (ruta:línea, nombre de test, policy/lint que lo cubre). Sin evidencia ⇒ `UNVERIFIED`,
   **nunca** `PASS`. Esta sola regla elimina la mayoría de los falsos "todo está bien".
   ```
   Security: PASS
   Evidence:
     - CommissionPolicy::update() en app/Policies/CommissionPolicy.php:22
     - CommissionAuthorizationTest::test_user_cannot_update_foreign_commission (verde)
     - policy:lint LW-MUTATION-NO-AUTHZ = 0 nuevas
   ```

3. **Un HIGH/CRITICAL CONFIRMED de seguridad, integridad financiera, aislamiento de
   tenant o concurrencia ⇒ BLOCKING / NO-GO.** No puede terminar en "nada bloquea" sin
   una justificación explícita **y evidencia** de que no es explotable.

4. **UNVERIFIED sobre un boundary crítico ⇒ BLOCKING-hasta-verificar.** La falta de
   prueba sobre aislamiento de tenant, autorización o integridad financiera **no baja**
   la severidad a MEDIUM por "no hay prueba de fuga": bloquea hasta que exista la
   evidencia (típicamente un test de regresión). Distinguir "no sabemos si hay fuga" de
   "no hay fuga" es obligatorio.

5. **FAIL/BLOCKING requiere evidencia reproducible, simétrico a la regla de PASS.** Un
   hallazgo que bloquea el GO no se sostiene solo con sospecha o razonamiento plausible:
   debe declarar el **tipo de evidencia** (static/runtime/test/db/policy/inferred) y, si
   es CONFIRMED, los **pasos de reproducción** (rol, acción, entrada, esperado vs.
   observado) — no solo la ruta:línea del código sospechoso. Sin pasos de reproducción,
   el hallazgo se degrada a `LIKELY` (no `CONFIRMED`) hasta que alguien lo reproduzca;
   sigue bloqueando si su severidad lo amerita, pero no se presenta como demostrado
   cuando no lo está. Esto evita que un BLOCKING se apoye en la misma clase de
   afirmación sin respaldo que la regla de "PASS requiere evidencia" ya prohíbe del
   otro lado.

## Definition of Done — `.orchestrator/20-production-gate.md`

La Fase 3 **debe** producir este artefacto antes de la compuerta. Tabla PASS/FAIL por
dimensión + conteo por severidad + lista de BLOCKING + veredicto:

```
╔══════════════════════════════════════════════════════╗
║              PRODUCTION READINESS GATE               ║
╠══════════════════════════════════════════════════════╣
║ Architecture             PASS                        ║
║ Business Rules           PASS                        ║
║ Database                 PASS                        ║
║ Security                 FAIL                        ║
║ Concurrency              PASS                        ║
║ QA / Coverage            FAIL                        ║
║ Performance              PASS                        ║
║ Observability            PASS                        ║
║ Deployment               PASS                        ║
║ Laravel Standards        PASS                        ║
╠══════════════════════════════════════════════════════╣
║ CRITICAL 0   HIGH 4   MEDIUM 3   LOW 3               ║
╠══════════════════════════════════════════════════════╣
║ BLOCKING: P1/S-01, S-02, P3, P6                      ║
╠══════════════════════════════════════════════════════╣
║              ❌ PRODUCTION: NO-GO                     ║
╚══════════════════════════════════════════════════════╝
```

Debajo, dos listas: **REQUERIDO PARA GO** (los BLOCKING con su corrección) y
**NO BLOQUEA** (el resto), más la **deuda arquitectónica**. No hay GO con un
CRITICAL/HIGH BLOCKING abierto. Solo entonces la compuerta pregunta qué aplicar; si la
persona decide no corregir, el veredicto queda como **NO-GO / riesgo asumido**.

## Veredicto por hallazgo — `veredicto.json` extendido

El esquema de `evidence-protocol.md` se extiende: cada hallazgo lleva sus tres ejes y su
evidencia enlazable.

```json
{
  "id": "P1",
  "titulo": "Acción Livewire mutadora sin authorize",
  "dominio": "autorizacion",
  "severity": "HIGH",
  "gate": "BLOCKING",
  "confidence": "CONFIRMED",
  "hard_gate": "unauthorized_mutation",
  "owasp": "API5:2023 BFLA",
  "evidence": ["app/Livewire/Commission/Edit.php:84"],
  "test_required": "CommissionAuthorizationTest::test_user_cannot_update_foreign_commission",
  "ledger_ref": "REG-014",
  "status": "OPEN"
}
```

- `hard_gate` es una de las claves de arriba, o `null`.
- `ledger_ref` enlaza con la entrada del registro de regresiones si el hallazgo es una
  regresión conocida o debe promoverse a una.
- `test_required` es lo que la Fase 5 exige para cerrar; su ausencia mantiene el hallazgo
  como `UNVERIFIED`, no `PASS`.

## Relación con Cross-Audit / Meta-Audit

El gate se calcula **después** de la Fase 2.5 (Cross-Audit + Red Team, ver
`red-team.md`), no antes. El Red Team tiene autoridad para **anular un PASS** y para
elevar una severidad subestimada: sin esa pasada, cuatro agentes pueden equivocarse de
la misma manera y el gate heredaría el error. El defecto "nada bloquea" se caza ahí.
