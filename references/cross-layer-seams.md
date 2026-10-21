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

Post-mortem 2026-09-24 sobre `ese proyecto` (Laravel + Livewire + S3 + MySQL):
24 defectos detectados por un auditor externo tras un corrida del orchestrator que los
marcó todos como `PASS`. Los archivos originales — `docs/bugs/fix identificados.md` y
`docs/bugs/fix_permisos.md` — quedaron como evidencia primaria del proyecto.

## Seed patterns (nombres cognitivos, no de artefacto)

Cada patrón se nombra por la **pregunta** que el auditor externo hizo, no por la cosa
que miró. Los patrones son los mismos 11 que el protocolo lista; aquí se documentan con
la evidencia que los originó.

### A · Contract mismatch — *¿el productor satisface el contrato del consumidor?*
- `uploadBatch = "draft-{id}"` en `mountPhotosStep()` vs `Rule: ['required','string','uuid']` en `RentalPhotoPresignController` → 422 al editar. Frontend válido, controller válido, boundary rota.
- `@can('manage-properties')` en sidebar apuntando a ruta con `middleware('permission:manage-rentals')` — ambos permisos existen, boundaries desalineadas.
- Verificación de migración `000007`: la línea base se calcula con `getCodesInVariantSpace()` (filtra solo por `zone_id`/`sector_id`) y el estado posterior con `getFilteredCodes()` → `applyAliasFilterAdmin()`, que añade un fallback por nombre (`ILIKE canonical_name`) que la línea base no tiene. Comparación por hash exacto entre dos conjuntos calculados con reglas distintas → la migración puede lanzar `RuntimeException` y bloquear el deploy. Ángulo nuevo: contract mismatch dentro de un *gate de verificación de deploy* (antes/después de una migración), no entre capas de request↔service.

### B · Invariant propagation — *¿dónde se define y dónde se aplica?*
- Trigger `rental_properties_unit_number_required_bi/bu` exige `unit_number` cuando `is_multi_unit=true`; `locationStepRules()` deja `unitNumber` `nullable` y `validateDraftFormat()` no lo exige. Wizard llega al autosave, BD rechaza, `catch(\Throwable)` presenta "No se pudo guardar el progreso".
- `snake_case` en `validateDraftFormat` vs `camelCase` en `lang/en/validation.php attributes` — el mensaje sale en spanglish, `errorBag` bajo `unit_number` no marca ningún input (todos usan `unitNumber`).
- `upsertVariantWithAlias()` siempre llama `resolveOrCreateAliasForAttributes()` (busca por `slug(name)` + padre) y pisa `alias_id` aunque la variante ya tenga uno asignado. El patrón anterior (`resolveForVariant`) devolvía el `alias_id` vigente si la variante ya lo tenía. Invariante "una asignación humana (merge/assign/rename) es autoritativa sobre la re-resolución automática" — se definía en la función reemplazada y se perdió al escribir la nueva; cada sync revierte la gobernanza del admin. Ángulo nuevo: el invariante **regresiona** al reemplazar una función, no es que nunca haya existido.

### C · Distributed atomicity — *si el paso N+1 falla, ¿qué queda?*
- `persistPendingPhotos()` mueve en S3 y limpia `pendingPhotos`/`pendingMainId` **antes** de `publish()`. `ValidationException` de requisitos hace rollback SQL pero deja S3 movido, memoria Livewire mutada y respaldo localStorage borrado por `rental-photos-committed` despachado dentro de la transacción.
- `propertyId` asignado dentro de la transacción — sobrevive al rollback apuntando a un id inexistente; `findOrFail` posterior falla.
- `revertMerge()` reescribe A→B en los filtros que apuntaban al origen, pero al revertir no distingue si el destino ya estaba en la lista antes de la fusión ni si otro origen (`C`) se fusionó después en el mismo destino — el snapshot `before` que sí tiene esa información no se usa. `merge()` recursivo tampoco migra las referencias de los hijos que se fusionan en cascada; quedan huérfanas. Ángulo nuevo: no es un punto de fallo del happy path — es una operación de **reversión/undo** que sólo deshace un subconjunto de lo que la operación directa mutó.

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
- `goToStep()` del wizard llama `persistCurrent()` sin `$this->authorize('update', $this->case)`, mientras `next()` y `saveDraft()` sí autorizan antes de persistir. Un usuario de solo lectura (`view` sin `update`) guarda datos del paso 1 al navegar el sidebar. Ángulo nuevo: la guardia falta en un entry point del mismo wizard, no en una ruta o menú distinto.

### G · Mechanism presence vs coverage — *¿qué operación protege realmente el mecanismo?*
- `lockForUpdate()` en `KeysLocations::add/saveEditing/remove/setActive` sin `DB::transaction` envolvente — con autocommit MySQL libera el lock al terminar el SELECT; el UPDATE va sin protección.
- `catch(\Throwable) { Log::error(…) }` en el loop de upsert de chunks + `Log::info('✅ Sincronización completada')` al final. El mecanismo (catch) existe; no cubre la operación (surfaced failure).
- `ini_set('memory_limit', '512M')` sin `ini_get` previo — el mecanismo (subir límite) es correcto en intención; en un worker con `-1` lo *baja*.
- `SyncMobiliaService::execute()`/`SyncMobiliaJwtService::execute()` envuelven el sync de catálogos maestros en `safeExecute()` (atrapa, loguea, devuelve `null`) — pero `SyncCityZone::execute()`/`SyncZoneSector::execute()` ya lanzan `RuntimeException` A PROPÓSITO, con comentario propio ("el caller/job debe enterarse para no marcar exito"). El mecanismo de propagación existe en el callee; el wrapper genérico del caller no lo conoce y lo ahoga igual. Ángulo distinto al ejemplo del catch en loop de arriba: aquí el "mecanismo que no cubre" es un helper compartido y reusado (`HandlesServiceErrors`), no un catch local — la brecha vive en el sitio de llamada, no en quien lanza.
- `WithoutOverlapping(releaseAfter: 30)` + `tries = 3` en el job de filtros: cada liberación del lock consume un intento de reintento. Si un segundo job del mismo dominio llega mientras el primero sigue corriendo (hasta 300 s de timeout), se libera cada 30 s y a los ~90 s se agotan los `tries` — el job termina en `failed()` sin haber aplicado los filtros, sin excepción de negocio ni log de error visible como tal. Ángulo nuevo: no es código de aplicación (catch/lock explícito) sino la interacción entre **dos parámetros de infraestructura de colas** (cadencia de release y presupuesto de reintentos) que se anulan en silencio.

### H · State-machine completeness — *¿UI, service, constraint y efecto coinciden en las transiciones?*
- `publish()` sólo valida `estado_publicacion`; CHECK `rental_properties_no_publicado_arrendado_check` prohíbe `publicado + arrendado`; `detail.blade.php` muestra el botón "Publicar" ignorando `estado_comercial`. Flujo publicar → arrendar → volver a publicar = QueryException al usuario.
- `Detail::$property` público con relaciones filtradas por closure en `loadProperty()` — Livewire re-hidrata sin closures; cambiar de pestaña reabre fotos con `is_active=false` y el historial completo en vez de los últimos 20.
- El pillbox nuevo de estado comercial en el filtro de arriendos solo ofrece `disponible` y `arrendado`; el filtro anterior también tenía `no_disponible` (borradores y retirados manuales). Regresión: un valor válido del enum `EstadoComercial` deja de estar representado en la UI, y ese subconjunto de inmuebles ya no se puede listar. Ángulo nuevo: no es una transición prohibida por un CHECK, es una **opción de enum que desaparece** al reescribir el control de filtro.

### I · Sibling consistency — *¿existe otro código que resuelve esto con reglas distintas?*
- `dateRange` no resetea paginación mientras `captadorIds/officeIds/useTypeIds` sí (via `updatedX()`).
- `initRentalMapView()` maneja `lat===null||undefined`; la función hermana usa `lat && lng` (falla en cero).
- `MlsPhotoUploadService::uploadOwnerPhotos()` deja de pasar overrides mientras el flujo de arrendamiento sigue con `validateTempObject()` (magic bytes) — dos flujos, dos garantías.
- `SyncMobiliaPropertyService::execute()` (sync clásico) resuelve el safety net de alias de `city`/`propertyType` UNA VEZ, fuera del loop de propiedades, porque son invariantes del batch; `SyncMobiliaJwtPropertyService` — escrito después como el "gemelo JWT" del mismo dominio — repetía la misma resolución dentro del loop por cada propiedad, sin refrescar en memoria el resultado. El hermano correcto ya existía en el mismo módulo; el nuevo no heredó su patrón al clonarlo.
- El filtro `activate` de rental hace un `UPDATE` masivo `retirado → publicado` directo sobre la query, saltándose `RentalPropertyService::publish()` — que valida requisitos de publicación (campos obligatorios, propietario, ambientes, fotos), bloquea la fila y registra `updated_by`. El flujo manual (un registro a la vez) y el flujo de filtro en lote (`activate`) resuelven "marcar como publicado" con reglas distintas. Ángulo nuevo: el hermano no es otro archivo del mismo dominio, es una **acción en lote vs. la misma acción de un solo registro** dentro del mismo servicio.

### J · Change vs ecosystem — *¿la infraestructura acompaña el uso previsto?*
- `runQueueNow()` invoca `Artisan::call('queue:work',…)` dentro de un request Livewire — el ecosistema (PHP-FPM, proxy, ausencia de pcntl para respetar `--timeout`) no soporta ese uso; el proceso muere reservado.
- `Telescope::filter(fn () => true)` elimina el filtro por entorno + falta programar `telescope:prune` — la infra (dev-deps en staging) no soporta grabar todo sin poda.
- Migración `2026_09_22_161441_make_company_id_nullable_on_rental_properties_table` hace `MODIFY` sobre columna que declara otro módulo (`multicompania_cimientos`) con `down()` no-op — el ecosistema de módulos no la soporta.
- `phpunit.xml` con `DB_DATABASE=aa_bakend_2_test` hardcoded — el ecosistema CI/otras máquinas no la tiene.

### K · Empty-value ambiguity — *¿esta representación vacía significa "sin restricción/sin dato" o "restringe a nada/requisito no resuelto", y coinciden ambos lados del boundary en cuál?*

Post-mortem 2026-09-29 (app-saas, AA-backend-laravel): un auditor externo encontró tres
instancias del mismo defecto en dos proyectos distintos, ninguna capturada por A–J. El
defecto: un array vacío, una clave ausente o una colección sin filas se usa para
significar dos cosas opuestas según quién lo lea, y nada en el código las distingue.

- `CreateNodeOrCaseCommand`: `address['formatted']` se asigna siempre (aunque sea a
  `null`) antes de que `CaseService::registerNode()` evalúe `!empty($input['address'])`.
  El array nunca queda realmente vacío, así que la unidad geocodifica y crea una
  dirección `main` vacía en vez de heredar la del contenedor — el chequeo de "sin
  dirección" nunca puede ser verdadero.
- `ParticipantRequiredRule`: los campos obligatorios del propietario salen de un
  `foreach` sobre requisitos `contacts.*` del catálogo `acquisition_requirements`. Si el
  catálogo no tiene esas filas (tenant sin seed, requisitos desactivados), el `foreach`
  no itera y la regla devuelve `true` con cualquier contacto — "sin filas que validar"
  se interpreta como "nada que exigir" en vez de "no se puede validar, bloquear".
- `mobilia_sync_filters`: al borrar el último alias de una lista de filtro,
  `migrateSyncFilterAliasReferences()` deja `filters['cities'] = []`.
  `applyAliasFilterAdmin()` trata la lista vacía como "sin restricción" y el `UPDATE`
  se aplica a todo el inventario — antes de este cambio, un id huérfano producía
  `whereRaw('1 = 0')` (restringe a nada). La misma representación (`[]`) pasó de
  significar "bloquea todo" a significar "no filtres nada".

Señales de detección: un `!empty()`/`isset()` sobre un array que el productor llena con
al menos una clave interna aunque el "valor real" esté ausente; un `foreach`/`map` cuyo
cuerpo es la única fuente de una regla de negocio y que "aprueba por default" cuando no
itera; una lista que puede llegar vacía por dos caminos distintos (nunca tuvo valor /
se quedó sin el último valor) tratada igual en el consumidor. Pregunta de auditoría:
para cada valor vacío que cruza un boundary, ¿"vacío" significa lo mismo para quien lo
escribió y para quien lo lee?

## Cómo evoluciona esta biblioteca

- Nuevo post-mortem → clasificar cada hallazgo en A–K; si no encaja, se propone patrón L
  (o M, N…) y se sube al protocolo con evidencia.
- Los ejemplos históricos se conservan; no se borran cuando el bug se arregla. Son el
  material de calibración para futuros auditores.
- No se listan aquí instancias que sean simplemente "otra vez el mismo patrón A" —
  bastan 2–3 ejemplos por patrón para transmitirlo. Si una instancia añade un ángulo
  nuevo, entra; si sólo confirma, no.
