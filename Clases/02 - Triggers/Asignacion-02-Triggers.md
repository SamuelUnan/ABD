# Asignación 02 · Concesionario — Triggers DML

## 1. Objetivo

Agregar **disparadores automáticos** al proceso de ventas para auditar las operaciones sobre `Factura` y `Cotizacion`, y validar los estados del ciclo de vida del vehículo desde la base de datos.

## 2. Contexto

La base de datos ya cuenta con las tablas del ciclo comercial y los procedimientos que manejan transacciones (tema 01). Ahora se agregan los disparadores. La tabla de auditoría no existe aún y se crea en esta asignación.

## 3. Tareas

- [ ] **T1.** Crear la tabla `LogAuditoria` en `dbo` con:
  - Registro de la tabla afectada, la operación realizada (`INSERT`/`UPDATE`/`DELETE`) y el identificador del registro.
  - Usuario y fecha que se llenen automáticamente.
  - Columnas para guardar el estado de los datos antes y después del cambio.
- [ ] **T2.** Crear el disparador que se ejecuta **después de** la operación sobre `Factura` y registre en `LogAuditoria` todo `INSERT`, `UPDATE` y `DELETE`.
- [ ] **T3.** Crear el disparador que audite los **cambios de estado** de `Cotizacion` (Pendiente → Aprobada → Facturada), guardando el estado anterior y el nuevo.
- [ ] **T4.** Crear el disparador que se ejecuta **en lugar de** la inserción en `Factura`:
  - Rechace la inserción si el vehículo no está en estado `Cotizado`.
  - Si la validación pasa, permita la inserción real.
- [ ] **T5.** Probar los disparadores:
  - Insertar una factura validando que `LogAuditoria` se llene automáticamente.
  - Intentar insertar una factura con un vehículo en estado incorrecto (debe rechazarse sin crear la fila).

## 4. Resultado esperado

- 1 tabla de auditoría + 3 disparadores en `dbo`.
- Cualquier operación sobre `Factura` deja rastro automático en `LogAuditoria`.
- La inserción de factura queda protegida a nivel de base de datos (incluso si se omite la validación del procedimiento).