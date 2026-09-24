# Asignación 03 · Concesionario — Esquemas y Organización de Objetos

## 1. Objetivo

**Clasificar** los objetos de la base Concesionario en **esquemas** según su área funcional, moviendo las tablas desde `dbo` hacia los esquemas del modelo y actualizando las dependencias (procedimientos y disparadores) para que las referencias apunten a los objetos en su nuevo esquema.

## 2. Contexto

Todas las tablas creadas en los temas 00–02 viven en `dbo`. Ahora se reorganizan en los esquemas planificados:

| Esquema | Tablas |
|---------|--------|
| `catalogo` | Marca, Modelo, Vehiculo, Accesorio |
| `personas` | Cliente, Empleado |
| `visitas` | Visita |
| `ventas` | Cotizacion, CotizacionRevision, CotizacionAccesorio, Financiamiento, Retoma, Factura, Pago, Matriculacion, Entrega |
| `inventario` | Categoria, Repuesto |
| `auditoria` | LogAuditoria |
| `config` | (se crea tabla en tema 05) |
| `ubicacion` | Sucursal |

## 3. Tareas

- [ ] **T1.** Crear los 8 esquemas: `catalogo`, `personas`, `visitas`, `ventas`, `inventario`, `auditoria`, `config`, `ubicacion`.
- [ ] **T2.** Consultar el catálogo de la base de datos para ver los esquemas existentes y los objetos de cada uno.
- [ ] **T3.** Mover de `dbo` a su esquema correspondiente cada tabla listada en el contexto.
- [ ] **T4.** Actualizar los disparadores para que sus referencias apunten a los objetos en su nuevo esquema.
- [ ] **T5.** Actualizar los procedimientos del tema 01 para que las referencias apunten a los objetos en su nuevo esquema.
- [ ] **T6.** Verificar que el flujo completo de venta siga funcionando tras la reorganización.

## 4. Resultado esperado

- 20 tablas clasificadas en sus esquemas (ninguna queda en `dbo`, salvo la tabla `LogErrores` y los procedimientos, que se documentan como objetos de aplicación).
- Disparadores y procedimientos actualizados con sus referencias a los nuevos esquemas.
- Consulta de catálogo que muestre la clasificación final.
- Una ejecución de prueba del flujo (cotizar → facturar → entregar) sin errores.