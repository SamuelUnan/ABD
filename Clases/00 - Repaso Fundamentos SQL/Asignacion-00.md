# Asignación 00 · Concesionario — Fundamentos de Llaves y Restricciones SQL

## 1. Contexto

La base de datos **Concesionario** inicia su construcción en el esquema `dbo`. Se crean las tablas de catálogo requeridas.

## 2. Tareas

- [ ] **T1.** Crear la base de datos `Concesionario`.
- [ ] **T2.** Crear la tabla `Marca` con:
  - Definición de Llaves Unicas.
  - Validación de columnas NOT NULL.
- [ ] **T3.** Crear la tabla `Modelo` con:
  - Llave Foránea a la Tabla `Marca`.
  - Definición de Llave Compuesta entre el Id y la Marca,
  - Validación de Rango de Años Validos.
  - Definición de Validación de Precio Base.
- [ ] **T4.** Crear la tabla `Vehiculo` con:
  - Definición de Llaves Unicas.
  - Validación del Campo Kilometraje.
  - Validación de Estados Posibles (`Disponible`, `Cotizado`, `Vendido`, `Entregado`).
  - Definición de un estado por Defecto.
- [ ] **T5.** Crear tabla `Accesorio` con:
  - Validación de Campos Unicos.
  - Validación del campo Precio.
- [ ] **T6.** Crear  tabla `Categoria` con:
  - Definición de Llaves Unicas.
- [ ] **T7.** Crear tabla `Repuesto` con:
  - Llave Foránea a la Tabla `Categoria`.
  - Definición de un stock por Defecto.
  - Validación de los campos Stock y Precio.
- [ ] **T8.** Crear tabla `Sucursal` con:
  - Validación de Campos Unicos.
- [ ] **T9.** Crear tabla `Cliente` con:
  - Validación de Campos Unicos.
  - Definición de Fecha por Defecto.
- [ ] **T10.** Crear tabla `Empleado` con:
  - Llave Foránea a la Tabla `Sucursal`.
  - Definición de un Jefe para el empleado (Llave Recursiva).
  - Validación del Salario del Empleado.

## 3. Resultado esperado

- 9 tablas creadas en `dbo`.
- Cada tabla con **todas sus restricciones** nombradas explicitamente (`pk_`, `fk_`, `uq_`, `ck_`, `df_`).
- Consulta de catálogo que muestre tablas y sus restricciones, verificando los nombres (Consultar [`AuxiliaryScript.sql`](../AuxiliaryScript.sql)).
- Un INSERT inicial de prueba en `Marca` y `Cliente` (datos semilla mínimos).