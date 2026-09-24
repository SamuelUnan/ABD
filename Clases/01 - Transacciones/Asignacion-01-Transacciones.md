# Asignación 01 · Concesionario — Transacciones y Manejo de Errores

## 1. Objetivo

Construir las tablas del **ciclo de venta** (recepción → cotización → facturación/matriculación/entrega) y crear los **procedimientos** que ejecuten cada etapa garantizando que los cambios se apliquen por completo o no se apliquen en absoluto (con control de errores).

## 2. Contexto

La base de datos Concesionario ya tiene las tablas base del tema 00 (Marca, Modelo, Vehiculo, Cliente, Empleado, Sucursal, Accesorio, Categoria, Repuesto). Ahora se agrega el flujo comercial completo, aún en `dbo`.

## 3. Tareas

- [ ] **T1.** Crear la tabla `Visita` (etapa de recepción y atención) con:
  - Vínculo al Cliente, Empleado y Sucursal.
  - Fecha por defecto.
  - Validación del estado.
- [ ] **T2.** Crear las tablas de cotización (etapa de cotización y negociación):
  - `Cotizacion` con número único, vínculo al Cliente, Empleado, Sucursal y Vehiculo; montos mayores que cero, descuento no negativo, validación del estado y valores por defecto.
  - `CotizacionRevision` para el historial de precios negociados.
  - `CotizacionAccesorio` que vincule cada cotización con sus accesorios (una combinación única de cotización y accesorio).
  - `Financiamiento` con el plan opcional (inicial, plazo, tasa, cuota) y su validación de estado.
  - `Retoma` con los datos del vehículo usado entregado como parte de pago, sin incorporarlo al inventario.
- [ ] **T3.** Crear las tablas de facturación (etapa de facturación, matriculación y entrega):
  - `Factura` con número único, vínculo a la cotización y al Cliente, Empleado, Sucursal y Vehiculo; validación del estado y del método de pago.
  - `Pago` con monto mayor que cero, método de pago y referencia.
  - `Matriculacion` con placa única, fecha y entidad.
  - `Entrega` con persona que recibe, observaciones y estado.
- [ ] **T4.** Crear la tabla de registro de errores para que los procedimientos dejen constancia cuando algo falla.
- [ ] **T5.** Crear el procedimiento que registra la cotización:
  - Valida que el vehículo esté `Disponible`.
  - Calcula el subtotal, el impuesto (15%) y el total con descuento.
  - Inserta la cotización, deja el historial inicial de precios y marca el vehículo como `Cotizado`.
  - Todo en un solo proceso que se revierta completo si falla y que deje constancia en el registro de errores.
- [ ] **T6.** Crear el procedimiento que factura la venta:
  - Valida que la cotización exista, esté `Aprobada` y que el vehículo esté `Cotizado`.
  - Emite la factura, registra el pago y crea la matriculación.
  - Actualiza la cotización a `Facturada` y el vehículo a `Vendido`.
  - Todo en un solo proceso: si falla cualquier paso, no queda ningún cambio parcial.
- [ ] **T7.** Crear el procedimiento de entrega: registra la `Entrega` y actualiza el vehículo a `Entregado`.
- [ ] **T8.** Probar casos de éxito y casos de error que reviertan el proceso sin dejar cambios parciales.

## 4. Resultado esperado

- 10 tablas del flujo comercial + registro de errores en `dbo`.
- 3 procedimientos que solo aplican cambios si todo el proceso es correcto.
- Ejecución de una venta completa de principio a fin:
  1. Cotizar (vehículo → `Cotizado`)
  2. Aprobar cotización (actualización manual)
  3. Facturar (vehículo → `Vendido`)
  4. Entregar (vehículo → `Entregado`)
- Prueba negativa: intentar facturar una cotización `Pendiente` y comprobar que no queda ningún cambio parcial.