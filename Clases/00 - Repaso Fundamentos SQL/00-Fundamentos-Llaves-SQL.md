# 00. Fundamentos de Llaves y Restricciones SQL

---

## 1. Introducción

### ¿Por qué son importantes las llaves?

Las **llaves** son la columna vertebral de cualquier base de datos relacional. Sin ellas:

- No existiría forma de **identificar de manera única** cada registro
- No se podrían establecer **relaciones** entre tablas
- La **integridad de los datos** no estaría garantizada
- Las consultas perderían **rendimiento** al no poder indexar eficientemente

### Relación con la integridad referencial

La **integridad referencial** es la regla que garantiza que las relaciones entre tablas permanezcan consistentes. Esto significa:

- No puedes insertar un registro hijo si el padre no existe
- No puedes eliminar un registro padre si tiene hijos (a menos que uses CASCADE)
- No puedes cambiar la PK de un registro padre si tiene hijos referenciados

---

## 2. Tipos de Llaves

### 2.1 Primary Key (PK) — Llave Primaria

**Definición:** columna o grupo de columnas que identifica **de manera única** cada fila de una tabla.

**Características:**
- NO permite valores NULL
- GARANTIZA unicidad (no hay duplicados)
- Cada tabla solo puede tener UNA PK
- Se crea automáticamente un índice clustered

**Cuándo usarla:**
- Siempre en cada tabla relacional
- Para identificar registros de forma unívoca
- Como referencia para Foreign Keys

```sql
-- PK simple (recomendado)
CREATE TABLE Paciente (
    id_paciente INT IDENTITY(1,1) NOT NULL,
    nombre VARCHAR(80) NOT NULL,
    fecha_nacimiento DATE,
    CONSTRAINT pk_paciente PRIMARY KEY (id_paciente)
);
```

### 2.2 Foreign Key (FK) — Llave Foránea

**Definición:** columna que establece un enlace con la PK de otra tabla, creando una **relación** entre ambas.

**Características:**
- Permite valores NULL (a menos que sea NOT NULL)
- Permite valores duplicados
- Puede apuntar a PK o a UNIQUE de otra tabla
- Garantiza integridad referencial

**Cuándo usarla:**
- En tablas hijas que dependen de una tabla padre
- Para implementar relaciones 1:N y M:N
- Para crear cascadas de eliminación/actualización

```sql
CREATE TABLE Cita (
    id_cita INT IDENTITY(1,1) NOT NULL,
    id_paciente INT NOT NULL,
    fecha DATE NOT NULL,
    CONSTRAINT pk_cita PRIMARY KEY (id_cita),
    CONSTRAINT fk_cita_paciente FOREIGN KEY (id_paciente)
        REFERENCES Paciente(id_paciente)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);
```

### 2.3 Unique Key (UQ) — Llave Única

**Definición:** garantiza que no existan valores duplicados en una columna, pero **permite un valor NULL**.

**Diferencia con PK:**
- Permite UN solo NULL (a diferencia de PK que no permite ninguno)
- Puede haber múltiples UQ por tabla
- No crea índice clustered (crea non-clustered)

**Cuándo usarla:**
- En columnas que deben ser únicas pero no son la PK
- Emails, números de identificación, códigos
- Cuando necesitas múltiples constraint de unicidad

```sql
CREATE TABLE Usuario (
    id_usuario INT IDENTITY(1,1) NOT NULL,
    email VARCHAR(100) NOT NULL,
    username VARCHAR(50) NOT NULL,
    CONSTRAINT pk_usuario PRIMARY KEY (id_usuario),
    CONSTRAINT uq_usuario_email UNIQUE (email),
    CONSTRAINT uq_usuario_username UNIQUE (username)
);
```

### 2.4 Composite Key — Llave Compuesta

**Definición:** PK formada por **dos o más columnas** que combinadas identifican únicamente cada fila.

**Cuándo usarla:**
- En tablas de relación M:N (estudiante-materia, producto-pedido)
- En tablas de auditoría (usuario + fecha + tabla)
- En históricos (producto + fecha_vigencia)

```sql
-- Relación M:N: Estudiante se inscribe en Materias
CREATE TABLE Inscripcion (
    id_estudiante INT NOT NULL,
    id_materia INT NOT NULL,
    fecha_inscripcion DATE DEFAULT GETDATE(),
    calificacion DECIMAL(5,2),
    CONSTRAINT pk_inscripcion PRIMARY KEY (id_estudiante, id_materia),
    CONSTRAINT fk_inscripcion_estudiante FOREIGN KEY (id_estudiante)
        REFERENCES Estudiante(id_estudiante),
    CONSTRAINT fk_inscripcion_materia FOREIGN KEY (id_materia)
        REFERENCES Materia(id_materia)
);
```

**Nota:** La PK compuesta `(id_estudiante, id_materia)` significa que un estudiante solo puede inscribirse una vez en cada materia.

---

## 3. Sintaxis Detallada

### 3.1 PK Simple con IDENTITY

```sql
CREATE TABLE Producto (
    id_producto INT IDENTITY(1,1) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    precio DECIMAL(10,2) NOT NULL,
    CONSTRAINT pk_producto PRIMARY KEY (id_producto)
);
```

**IDENTITY(1,1):**
- Primer valor: 1 (semilla inicial)
- Segundo valor: 1 (incremento)
- SQL Server asigna automáticamente valores

### 3.2 PK Compuesta

```sql
CREATE TABLE DetallePedido (
    id_pedido INT NOT NULL,
    id_producto INT NOT NULL,
    cantidad INT NOT NULL CHECK (cantidad > 0),
    precio_unitario DECIMAL(10,2) NOT NULL,
    CONSTRAINT pk_detalle_pedido PRIMARY KEY (id_pedido, id_producto)
);
```

### 3.3 FK con Acciones

```sql
CREATE TABLE Pedido (
    id_pedido INT IDENTITY(1,1) NOT NULL,
    id_cliente INT NOT NULL,
    fecha_pedido DATE DEFAULT GETDATE(),
    CONSTRAINT pk_pedido PRIMARY KEY (id_pedido),
    CONSTRAINT fk_pedido_cliente FOREIGN KEY (id_cliente)
        REFERENCES Cliente(id_cliente)
        ON DELETE CASCADE      -- Si se elimina el cliente, se eliminan sus pedidos
        ON UPDATE CASCADE      -- Si cambia el id del cliente, se actualiza en pedido
);
```

### 3.4 FK sin CASCADE (comportamiento por defecto)

```sql
CREATE TABLE Factura (
    id_factura INT IDENTITY(1,1) NOT NULL,
    id_pedido INT NOT NULL,
    monto_total DECIMAL(12,2) NOT NULL,
    CONSTRAINT pk_factura PRIMARY KEY (id_factura),
    CONSTRAINT fk_factura_pedido FOREIGN KEY (id_pedido)
        REFERENCES Pedido(id_pedido)
        -- ON DELETE NO ACTION (por defecto)
        -- ON UPDATE NO ACTION (por defecto)
);
```

**Comportamiento NO ACTION:**
- No permite eliminar el registro padre si tiene hijos
- No permite actualizar la PK del padre si tiene hijos
- Lanza error: "The DELETE statement conflicted with..."

### 3.5 UNIQUE con NULLs

```sql
CREATE TABLE Cliente (
    id_cliente INT IDENTITY(1,1) NOT NULL,
    nombre VARCHAR(80) NOT NULL,
    email VARCHAR(100) NULL,
    telefono VARCHAR(20) NULL,
    CONSTRAINT pk_cliente PRIMARY KEY (id_cliente),
    CONSTRAINT uq_cliente_email UNIQUE (email),  -- Permite 1 NULL
    CONSTRAINT uq_cliente_telefono UNIQUE (telefono)  -- Permite 1 NULL
);
```

---

## 4. Restricciones y sus Usos

### 4.1 ¿Qué es una Restricción?

Una **restricción** (constraint) es una regla que se aplica a columnas o tablas para garantizar la integridad de los datos. Se aplican durante las operaciones INSERT, UPDATE y DELETE.

**Tipos de restricciones:**
- A nivel de columna: se definen junto con la columna
- A nivel de tabla: se definen al final de la sentencia CREATE TABLE

### 4.2 NOT NULL

**Propósito:** Impide que una columna contenga valores NULL.

```sql
CREATE TABLE Paciente (
    id_paciente INT IDENTITY(1,1) NOT NULL,
    nombre VARCHAR(80) NOT NULL,          -- Obligatorio
    telefono VARCHAR(20) NULL,            -- Opcional (permite NULL)
    email VARCHAR(100) NULL               -- Opcional
);
```

**Buenas prácticas:**
- Usar NOT NULL en columnas que siempre deben tener valor (nombres, fechas de registro)
- Usar NULL en columnas opcionales (teléfono, email secundario)
- No abusar de NULL: dificulta consultas y reportes

### 4.3 UNIQUE

**Propósito:** Garantiza que no existan valores duplicados en una columna (permite un NULL).

```sql
-- A nivel de columna
CREATE TABLE Usuario (
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE
);

-- A nivel de tabla (con nombre explícito)
CREATE TABLE Usuario (
    username VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    CONSTRAINT uq_usuario_username UNIQUE (username),
    CONSTRAINT uq_usuario_email UNIQUE (email)
);
```

**Características:**
- Permite UN solo NULL por columna
- Crea un índice non-clustered automáticamente
- Se puede agregar a tablas existentes con ALTER TABLE

### 4.4 PRIMARY KEY

**Propósito:** Identificador único de cada fila (NOT NULL + UNIQUE).

```sql
CREATE TABLE Producto (
    id_producto INT IDENTITY(1,1) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    CONSTRAINT pk_producto PRIMARY KEY (id_producto)
);
```

**Características:**
- NO permite NULL
- GARANTIZA unicidad
- Solo UNA PK por tabla (puede ser compuesta)
- Crea un índice clustered por defecto

### 4.5 FOREIGN KEY

**Propósito:** Garantiza integridad referencial entre tablas.

```sql
CREATE TABLE Venta (
    id_venta INT IDENTITY(1,1) NOT NULL,
    id_cliente INT NOT NULL,
    fecha_venta DATE DEFAULT GETDATE(),
    CONSTRAINT pk_venta PRIMARY KEY (id_venta),
    CONSTRAINT fk_venta_cliente FOREIGN KEY (id_cliente)
        REFERENCES Cliente(id_cliente)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);
```

**Acciones disponibles:**

| Acción | Comportamiento |
|--------|----------------|
| `ON DELETE CASCADE` | Elimina hijos al eliminar padre |
| `ON DELETE SET NULL` | Pone NULL en hijos al eliminar padre |
| `ON DELETE SET DEFAULT` | Pone valor default en hijos al eliminar padre |
| `ON DELETE NO ACTION` | Impide eliminar si tiene hijos (por defecto) |
| `ON UPDATE CASCADE` | Actualiza hijos al cambiar PK padre |
| `ON UPDATE SET NULL` | Pone NULL en hijos al cambiar PK padre |
| `ON UPDATE NO ACTION` | Impide actualizar si tiene hijos (por defecto) |

### 4.6 CHECK

**Propósito:** Valida que los datos cumplan una condición booleana.

```sql
CREATE TABLE Empleado (
    id_empleado INT IDENTITY(1,1) NOT NULL,
    nombre VARCHAR(80) NOT NULL,
    edad INT NOT NULL CHECK (edad >= 18 AND edad <= 70),
    salario DECIMAL(10,2) NOT NULL CHECK (salario > 0),
    estado CHAR(1) NOT NULL CHECK (estado IN ('A', 'I', 'V')),
    fecha_ingreso DATE NOT NULL,
    fecha_salida DATE NULL,
    CONSTRAINT pk_empleado PRIMARY KEY (id_empleado),
    CONSTRAINT ck_empleado_fechas CHECK (fecha_salida IS NULL OR fecha_salida > fecha_ingreso)
);
```

**Ejemplos prácticos de CHECK:**

| Caso | Restricción |
|------|-------------|
| Edad válida | `CHECK (edad BETWEEN 0 AND 150)` |
| Email formato básico | `CHECK (email LIKE '%_@__%.__%')` |
| Fechas coherentes | `CHECK (fecha_fin > fecha_inicio)` |
| Estado válido | `CHECK (estado IN ('Pendiente', 'Activo', 'Cancelado'))` |
| Monto positivo | `CHECK (monto > 0)` |
| Porcentaje válido | `CHECK (porcentaje BETWEEN 0 AND 100)` |
| Longitud de texto | `CHECK (LEN(codigo) = 10)` |

### 4.7 DEFAULT

**Propósito:** Asigna un valor por defecto cuando no se especifica uno en el INSERT.

```sql
CREATE TABLE Registro (
    id_registro INT IDENTITY(1,1) NOT NULL,
    descripcion VARCHAR(200) NOT NULL,
    fecha_registro DATETIME DEFAULT GETDATE(),
    estado VARCHAR(20) DEFAULT 'Pendiente',
    activo BIT DEFAULT 1,
    usuario_registro VARCHAR(50) DEFAULT SYSTEM_USER,
    CONSTRAINT pk_registro PRIMARY KEY (id_registro)
);
```

**Tipos de valores DEFAULT:**

```sql
-- Función
fecha DATETIME DEFAULT GETDATE()

-- Valor constante
estado VARCHAR(20) DEFAULT 'Activo'

-- Expresión
codigo VARCHAR(10) DEFAULT 'SIN_CODIGO'

-- Función del sistema
usuario VARCHAR(50) DEFAULT SYSTEM_USER
```

**Uso en INSERT:**

```sql
-- Sin DEFAULT (se aplica automáticamente)
INSERT INTO Registro (descripcion) VALUES ('Primer registro');

-- Especificando DEFAULT
INSERT INTO Registro (descripcion, fecha_registro) VALUES ('Segundo registro', DEFAULT);

-- Todos los valores
INSERT INTO Registro (descripcion, fecha_registro, estado, activo, usuario_registro)
VALUES ('Tercer registro', GETDATE(), 'Activo', 1, 'admin');
```

### 4.8 Agregar/Eliminar Restricciones en Tablas Existentes

```sql
-- Agregar CHECK
ALTER TABLE Producto
ADD CONSTRAINT ck_producto_precio CHECK (precio > 0);

-- Agregar UNIQUE
ALTER TABLE Producto
ADD CONSTRAINT uq_producto_codigo UNIQUE (codigo_barras);

-- Agregar DEFAULT
ALTER TABLE Producto
ADD CONSTRAINT df_producto_stock DEFAULT 0 FOR stock;

-- Agregar FK
ALTER TABLE Venta
ADD CONSTRAINT fk_venta_producto FOREIGN KEY (id_producto)
    REFERENCES Producto(id_producto);

-- Eliminar restricción
ALTER TABLE Producto
DROP CONSTRAINT ck_producto_precio;

-- Verificar restricciones de una tabla
SELECT * FROM sys.objects WHERE parent_object_id = OBJECT_ID('Producto');
```

### 4.9 Tabla Resumen: Comparativa de Restricciones

| Restricción | Permite NULL | Única por columna | Se puede nombrar | Tablas existentes |
|-------------|--------------|-------------------|------------------|-------------------|
| NOT NULL | No | No | No | Sí (ALTER) |
| UNIQUE | Sí (1) | Sí | Sí | Sí |
| PRIMARY KEY | No | Sí | Sí | Sí |
| FOREIGN KEY | Sí* | No | Sí | Sí |
| CHECK | Sí | No | Sí | Sí |
| DEFAULT | Sí** | No | Sí | Sí |

*\* FK permite NULL a menos que la columna sea NOT NULL*
*\*\* DEFAULT se aplica solo si la columna permite NULL o no se especifica valor*

### 4.10 Orden de Definición en CREATE TABLE

El orden correcto para definir columnas y restricciones:

```sql
CREATE TABLE Pedido (
    -- 1. Columnas con sus restricciones a nivel de columna
    id_pedido INT IDENTITY(1,1) NOT NULL,
    id_cliente INT NOT NULL,
    fecha_pedido DATE NOT NULL DEFAULT GETDATE(),
    total DECIMAL(12,2) NULL,
    
    -- 2. Restricciones a nivel de tabla (al final)
    CONSTRAINT pk_pedido PRIMARY KEY (id_pedido),
    CONSTRAINT fk_pedido_cliente FOREIGN KEY (id_cliente)
        REFERENCES Cliente(id_cliente)
        ON DELETE CASCADE,
    CONSTRAINT ck_pedido_total CHECK (total >= 0)
);
```

---

## 5. Buenas Prácticas de Nomenclatura

### 5.1 Prefijos por Tipo de Objeto

| Objeto | Prefijo | Ejemplo |
|--------|---------|---------|
| Primary Key | `pk_` | `pk_producto`, `pk_pedido` |
| Foreign Key | `fk_` | `fk_venta_producto` |
| Unique | `uq_` | `uq_usuario_email` |
| Check | `ck_` | `ck_edad_positiva` |
| Default | `df_` | `df_fecha_registro` |
| Index | `ix_` | `ix_cliente_nombre` |
| Constraint general | `cn_` | `cn_estado_valido` |

### 5.2 Convenciones de Nombres

```sql
CONSTRAINT pk_producto
CONSTRAINT fk_venta_producto
CONSTRAINT uq_usuario_email
CONSTRAINT ck_producto_precio

CONSTRAINT PK1
CONSTRAINT FK_Factura_2
CONSTRAINT UniqueEmail
CONSTRAINT Check_Precio_Positivo
```

### 5.3 Nombres descriptivos

```sql
CONSTRAINT ck_producto_precio_positivo
CONSTRAINT ck_empleado_edad_rango
CONSTRAINT ck_pedido_fechas_coherentes

CONSTRAINT ck_check1
CONSTRAINT ck_constraint_precio
```

### 5.4 Tabla de Nomenclatura Recomendada

| Objeto | Formato | Ejemplo |
|--------|---------|---------|
| Tabla | Nombre en singular, PascalCase | `Producto`, `DetallePedido` |
| Columna | snake_case o camelCase | `id_producto`, `fechaRegistro` |
| PK | `pk_tabla` | `pk_producto` |
| FK | `fk_tablaHija_tablaPadre` | `fk_venta_cliente` |
| UQ | `uq_tabla_columna` | `uq_usuario_email` |
| CHECK | `ck_tabla_condicion` | `ck_producto_precio` |
| INDEX | `ix_tabla_columna` | `ix_cliente_nombre` |

---

## 6. Llaves Combinadas: Casos de Uso

### 6.1 Relaciones M:N (Muchos a Muchos)

**Ejemplo:** Estudiante se inscribe en múltiples Materias; cada Materia tiene múltiples Estudiantes.

```sql
CREATE TABLE Estudiante (
    id_estudiante INT IDENTITY(1,1) NOT NULL,
    nombre VARCHAR(80) NOT NULL,
    CONSTRAINT pk_estudiante PRIMARY KEY (id_estudiante)
);

CREATE TABLE Materia (
    id_materia INT IDENTITY(1,1) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    CONSTRAINT pk_materia PRIMARY KEY (id_materia)
);

-- Tabla intermedia con PK compuesta
CREATE TABLE Inscripcion (
    id_estudiante INT NOT NULL,
    id_materia INT NOT NULL,
    fecha_inscripcion DATE DEFAULT GETDATE(),
    calificacion DECIMAL(5,2) NULL,
    CONSTRAINT pk_inscripcion PRIMARY KEY (id_estudiante, id_materia),
    CONSTRAINT fk_inscripcion_estudiante FOREIGN KEY (id_estudiante)
        REFERENCES Estudiante(id_estudiante) ON DELETE CASCADE,
    CONSTRAINT fk_inscripcion_materia FOREIGN KEY (id_materia)
        REFERENCES Materia(id_materia) ON DELETE CASCADE
);
```

### 6.2 Tablas de Auditoría

**Ejemplo:** Registrar qué usuario modificó qué tabla y cuándo.

```sql
CREATE TABLE Auditoria (
    id_usuario INT NOT NULL,
    fecha_modificacion DATETIME NOT NULL,
    tabla_afectada VARCHAR(50) NOT NULL,
    accion VARCHAR(10) NOT NULL,
    registro_id INT NOT NULL,
    CONSTRAINT pk_auditoria PRIMARY KEY (id_usuario, fecha_modificacion, tabla_afectada),
    CONSTRAINT fk_auditoria_usuario FOREIGN KEY (id_usuario)
        REFERENCES Usuario(id_usuario)
);
```

### 6.3 Histórico de Precios

**Ejemplo:** Cada producto tiene precios diferentes según la fecha de vigencia.

```sql
CREATE TABLE HistoricoPrecio (
    id_producto INT NOT NULL,
    fecha_vigencia DATE NOT NULL,
    precio DECIMAL(10,2) NOT NULL,
    CONSTRAINT pk_historico_precio PRIMARY KEY (id_producto, fecha_vigencia),
    CONSTRAINT fk_historico_producto FOREIGN KEY (id_producto)
        REFERENCES Producto(id_producto) ON DELETE CASCADE,
    CONSTRAINT ck_historico_precio CHECK (precio > 0)
);
```

### 6.4 Horarios de Empleado

**Ejemplo:** Cada empleado tiene un horario por día de la semana.

```sql
CREATE TABLE Horario (
    id_empleado INT NOT NULL,
    dia_semana TINYINT NOT NULL,  -- 1=Lunes, 7=Domingo
    hora_entrada TIME NOT NULL,
    hora_salida TIME NOT NULL,
    CONSTRAINT pk_horario PRIMARY KEY (id_empleado, dia_semana),
    CONSTRAINT fk_horario_empleado FOREIGN KEY (id_empleado)
        REFERENCES Empleado(id_empleado) ON DELETE CASCADE,
    CONSTRAINT ck_horario_dia CHECK (dia_semana BETWEEN 1 AND 7),
    CONSTRAINT ck_horario_horas CHECK (hora_salida > hora_entrada)
);
```

---

## 7. Ejercicios Prácticos

### Ejercicio 1: Crear esquema completo con restricciones

Crear una base de datos `ClinicaDB` con las siguientes tablas y restricciones:

```sql
-- Tabla: Paciente
-- Columnas: id_paciente (PK), nombre (NOT NULL), email (UQ), telefono, fecha_nacimiento
-- Restricción: fecha_nacimiento no puede ser futura

-- Tabla: Medico
-- Columnas: id_medico (PK), nombre (NOT NULL), especialidad (NOT NULL), email (UQ)
-- Restricción: especialidad debe estar en lista permitida

-- Tabla: Cita
-- Columnas: id_cita (PK), id_paciente (FK), id_medico (FK), fecha (NOT NULL), hora, estado
-- Restricción: estado en ('Programada', 'Atendida', 'Cancelada')

-- Tabla: Receta
-- Columnas: id_receta (PK), id_cita (FK), medicamento, dosis, instrucciones
-- Restricción: dosis no puede ser vacía
```

### Ejercicio 2: Modificar tabla existente

```sql
-- Agregar restricciones a una tabla ya creada:
-- 1. Agregar CHECK para validar que el stock no sea negativo
-- 2. Agregar UNIQUE al codigo_barras
-- 3. Agregar DEFAULT para el campo activo (DEFAULT 1)
-- 4. Eliminar una restricción CHECK anterior
```

### Ejercicio 3: Identificar errores

¿Qué errores encuentras en este esquema?

```sql
CREATE TABLE Pedido (
    id_pedido INT,
    id_cliente INT,
    total DECIMAL(10,2),
    CONSTRAINT pk_pedido PRIMARY KEY (id_cliente),  -- Error 1
    CONSTRAINT fk_pedido_cliente FOREIGN KEY (id_pedido)  -- Error 2
        REFERENCES Cliente(id_cliente),
    CONSTRAINT ck_pedido CHECK (total < 0)  -- Error 3
);
```

---

## 8. Preguntas de Autoevaluación

1. ¿Cuál es la diferencia entre PRIMARY KEY y UNIQUE KEY?

2. ¿Cuándo se debe usar una llave compuesta en lugar de una PK simple?

3. ¿Qué diferencia hay entre ON DELETE CASCADE y ON DELETE SET NULL?

4. ¿Por qué es importante nombrar las restricciones explícitamente?

5. ¿Cuántas PRIMARY KEY puede tener una tabla? ¿Y UNIQUE KEY?

6. ¿Qué restricción usarías para garantizar que un email tenga un formato válido?

7. ¿Cómo se agrega una restricción CHECK a una tabla ya existente?

8. ¿Qué sucede si intentas eliminar una fila padre que tiene hijos con FK sin CASCADE?

9. ¿Cuál es la diferencia entre NOT NULL y UNIQUE en cuanto a NULLs?

10. ¿Por qué se recomienda usar prefijos (pk_, fk_, ck_) en los nombres de restricciones?

---


