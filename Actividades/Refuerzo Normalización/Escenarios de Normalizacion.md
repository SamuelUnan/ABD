# Estaciones

## Escenario 1 — Consultorio médico (Transaccional)

### Contexto del escenario

Un consultorio de atención primaria gestiona sus pacientes y el proceso de atención médica. Un paciente puede tener uno o más teléfonos de contacto. El médico tiene una especialidad fija y atiende siempre en un mismo consultorio. Durante una consulta, el médico registra el diagnóstico y puede indicar **0..n medicamentos** (cada uno con su dosis) y ordenar **0..n pruebas de laboratorio** (cada una con su resultado). Una cita atendida puede **generar una reconsulta** (nueva cita). El historial de estados de la cita debe quedar trazable.

### Flujo variable del proceso

```
SOLICITADA ──▶ PROGRAMADA ──▶ EN CONSULTA ──▶ ATENDIDA
                    │              │              │
                    │              │              ├─▶ (opcional) LABORATORIO  → 0..n pruebas (resultado)
                    │              │              └─▶ (opcional) RECETA       → 0..n medicamentos (dosis)
                    ├─▶ CANCELADA  │              └─▶ (opcional) RECONSULTA   → genera nueva cita
                    └─▶ NO_ASISTIÓ │
                                   └─▶ (se cancela o re-programa)
```

**Cardinalidades variables a observar:** teléfonos 1..3 → 1..n · medicamentos 0..n · pruebas 0..n · reconsultas 0..n.

### Estructura desnormalizada

```
CITA (tabla única)
┌──────────────────────────────────────────────────────────────────┐
│ id_cita, fecha, hora, estado                                     │
│ nombre_paciente, telefono_1, telefono_2, telefono_3    ← repetidos│
│ medico, especialidad, consultorio                       ← transitivo│
│ diagnostico                                                       │
│ medicamento_1, dosis_1, medicamento_2, dosis_2,          ← repetidos│
│ medicamento_3, dosis_3                                             │
│ prueba_1, resultado_1, prueba_2, resultado_2             ← repetidos│
└──────────────────────────────────────────────────────────────────┘
```

### T-SQL de partida (no normalizado)

```sql
CREATE TABLE dbo.Cita(
    id_cita          INT IDENTITY PRIMARY KEY,
    fecha            DATE NOT NULL,
    hora             TIME NOT NULL,
    estado           VARCHAR(20) NOT NULL DEFAULT 'PROGRAMADA',
    nombre_paciente  VARCHAR(80) NOT NULL,
    telefono_1       VARCHAR(20),
    telefono_2       VARCHAR(20),
    telefono_3       VARCHAR(20),
    medico           VARCHAR(80) NOT NULL,
    especialidad     VARCHAR(50) NOT NULL,
    consultorio      VARCHAR(20) NOT NULL,
    diagnostico      VARCHAR(500),
    medicamento_1    VARCHAR(50),  dosis_1 VARCHAR(50),
    medicamento_2    VARCHAR(50),  dosis_2 VARCHAR(50),
    medicamento_3    VARCHAR(50),  dosis_3 VARCHAR(50),
    prueba_1         VARCHAR(50),  resultado_1 VARCHAR(50),
    prueba_2         VARCHAR(50),  resultado_2 VARCHAR(50)
);

INSERT INTO dbo.Cita (fecha, hora, estado, nombre_paciente, telefono_1, telefono_2, telefono_3,
    medico, especialidad, consultorio, diagnostico,
    medicamento_1, dosis_1, medicamento_2, dosis_2,
    prueba_1, resultado_1)
VALUES
('2026-08-07', '08:30', 'ATENDIDA', 'Ana Lopez',   '8888-1111', '8888-1112', NULL,
 'Dra. Rivas', 'Medicina General', 'C01', 'Rinitis aguda',
 'Loratadina', '10 mg c/24h', 'Salbutamol', 'Inhalador c/8h',
 'Hemograma', 'Dentro de parametros'),
('2026-08-07', '09:00', 'PROGRAMADA', 'Luis Mendez', '7777-2222', NULL, NULL,
 'Dr. Herrera', 'Cardiologia', 'C02', NULL,
 NULL, NULL, NULL, NULL,
 NULL, NULL),
('2026-08-07', '09:30', 'EN CONSULTA', 'Sofia Castro', '6666-3333', '6666-3334', '6666-3335',
 'Dra. Rivas', 'Medicina General', 'C01', 'Sospecha de gastritis',
 'Omeprazol', '20 mg c/24h', NULL, NULL,
 'Endoscopia', 'En espera');
```

### Tareas a realizar

1. Identifica las dependencias funcionales del esquema y las claves candidatas.
3. Normaliza 1FN → 2FN → 3FN indicando la anomalía que se elimina en cada paso.
4. Dibuja el modelo E-R normalizado (entidades, claves, cardinalidades).

---

## Escenario 2 — Biblioteca (Transaccional)

### Contexto del escenario

La biblioteca gestiona socios, títulos y ejemplares. Un título puede tener **varios autores** y pertenecer a una editorial (con su dirección). Cada título posee **1..n ejemplares** con código físico. El flujo del préstamo inicia con una **reserva** (opcional), sigue con el préstamo, admite **0..n renovaciones** (cada una desplaza la fecha de devolución), y termina en **devuelto**, **en mora** o **perdido**. Si la devolución ocurre con atraso, se **calcula una multa** por días. El socio tiene datos de contacto repetidos en cada préstamo.

### Flujo variable del proceso

```
RESERVADO ──▶ PRESTADO ──▶ RENOVADO (0..n) ──▶ DEVUELTO
    │             │              │                 │
    │             │              │                 └─▶ (si atraso) MULTA calculada
    │             │              └─▶ EN MORA        └─▶ (opcional) PRORROGA a RESERVADO
    └─▶ (vence reserva, se libera ejemplar)
                   └─▶ PERDIDO (se genera multa por reposición)
```

**Cardinalidades variables a observar:** autores 1..n por título · ejemplares 1..n por título · renovaciones 0..n · reserva 0..1.

### Estructura desnormalizada

```
PRESTAMO (tabla única)
┌──────────────────────────────────────────────────────────────────┐
│ id_prestamo, fecha_prestamo, fecha_devolucion, estado             │
│ socio, direccion, telefono                              ← repetidos│
│ titulo, autores (lista separada por ";")                 ← multivaluado│
│ editorial, editorial_direccion                           ← transitivo│
│ ejemplar_codigo                                                   │
│ renovacion_1, renovacion_2, renovacion_3                 ← repetidos│
│ dias_atraso, monto_multa                                 ← calculados│
└──────────────────────────────────────────────────────────────────┘
```

### T-SQL de partida (no normalizado)

```sql
CREATE TABLE dbo.Prestamo(
    id_prestamo       INT IDENTITY PRIMARY KEY,
    fecha_prestamo    DATE NOT NULL,
    fecha_devolucion  DATE NOT NULL,
    estado            VARCHAR(15) NOT NULL,
    socio             VARCHAR(80) NOT NULL,
    direccion         VARCHAR(120) NOT NULL,
    telefono          VARCHAR(20) NOT NULL,
    titulo            VARCHAR(120) NOT NULL,
    autores           VARCHAR(200) NOT NULL,
    editorial         VARCHAR(60) NOT NULL,
    editorial_direccion VARCHAR(120) NOT NULL,
    ejemplar_codigo   VARCHAR(15) NOT NULL,
    renovacion_1      DATE,
    renovacion_2      DATE,
    renovacion_3      DATE,
    dias_atraso       INT,
    monto_multa       DECIMAL(10,2)
);

INSERT INTO dbo.Prestamo (fecha_prestamo, fecha_devolucion, estado, socio, direccion, telefono,
    titulo, autores, editorial, editorial_direccion, ejemplar_codigo, renovacion_1)
VALUES
('2026-07-20', '2026-08-03', 'DEVUELTO', 'Carlos Ruiz', 'Del parque 1 cuadra al norte', '8888-0001',
 'Fundamentos de BD', 'Silberschatz;Korth;Sudarshan', 'McGraw-Hill', 'Av. Central 500',
 'BD-001', '2026-07-27'),
('2026-07-25', '2026-08-08', 'EN MORA', 'Maria Solis', 'Bo. La Paz, casa 12', '8888-0002',
 'Algoritmos', 'Cormen', 'MIT Press', 'Cambridge, MA', 'ALG-002', NULL),
('2026-07-28', '2026-08-11', 'PRESTADO', 'Pedro Vega', 'Col. El Progreso 8', '8888-0003',
 'Bases de Datos Avanzadas', 'Elmasri;Navathe', 'Pearson', 'Calle 9, Madrid',
 'BD-003', '2026-08-04');
```

### Tareas a realizar

1. Identifica las dependencias funcionales del esquema y las claves candidatas.
3. Normaliza 1FN → 2FN → 3FN indicando la anomalía que se elimina en cada paso.
4. Dibuja el modelo E-R normalizado (entidades, claves, cardinalidades).
---

## Escenario 3 — Almacén (Transaccional)

### Contexto del escenario

El almacén administra productos por **lotes** (con fecha de vencimiento) distribuidos en **varias ubicaciones**. El flujo del stock: la mercadería se **recibe** de un proveedor, se **ubica**, puede **trasladarse entre ubicaciones** (traspaso), quedar **disponible**, **reservarse** para despacho y finalmente **despacharse**. De forma variable pueden ocurrir **mermas** (por vencimiento, aplicación de FEFO), **devoluciones al proveedor** y **ajustes por conteo físico**. El proveedor repite sus datos en cada movimiento. Un producto puede estar en 1..n ubicaciones.

### Flujo variable del proceso

```
RECIBIDO ──▶ UBICADO ──▶ EN_TRANSITO (traspaso origen→destino) ──▶ DISPONIBLE
   │          │                                                   │
   │          └─▶ DISPONIBLE ──▶ RESERVADO ──▶ DESPACHADO          │
   │                                                            │
   └─▶ (opcional) DEVUELTO_PROVEEDOR                             ├─▶ (opcional) MERMA (FEFO/vencimiento)
                                                                  └─▶ (opcional) AJUSTE (conteo físico)
```

**Cardinalidades variables a observar:** 1..n ubicaciones por producto-lote · traspasos 0..n · mermas/ajustes/devoluciones 0..n.

### Estructura desnormalizada

```
MOVIMIENTO (tabla única)
┌──────────────────────────────────────────────────────────────────┐
│ id_mov, fecha, tipo, estado                                      │
│ producto, descripcion, categoria, unidad                         │
│ proveedor, proveedor_telefono                          ← transitivo│
│ lote, fecha_vencimiento                                          │
│ ubicacion_1, ubicacion_2, ubicacion_3                   ← repetidos│
│ cantidad                                                        │
└──────────────────────────────────────────────────────────────────┘
```

### T-SQL de partida (no normalizado)

```sql
CREATE TABLE dbo.Movimiento(
    id_mov             INT IDENTITY PRIMARY KEY,
    fecha              DATE NOT NULL,
    tipo               VARCHAR(20) NOT NULL,
    estado             VARCHAR(15) NOT NULL,
    producto           VARCHAR(80) NOT NULL,
    descripcion        VARCHAR(120),
    categoria          VARCHAR(40),
    unidad             VARCHAR(10) NOT NULL,
    proveedor          VARCHAR(80),
    proveedor_telefono VARCHAR(20),
    lote               VARCHAR(20),
    fecha_vencimiento  DATE,
    ubicacion_1        VARCHAR(15),
    ubicacion_2        VARCHAR(15),
    ubicacion_3        VARCHAR(15),
    cantidad           INT NOT NULL
);

INSERT INTO dbo.Movimiento (fecha, tipo, estado, producto, descripcion, categoria, unidad,
    proveedor, proveedor_telefono, lote, fecha_vencimiento, ubicacion_1, ubicacion_2, cantidad)
VALUES
('2026-08-01', 'RECEPCION', 'UBICADO', 'Arroz 25 kg', 'Arroz blanco premium', 'Grano basico', 'saco',
 'AgroSur', '2222-3333', 'L2026-08', '2027-08-01', 'A-01', 'A-02', 120),
('2026-08-02', 'DESPACHO', 'DESPACHADO', 'Arroz 25 kg', 'Arroz blanco premium', 'Grano basico', 'saco',
 'AgroSur', '2222-3333', 'L2026-08', '2027-08-01', 'A-01', NULL, 40),
('2026-08-03', 'MERMA', 'MERMA', 'Leche entera', 'Leche UHT entera', 'Lacteo', 'caja',
 'LacteosCentro', '2222-4444', 'L2026-07', '2026-08-02', 'C-10', NULL, 15);
```

### Tareas a realizar

1. Identifica las dependencias funcionales del esquema y las claves candidatas.
3. Normaliza 1FN → 2FN → 3FN indicando la anomalía que se elimina en cada paso.
4. Dibuja el modelo E-R normalizado (entidades, claves, cardinalidades).

---

## Escenario 4 — RRHH / Proyectos (No transaccional)

### Contexto del escenario

La empresa administra su personal para **reportes gerenciales**. Un empleado pertenece a un departamento (con jefe) y ocupa **1..n cargos a lo largo del tiempo** (historial de posiciones con sueldo y fechas). Puede estar asignado a **1..n proyectos de forma simultánea**, cada uno con un **porcentaje de dedicación variable** y fechas de inicio/fin. Puede tener **0..n dependientes**. El estado del empleado varía: activo, en licencia, en vacaciones o inactivo. El énfasis es el **modelado correcto para consultas de reporte**, no transacciones.

### Flujo variable del proceso

```
INGRESO ──▶ ACTIVO ──▶ (ramas simultáneas)
              │          ├─▶ (opcional) LICENCIA
              │          ├─▶ (opcional) VACACIONES
              │          ├─▶ (histórico) CAMBIO DE CARGO  → 1..n posiciones
              │          └─▶ (histórico) ASIGNACIÓN A PROYECTOS → 1..n simultáneos (% dedicación)
              └─▶ INACTIVO
```

**Cardinalidades variables a observar:** cargos 1..n en el tiempo · proyectos 1..n simultáneos · dedicación % · dependientes 0..n.

### Estructura desnormalizada

```
EMPLEADO (tabla única)
┌──────────────────────────────────────────────────────────────────┐
│ id_emp, nombre, departamento, jefe                     ← transitivo│
│ cargo, salario                                          ← transitivo│
│ proyecto_1, dedicacion_1, proyecto_2, dedicacion_2,      ← repetidos│
│ proyecto_3, dedicacion_3                                 (historial)│
│ dependiente_1, dependiente_2                             ← repetidos│
│ fecha_ingreso, estado                                              │
└──────────────────────────────────────────────────────────────────┘
```

#### T-SQL de partida (no normalizado)

```sql
CREATE TABLE dbo.Empleado(
    id_emp        INT PRIMARY KEY,
    nombre        VARCHAR(80) NOT NULL,
    departamento  VARCHAR(60) NOT NULL,
    jefe          VARCHAR(80) NOT NULL,
    cargo         VARCHAR(60) NOT NULL,
    salario       DECIMAL(10,2) NOT NULL,
    proyecto_1    VARCHAR(60), dedicacion_1 INT,
    proyecto_2    VARCHAR(60), dedicacion_2 INT,
    proyecto_3    VARCHAR(60), dedicacion_3 INT,
    dependiente_1 VARCHAR(80),
    dependiente_2 VARCHAR(80),
    fecha_ingreso DATE NOT NULL,
    estado        VARCHAR(15) NOT NULL
);

INSERT INTO dbo.Empleado (id_emp, nombre, departamento, jefe, cargo, salario,
    proyecto_1, dedicacion_1, proyecto_2, dedicacion_2,
    dependiente_1, dependiente_2, fecha_ingreso, estado)
VALUES
(101, 'Rosa Prado', 'Desarrollo', 'Ing. Mora', 'Analista', 18000.00,
 'SIG Contable', 60, 'Portal Web', 40, 'Luis Prado', NULL, '2019-03-01', 'ACTIVO'),
(102, 'Ivan Rojas', 'Desarrollo', 'Ing. Mora', 'Programador', 15000.00,
 'Portal Web', 100, NULL, NULL, NULL, NULL, '2021-06-15', 'VACACIONES'),
(103, 'Diana Cruz', 'Calidad', 'Lic. Paz', 'Tester', 14000.00,
 'SIG Contable', 50, 'App Movil', 50, 'Mia Cruz', 'Leo Cruz', '2022-01-10', 'ACTIVO');
```

### Tareas a realizar

1. Identifica las dependencias funcionales del esquema y las claves candidatas.
3. Normaliza 1FN → 2FN → 3FN indicando la anomalía que se elimina en cada paso.
4. Dibuja el modelo E-R normalizado (entidades, claves, cardinalidades).

---

## Escenario 5 — Flota vehicular (No transaccional)

### Contexto del escenario

La empresa de transporte administra su flota para **reportes de operación**. Cada vehículo pasa por estados: disponible, asignado, en mantenimiento o fuera de servicio. Un vehículo es manejado por **1..n conductores a lo largo del tiempo** (asignaciones con fechas) y puede cubrir **1..n rutas**. Recibe **1..n mantenimientos** (preventivo o correctivo, con costo y odómetro), y cada mantenimiento puede incluir **1..n repuestos**. Se registran **0..n cargas de combustible** y **0..n incidentes/multas**. El reporte clave: **costo de mantenimiento por vehículo** y **disponibilidad** de la flota.

### Flujo variable del proceso

```
DISPONIBLE ──▶ ASIGNADO (a conductor y ruta) ──▶ EN_MANTENIMIENTO ──▶ DISPONIBLE
    │                    │                            │
    │                    └─▶ (histórico) 1..n conductores en el tiempo
    │                    └─▶ (histórico) 1..n rutas
    │                    ├─▶ (opcional) COMBUSTIBLE 0..n cargas
    │                    └─▶ (opcional) INCIDENTE/MULTA 0..n
    └─▶ FUERA_DE_SERVICIO
          (mantenimiento preventivo vs correctivo)
```

**Cardinalidades variables a observar:** conductores 1..n en el tiempo · rutas 1..n · mantenimientos 1..n con 1..n repuestos · combustible 0..n · incidentes 0..n.

### Estructura desnormalizada

```
VEHICULO (tabla única)
┌──────────────────────────────────────────────────────────────────┐
│ placa, modelo, anio, estado, odometro                            │
│ conductor, licencia                                    ← transitivo│
│ ruta, origen, destino                                  ← transitivo│
│ mant_fecha_1, mant_tipo_1, mant_costo_1,                ← repetidos│
│ mant_fecha_2, mant_tipo_2, mant_costo_2                   (historial)│
│ repuesto_1, repuesto_2, repuesto_3                     ← repetidos│
└──────────────────────────────────────────────────────────────────┘
```

### T-SQL de partida (no normalizado)

```sql
CREATE TABLE dbo.Vehiculo(
    placa        VARCHAR(10) PRIMARY KEY,
    modelo       VARCHAR(40) NOT NULL,
    anio         INT NOT NULL,
    estado       VARCHAR(20) NOT NULL,
    odometro     INT NOT NULL,
    conductor    VARCHAR(80),
    licencia     VARCHAR(20),
    ruta         VARCHAR(40),
    origen       VARCHAR(60),
    destino      VARCHAR(60),
    mant_fecha_1 DATE,  mant_tipo_1 VARCHAR(20),  mant_costo_1 DECIMAL(10,2),
    mant_fecha_2 DATE,  mant_tipo_2 VARCHAR(20),  mant_costo_2 DECIMAL(10,2),
    mant_fecha_3 DATE,  mant_tipo_3 VARCHAR(20),  mant_costo_3 DECIMAL(10,2),
    repuesto_1   VARCHAR(60),
    repuesto_2   VARCHAR(60),
    repuesto_3   VARCHAR(60)
);

INSERT INTO dbo.Vehiculo (placa, modelo, anio, estado, odometro, conductor, licencia,
    ruta, origen, destino, mant_fecha_1, mant_tipo_1, mant_costo_1, mant_fecha_2, mant_tipo_2, mant_costo_2,
    repuesto_1, repuesto_2)
VALUES
('M-1234', 'Toyota Hilux', 2021, 'DISPONIBLE', 48200, 'Juan Ortiz', 'L-8821',
 'R-01', 'Managua', 'Masaya', '2026-05-10', 'CORRECTIVO', 4500.00, '2026-07-15', 'PREVENTIVO', 3200.00,
 'Bateria', 'Filtro de aceite'),
('M-5678', 'Nissan Frontier', 2020, 'EN MANTENIMIENTO', 61000, 'Ana Vega', 'L-9033',
 'R-02', 'Managua', 'Leon', '2026-06-01', 'CORRECTIVO', 12000.00, NULL, NULL, NULL,
 'Motor de arranque', NULL),
('M-9012', 'Isuzu D-Max', 2022, 'ASIGNADO', 30500, 'Luis Ponce', 'L-4470',
 'R-03', 'Managua', 'Chinandega', '2026-04-20', 'PREVENTIVO', 2800.00, NULL, NULL, NULL,
 'Aceite de motor', 'Filtro de aire');
```

#### Tareas a realizar

### Tareas a realizar

1. Identifica las dependencias funcionales del esquema y las claves candidatas.
3. Normaliza 1FN → 2FN → 3FN indicando la anomalía que se elimina en cada paso.
4. Dibuja el modelo E-R normalizado (entidades, claves, cardinalidades).

---