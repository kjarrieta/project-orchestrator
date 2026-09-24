# Pattern library — evidencia histórica de journey defects

Memoria institucional, no protocolo de ejecución. El método vive en
`references/behavioral-journey-tracing.md`; aquí están los defectos históricos que
justificaron ese método, generalizados a **seed patterns** que evolucionan con cada
post-mortem.

Uso: los auditores consultan esta biblioteca cuando necesitan **generalizar** un
sospechoso ("¿esto se parece a algo ya visto?") o **calibrar** la severidad de un
finding a la luz de casos análogos. No es lista de chequeos; los checks los dicta el
protocolo.

## Origen

Post-mortem 2026-09-24 sobre `backend-sincronizador` (Laravel + Livewire + S3 + MySQL):
24 defectos detectados por un auditor externo tras un corrida del orchestrator que los
marcó todos como `PASS`. Los archivos originales — `docs/bugs/fix identificados.md` y
`docs/bugs/fix_permisos.md` — quedaron como evidencia primaria del proyecto.

## Seed patterns (nombres cognitivos, no de artefacto)

Cada patrón se nombra por la **pregunta** que el auditor externo hizo, no por la cosa
que miró. Los patrones son los mismos 10 que el protocolo lista; aquí se documentan con
la evidencia que los originó.

### A · Contract mismatch — *¿el productor satisface el contrato del consumidor?*
- `uploadBatch = "draft-{id}"` en `mountPhotosStep()` vs `Rule: ['required','string','uuid']` en `RentalPhotoPresignController` → 422 al editar. Frontend válido, controller válido, boundary rota.
- `@can('manage-properties')` en sidebar apuntando a ruta con `middleware('permission:manage-rentals')` — ambos permisos existen, boundaries desalineadas.

### B · Invariant propagation — *¿dónde se define y dónde se aplica?*
- Trigger `rental_properties_unit_number_required_bi/bu` exige `unit_number` cuando `is_multi_unit=true`; `locationStepRules()` deja `unitNumber` `nullable` y `validateDraftFormat()` no lo exige. Wizard llega al autosave, BD rechaza, `catch(\Throwable)` presenta "No se pudo guardar el progreso".
- `snake_case` en `validateDraftFormat` vs `camelCase` en `lang/en/validation.php attributes` — el mensaje sale en spanglish, `errorBag` bajo `unit_number` no marca ningún input (todos usan `unitNumber`).

### C · Distributed atomicity — *si el paso N+1 falla, ¿qué queda?*
- `persistPendingPhotos()` mueve en S3 y limpia `pendingPhotos`/`pendingMainId` **antes** de `publish()`. `ValidationException` de requisitos hace rollback SQL pero deja S3 movido, memoria Livewire mutada y respaldo localStorage borrado por `rental-photos-committed` despachado dentro de la transacción.
- `propertyId` asignado dentro de la transacción — sobrevive al rollback apuntando a un id inexistente; `findOrFail` posterior falla.

### D · Failure-path tracing — *¿el recovery restaura demasiado o demasiado poco?*
- `recoverFromFailedPublish()` llama `fillPhotosStepFromProperty($this->property->fresh())` que reasigna `description`, `tour360Url`, `flashviewCode` con valores post-rollback — sobrescribe lo que el usuario acababa de escribir (dictado por voz) sin aviso.
- Recuperación de fotos desde `localStorage`: `uploadBatch` regenerado en cada mount + guard `str_starts_with($key, "rentals/_pending/{$this->uploadBatch}/")` rechaza siempre el respaldo de la sesión anterior; `forgetAccepted()` borra el respaldo silenciosamente.

### E · Read-after-write continuity — *¿quién consume el dato nuevo?*
- `markAsAvailable()` actualiza sólo `estado_comercial`, no pasa `updated_by`. `RentalPropertyObserver::resolveChangedBy()` se apoya en el valor previo cuando corre fuera de HTTP.
- Docblock de `toYearOrNull()` describe una guarda `strlen` que ya es `preg_match('/^\d{5,}$/')`. Consumidor del comentario (el próximo lector) lee una garantía que el código no ofrece.

### F · Authorization symmetry — *¿la visibilidad y el acceso comparten permiso?*
- Sidebar `@can('manage-properties')` + ruta `permission:manage-rentals` — un rol con sólo `manage-rentals` no ve el enlace; uno con sólo `manage-properties` recibe 403.
- `AmenityCatalogModal::save()` escribe en `rental_features` sin ningún guard mientras el resto del módulo (Index, Detail, RentalSettings…) sí lo tiene.
- `validateImages()` que reemplaza `getMimeType()` real por `getClientOriginalExtension()` — la autorización de tipo de archivo pasa a controlarse por dato del cliente.

### G · Mechanism presence vs coverage — *¿qué operación protege realmente el mecanismo?*
- `lockForUpdate()` en `KeysLocations::add/saveEditing/remove/setActive` sin `DB::transaction` envolvente — con autocommit MySQL libera el lock al terminar el SELECT; el UPDATE va sin protección.
- `catch(\Throwable) { Log::error(…) }` en el loop de upsert de chunks + `Log::info('✅ Sincronización completada')` al final. El mecanismo (catch) existe; no cubre la operación (surfaced failure).
- `ini_set('memory_limit', '512M')` sin `ini_get` previo — el mecanismo (subir límite) es correcto en intención; en un worker con `-1` lo *baja*.

### H · State-machine completeness — *¿UI, service, constraint y efecto coinciden en las transiciones?*
- `publish()` sólo valida `estado_publicacion`; CHECK `rental_properties_no_publicado_arrendado_check` prohíbe `publicado + arrendado`; `detail.blade.php` muestra el botón "Publicar" ignorando `estado_comercial`. Flujo publicar → arrendar → volver a publicar = QueryException al usuario.
- `Detail::$property` público con relaciones filtradas por closure en `loadProperty()` — Livewire re-hidrata sin closures; cambiar de pestaña reabre fotos con `is_active=false` y el historial completo en vez de los últimos 20.

### I · Sibling consistency — *¿existe otro código que resuelve esto con reglas distintas?*
- `dateRange` no resetea paginación mientras `captadorIds/officeIds/useTypeIds` sí (via `updatedX()`).
- `initRentalMapView()` maneja `lat===null||undefined`; la función hermana usa `lat && lng` (falla en cero).
- `MlsPhotoUploadService::uploadOwnerPhotos()` deja de pasar overrides mientras el flujo de arrendamiento sigue con `validateTempObject()` (magic bytes) — dos flujos, dos garantías.

### J · Change vs ecosystem — *¿la infraestructura acompaña el uso previsto?*
- `runQueueNow()` invoca `Artisan::call('queue:work',…)` dentro de un request Livewire — el ecosistema (PHP-FPM, proxy, ausencia de pcntl para respetar `--timeout`) no soporta ese uso; el proceso muere reservado.
- `Telescope::filter(fn () => true)` elimina el filtro por entorno + falta programar `telescope:prune` — la infra (dev-deps en staging) no soporta grabar todo sin poda.
- Migración `2026_09_22_161441_make_company_id_nullable_on_rental_properties_table` hace `MODIFY` sobre columna que declara otro módulo (`multicompania_cimientos`) con `down()` no-op — el ecosistema de módulos no la soporta.
- `phpunit.xml` con `DB_DATABASE=aa_bakend_2_test` hardcoded — el ecosistema CI/otras máquinas no la tiene.

## Cómo evoluciona esta biblioteca

- Nuevo post-mortem → clasificar cada hallazgo en A–J; si no encaja, se propone patrón K
  (o L, M…) y se sube al protocolo con evidencia.
- Los ejemplos históricos se conservan; no se borran cuando el bug se arregla. Son el
  material de calibración para futuros auditores.
- No se listan aquí instancias que sean simplemente "otra vez el mismo patrón A" —
  bastan 2–3 ejemplos por patrón para transmitirlo. Si una instancia añade un ángulo
  nuevo, entra; si sólo confirma, no.
