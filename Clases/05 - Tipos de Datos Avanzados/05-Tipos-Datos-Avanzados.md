# 05. Tipos de Datos Avanzados

> **Antes de los tipos "avanzados".** La rúbrica del proyecto integrador evalúa la aplicación del Tema 05 como **buena práctica de modelado**. Eso empieza por elegir bien los tipos **básicos** (sección 0) y por saber **cuándo no** usar un tipo avanzado.

## 0. Criterios de elección de tipos (base de todo el tema)

| Dato | Recomendado | Evitar | Motivo |
|------|-------------|--------|--------|
| Dinero, precios, tasas | `DECIMAL(p,s)` (ej. `DECIMAL(12,2)`) | `FLOAT`, `REAL`, `MONEY` | `FLOAT` es aproximado: `0.1 + 0.2 ≠ 0.3`. `MONEY` redondea a 4 decimales en divisiones intermedias. |
| Solo fecha | `DATE` (3 bytes) | `DATETIME` | No almacenar una hora que no existe. |
| Fecha y hora | `DATETIME2(0..7)` + `SYSDATETIME()` | `DATETIME` + `GETDATE()` | `DATETIME` tiene precisión de ~3 ms y rango desde 1753. `DATETIME2` es más preciso y ocupa igual o menos. |
| Fecha y hora con zona | `DATETIMEOFFSET` | `DATETIME` + columna aparte | Sistemas multi-zona. |
| Texto con tildes y ñ (nombres, direcciones) | `NVARCHAR(n)` o `VARCHAR` con intercalación UTF-8 (`*_UTF8`) | `VARCHAR` con una intercalación que no cubre el carácter | Con `VARCHAR` sobre la página de códigos 1252 un carácter fuera de ella (`→`, letras de otros alfabetos, emojis) se convierte en `?`. |
| Códigos de longitud fija (VIN, ISO de país) | `CHAR(n)` | `VARCHAR(MAX)` | Longitud conocida → validable con `CHECK (LEN(col) = n)`. |
| Banderas sí/no | `BIT` | `CHAR(1)` `'S'/'N'` sin `CHECK` | Dominio cerrado. |
| Cantidades enteras | `TINYINT` / `SMALLINT` / `INT` / `BIGINT` según rango | `INT` "para todo" o `DECIMAL` | Tamaño adecuado = menos páginas = índices más pequeños (Tema 06). |
| Texto libre largo | `VARCHAR(n)` con un `n` realista; `(MAX)` solo si supera 8000 | `VARCHAR(MAX)` "por si acaso" | Las columnas `MAX` no pueden ser clave de índice y complican los planes. |

**Revisión crítica del script del curso.** ConcessionaireDB usa `DATETIME` + `GETDATE()` en las fechas de cotización, factura y auditoría. Es funcional, pero la práctica recomendada para un diseño nuevo es `DATETIME2(0)` + `SYSDATETIME()`. Los nombres (`client_name`, `employee_name`) en `VARCHAR(50)` funcionan con tildes en la intercalación `Modern_Spanish_CI_AS` / `SQL_Latin1_General_CP1_CI_AS`, pero **no** admiten caracteres fuera de la página de códigos 1252.

> **Conversiones implícitas (vínculo con el Tema 06).** Comparar una columna `VARCHAR` con un parámetro `NVARCHAR` obliga a convertir la **columna**, lo que puede impedir el uso del índice (*Index Seek* → *Index Scan*). Los parámetros de los SP deben declararse con **el mismo tipo** que la columna.

---

## 1. SQL_VARIANT

### 1.1 ¿Qué es?

`SQL_VARIANT` almacena valores de **distintos tipos base** en una misma columna. Cada valor guarda su tipo original junto con el dato, con un máximo de **8016 bytes**.

**No puede contener:** `VARCHAR(MAX)`, `NVARCHAR(MAX)`, `VARBINARY(MAX)`, `XML`, `TEXT`, `NTEXT`, `IMAGE`, `ROWVERSION`/`TIMESTAMP`, `SQL_VARIANT`, `GEOGRAPHY`, `GEOMETRY`, `HIERARCHYID` ni tipos CLR definidos por el usuario.

### 1.2 ¿Cuándo usar? (y cuándo NO)

**Caso razonable:** una tabla de **parámetros de configuración**, con pocas filas, leída por clave y donde cada parámetro tiene un tipo distinto.

**Riesgos que hay que conocer:**

- **Modelo EAV (Entidad-Atributo-Valor).** Usar `SQL_VARIANT` para "guardar cualquier atributo de cualquier entidad" rompe la idea de columna con **dominio único**, que es la base de la **1FN**. Además impide aplicar `CHECK`, `FOREIGN KEY` y tipos adecuados.
- **Comparaciones y orden por "familia" de tipos.** Un `INT 5` y un `VARCHAR '5'` no se comparan como números. Para operar hay que hacer `CAST` explícito.
- **No es "flexible para esquemas que cambian".** Si el esquema cambia, se modifica el esquema (`ALTER TABLE`). La "flexibilidad" de `SQL_VARIANT` traslada los errores de tipo a tiempo de ejecución.

### 1.3 Ejemplo

```sql
CREATE TABLE config.Cat_Setting (
    setting_id INT IDENTITY(1,1) NOT NULL,
    setting_name VARCHAR(50) NOT NULL,
    setting_value SQL_VARIANT NOT NULL,
    CONSTRAINT PK_Setting PRIMARY KEY (setting_id),
    CONSTRAINT UQ_Setting_Name UNIQUE (setting_name)
);

-- El tipo base es el del VALOR insertado: si se quiere DATE o BIT hay que convertir.
-- Un INSERT con VALUES de varias filas NO sirve aquí: el constructor
--   VALUES unifica cada columna al tipo de mayor precedencia ANTES de
--   llegar a SQL_VARIANT (int + date → Msg 206 "Operand type clash").
--   Se inserta una fila por sentencia, o se convierte cada valor a SQL_VARIANT.
INSERT INTO config.Cat_Setting (setting_name, setting_value) VALUES ('max_conexiones', CAST(100 AS INT));
INSERT INTO config.Cat_Setting (setting_name, setting_value) VALUES ('nombre_empresa', CAST('Concesionario Managua' AS VARCHAR(100)));
INSERT INTO config.Cat_Setting (setting_name, setting_value) VALUES ('fecha_apertura', CAST('2020-01-15' AS DATE));  -- sin CAST quedaría varchar
INSERT INTO config.Cat_Setting (setting_name, setting_value) VALUES ('facturacion_activa', CAST(1 AS BIT));          -- sin CAST quedaría int
INSERT INTO config.Cat_Setting (setting_name, setting_value) VALUES ('tasa_impuesto', CAST(0.15 AS DECIMAL(5,2)));

SELECT setting_name,
       setting_value,
       SQL_VARIANT_PROPERTY(setting_value, 'BaseType')  AS tipo_base,
       SQL_VARIANT_PROPERTY(setting_value, 'Precision') AS [precision],  -- PRECISION es palabra reservada
       SQL_VARIANT_PROPERTY(setting_value, 'Scale')     AS escala,
       SQL_VARIANT_PROPERTY(setting_value, 'MaxLength') AS longitud_max
FROM config.Cat_Setting;

-- Para usar el valor hay que convertirlo explícitamente
SELECT CAST(setting_value AS DECIMAL(5,2)) AS tasa
FROM config.Cat_Setting
WHERE setting_name = 'tasa_impuesto';
```

### 1.4 `SQL_VARIANT_PROPERTY`

| Propiedad | Devuelve | Ejemplo |
|-----------|----------|---------|
| `BaseType` | Tipo base | `int`, `varchar`, `date`, `bit` |
| `Precision` | Dígitos de precisión | 10 (int), 5 (decimal(5,2)) |
| `Scale` | Dígitos decimales | 2 |
| `TotalBytes` | Bytes ocupados (valor + metadatos) | 6 |
| `Collation` | Intercalación (solo texto) | `SQL_Latin1_General_CP1_CI_AS` |
| `MaxLength` | Longitud máxima del tipo base, en bytes | 4, 100 |

---

## 2. HIERARCHYID

### 2.1 ¿Qué es?

`HIERARCHYID` representa la **posición de un nodo en un árbol** como una ruta compacta (`/1/3/2/`). Es una alternativa a la **lista de adyacencia** (`boss_id`) vista en el Tema 04.

| | Lista de adyacencia (`boss_id`) | `HIERARCHYID` |
|---|---|---|
| Integridad | **FK** garantiza que el jefe exista | **Ninguna**: puede haber nodos huérfanos o rutas duplicadas |
| Mover un subárbol | `UPDATE` de una fila | Reescribir la ruta de **todos** los descendientes (`GetReparentedValue`) |
| Consultar descendientes | CTE recursiva | `IsDescendantOf` sin recursión, apoyada en un índice |
| Nivel | Se calcula con recursión | `GetLevel()` directo |

> **Vínculo con la 3FN.** Si una tabla guarda a la vez `boss_id` y `jerarquia`, el segundo **se deriva** del primero: es **información redundante**. Hay que justificarlo como optimización de lectura y **mantenerlos sincronizados** (por ejemplo, con un trigger), o elegir uno solo.

### 2.2 ¿Cuándo usar?

- Árboles **muy leídos y poco modificados**: categorías, menús, organigramas estables, estructura de carpetas.
- Cuando las consultas típicas son "todo el subárbol de X" o "nivel de cada nodo".

### 2.3 Niveles y raíz

- La **raíz** es `'/'` y tiene `GetLevel() = 0`.
- `'/1/'` es un **hijo de la raíz**: nivel **1**.
- `'/1/1/'` es nivel 2, y así sucesivamente.

```sql
CREATE TABLE Categoria (
    id_categoria INT IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    nodo HIERARCHYID NOT NULL,
    nivel AS nodo.GetLevel() PERSISTED   -- columna calculada
);

INSERT INTO Categoria (nombre, nodo) VALUES
('Raíz',          hierarchyid::GetRoot()),       -- '/'       nivel 0
('Electrónica',   hierarchyid::Parse('/1/')),    -- nivel 1
('Computadoras',  hierarchyid::Parse('/1/1/')),  -- nivel 2
('Laptops',       hierarchyid::Parse('/1/1/1/')),-- nivel 3
('Desktops',      hierarchyid::Parse('/1/1/2/')),-- nivel 3
('Celulares',     hierarchyid::Parse('/1/2/')),  -- nivel 2
('Accesorios',    hierarchyid::Parse('/1/3/'));  -- nivel 2

SELECT nombre, nodo.ToString() AS ruta, nodo.GetLevel() AS nivel
FROM Categoria
ORDER BY nodo;          -- orden "en profundidad" (depth-first)
```

### 2.4 Métodos principales

| Método | Uso |
|--------|-----|
| `hierarchyid::GetRoot()` | Nodo raíz `/` |
| `hierarchyid::Parse('/1/2/')` / `.ToString()` | Convertir desde y hacia texto |
| `nodo.GetLevel()` | Profundidad (raíz = 0) |
| `nodo.GetAncestor(n)` | Ancestro *n* niveles arriba (**el padre es `GetAncestor(1)`**; no existe `GetParent()`) |
| `nodo.IsDescendantOf(x)` | 1 si `nodo` está en el subárbol de `x` (**incluye a `x` mismo**) |
| `padre.GetDescendant(c1, c2)` | Genera un hijo nuevo entre los hermanos `c1` y `c2` (NULL = extremos) |
| `nodo.GetReparentedValue(viejo, nuevo)` | Ruta del nodo al mover su subárbol de `viejo` a `nuevo` |

```sql
-- Hijos directos de Electrónica
SELECT nombre FROM Categoria
WHERE nodo.GetAncestor(1) = hierarchyid::Parse('/1/');

-- Todo el subárbol de Computadoras (incluye Computadoras)
SELECT nombre FROM Categoria
WHERE nodo.IsDescendantOf(hierarchyid::Parse('/1/1/')) = 1;

-- Padre de un nodo
SELECT nodo.GetAncestor(1).ToString() AS ruta_padre
FROM Categoria
WHERE nombre = 'Laptops';

-- Insertar un nuevo hijo de Electrónica después del último hermano
DECLARE @padre HIERARCHYID = hierarchyid::Parse('/1/');
DECLARE @ultimo HIERARCHYID = (SELECT MAX(nodo) FROM Categoria WHERE nodo.GetAncestor(1) = @padre);
INSERT INTO Categoria (nombre, nodo) VALUES ('Audio', @padre.GetDescendant(@ultimo, NULL));
```

### 2.5 Índices recomendados

```sql
-- En profundidad: acelera "todo el subárbol"
CREATE UNIQUE INDEX UX_Categoria_Nodo ON Categoria(nodo);

-- En anchura: acelera "todos los nodos del nivel N" / hijos directos
CREATE INDEX IX_Categoria_Nivel_Nodo ON Categoria(nivel, nodo);
```

> El índice **único** sobre `nodo` es la única defensa estructural contra rutas duplicadas, ya que `HIERARCHYID` no valida la integridad del árbol.

---

## 3. GEOGRAPHY y GEOMETRY

### 3.1 Diferencia clave

| | `GEOGRAPHY` | `GEOMETRY` |
|---|---|---|
| Modelo | Tierra **elipsoidal** (lat/long) | Plano **cartesiano** (X/Y) |
| Unidades de `STDistance` | **Metros** (con SRID 4326) | Unidades del sistema de coordenadas |
| Orden en `Point()` | `geography::Point(lat, long, srid)` | `geometry::Point(x, y, srid)` |
| Orden en WKT (`'POINT(...)'`) | `POINT(long lat)`: ¡**invertido** respecto a `Point()`! | `POINT(x y)` |
| Polígonos | El orden del anillo **importa** (regla de la mano izquierda: el interior queda a la izquierda) | El orden no importa |
| Uso típico | Sucursales, rutas, distancias reales | Planos de edificios, diseño CAD |

> SRID **4326** = WGS 84, el sistema del GPS. Usar `GEOMETRY` con coordenadas lat/long "funciona", pero las distancias salen en **grados**, no en metros.

### 3.2 GEOGRAPHY

```sql
CREATE TABLE PuntoInteres (
    id INT IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    ubicacion GEOGRAPHY NOT NULL
);

INSERT INTO PuntoInteres (nombre, ubicacion) VALUES
('UNAN-Managua', geography::Point(12.1050, -86.2700, 4326)),   -- (latitud, longitud, SRID)
('Catedral',     geography::Point(12.1150, -86.2362, 4326));

SELECT a.nombre AS punto_a, b.nombre AS punto_b,
       CAST(a.ubicacion.STDistance(b.ubicacion) AS DECIMAL(10,1)) AS distancia_metros
FROM PuntoInteres a
INNER JOIN PuntoInteres b ON a.id < b.id;   -- cada par una sola vez
```

### 3.3 GEOMETRY

```sql
CREATE TABLE Edificio (
    id INT IDENTITY PRIMARY KEY,
    nombre VARCHAR(100),
    forma GEOMETRY
);

-- Plano local en metros (SRID 0): rectángulo de 50 x 20
INSERT INTO Edificio (nombre, forma) VALUES
('Biblioteca', geometry::STGeomFromText('POLYGON((0 0, 50 0, 50 20, 0 20, 0 0))', 0));

-- ¿Un punto está dentro del polígono?
SELECT nombre FROM Edificio
WHERE forma.STContains(geometry::Point(10, 5, 0)) = 1;

SELECT nombre, forma.STArea() AS area_m2 FROM Edificio;   -- 1000
```

---

## 4. Tipos de Tabla Personalizados (TVP)

### 4.1 ¿Qué es?

Un **tipo de tabla** define una estructura reutilizable que se usa para declarar **variables de tabla** y **parámetros con valores de tabla (TVP)**. Así se envían **muchas filas en una sola llamada** a un procedimiento.

### 4.2 Sintaxis

```sql
CREATE TYPE dbo.TipoTablaRepuesto AS TABLE (
    category_id INT NOT NULL,
    spare_part_name VARCHAR(50) NOT NULL,
    spare_part_price DECIMAL(12,2) NOT NULL CHECK (spare_part_price > 0),
    spare_part_stock INT NOT NULL,
    PRIMARY KEY (spare_part_name)          -- también admite PK/UNIQUE/CHECK
);
GO

CREATE PROCEDURE dbo.usp_load_spare_parts
    @repuestos dbo.TipoTablaRepuesto READONLY      -- READONLY es obligatorio
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;          -- todas las filas o ninguna (Tema 01)

        INSERT INTO inventario.Cat_SparePart (category_id, spare_part_name, spare_part_price, spare_part_stock)
        SELECT category_id, spare_part_name, spare_part_price, spare_part_stock
        FROM @repuestos;

        DECLARE @filas INT = @@ROWCOUNT;   -- capturar ANTES de COMMIT (COMMIT reinicia @@ROWCOUNT)

        COMMIT TRANSACTION;
        SELECT @filas AS filas_procesadas;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

DECLARE @lote dbo.TipoTablaRepuesto;
INSERT INTO @lote VALUES (1, 'Filtro de aceite', 12.50, 100),
                         (1, 'Pastillas de freno', 45.00, 40);
EXEC dbo.usp_load_spare_parts @lote;
```

### 4.3 Ventajas y limitaciones

| Ventajas | Limitaciones |
|----------|--------------|
| Una sola llamada en lugar de N (menos viajes de red) | El parámetro es **solo lectura** (`READONLY`) |
| Estructura tipada y validada (`CHECK`, `PK`) | **No existe `ALTER TYPE`**: para cambiarlo hay que eliminar los objetos que lo usan, eliminar el tipo y recrearlo |
| Permite procesar el lote de forma transaccional | Antes de SQL Server 2019 el optimizador estima **1 fila** para variables de tabla, lo que da malos planes con lotes grandes |
| Ideal para cargas masivas desde la aplicación | Quien ejecuta necesita permiso `EXECUTE` sobre el **tipo** (`GRANT EXECUTE ON TYPE::dbo.TipoTablaRepuesto`) |

---

## 5. Alias de Tipos (User-Defined Data Types)

### 5.1 ¿Qué es?

Un **alias de tipo** es un nombre de dominio para un tipo existente (`Email` → `VARCHAR(100)`). Documenta la intención y garantiza que todas las columnas del mismo concepto tengan **el mismo tipo y longitud**.

### 5.2 Sintaxis

```sql
CREATE TYPE dbo.Email    FROM VARCHAR(100) NULL;
CREATE TYPE dbo.Telefono FROM VARCHAR(20)  NULL;
CREATE TYPE dbo.Cedula   FROM VARCHAR(20)  NOT NULL;
GO

CREATE TABLE Proveedor (
    proveedor_id INT IDENTITY PRIMARY KEY,
    proveedor_cedula dbo.Cedula,              -- hereda NOT NULL del alias
    proveedor_email dbo.Email,
    proveedor_telefono dbo.Telefono,
    CONSTRAINT CK_Proveedor_Email CHECK (proveedor_email LIKE '%_@_%._%')   -- la regla va en la tabla
);
GO                                            -- CREATE PROCEDURE debe iniciar su propio lote

CREATE PROCEDURE dbo.usp_find_supplier
    @email dbo.Email
AS
BEGIN
    SELECT * FROM Proveedor WHERE proveedor_email = @email;
END;
GO
```

### 5.3 Limitaciones y permisos

- Un alias **no** lleva reglas de validación propias; el `CHECK` se escribe en cada tabla. Las antiguas `CREATE RULE` están obsoletas.
- **No se puede modificar.** Para cambiar `Email` a `VARCHAR(150)` hay que eliminar los objetos que lo usan, eliminar el tipo y recrearlo.
- Para usar un alias de otro dueño o esquema se necesita el permiso `REFERENCES` sobre el tipo: `GRANT REFERENCES ON TYPE::dbo.Email TO rol_x`.
- Conviene **calificar el tipo con su esquema** (`dbo.Email`).

### 5.4 Eliminar un tipo

```sql
-- Primero los objetos que lo usan; si no, Msg 3732
DROP PROCEDURE IF EXISTS dbo.usp_find_supplier;
DROP TABLE IF EXISTS Proveedor;
DROP TYPE IF EXISTS dbo.Email;

-- ¿Quién usa un tipo?
SELECT OBJECT_SCHEMA_NAME(c.object_id) + '.' + OBJECT_NAME(c.object_id) AS tabla, c.name AS columna
FROM sys.columns c
WHERE c.user_type_id = TYPE_ID('dbo.Cedula');
```

---

## 6. Comparativa de Tipos

| Tipo | Uso principal | Ventaja | Riesgo principal |
|------|---------------|---------|------------------|
| `SQL_VARIANT` | Parámetros de configuración | Flexibilidad | Antipatrón EAV; pierde la validación por tipo |
| `HIERARCHYID` | Árboles muy leídos | Subárbol y nivel sin recursión | Sin integridad estructural; mover nodos es costoso |
| `GEOGRAPHY` | Coordenadas terrestres | Distancias en metros | Confundir el orden lat/long |
| `GEOMETRY` | Planos cartesianos | Operaciones geométricas | Usarlo con lat/long da grados |
| Tipo de tabla | Parámetros de SP con N filas | Carga masiva tipada | No admite `ALTER`; estimaciones de filas |
| Alias de tipo | Dominios repetidos (cédula, email) | Consistencia de tipo y longitud | No admite `ALTER`; sin reglas propias |

---

## 7. Notas para la Asignación 05

- **T2 (`email_alternativo`).** Agregar `email` y `email_alternativo` en `Cliente` es un **grupo repetitivo** encubierto (¿y si hay un tercero?). Desde la 1FN, la alternativa normalizada es una tabla `ClienteContacto (client_id, tipo, valor)`. Si se mantiene la columna, hay que **justificarlo** (máximo dos correos, regla de negocio). El alias `Cedula` debería **usarse** también, por ejemplo en una nueva columna o en los parámetros de los SP, para que el ejercicio tenga sentido.
- **T3 (`jerarquia` en `Empleado`).** Coexistirá con `boss_id`: documentar la redundancia y cómo se sincroniza (ver 2.1).
- **T5 (carga masiva de facturas).** Insertar facturas directamente desde un TVP **salta el flujo** cotización → aprobación → factura del Tema 01. Además, el trigger `INSTEAD OF` del Tema 02 **rechaza todo el lote** si **una sola** fila tiene el vehículo en un estado distinto de `Quoted`, y `UQ_Invoice_Quote` impide facturar dos veces la misma cotización. El procedimiento debe validar el lote completo dentro de una transacción e informar qué filas fallaron.

---

## 8. Ejercicios Prácticos

### Ejercicio 1: Configuración flexible

Crear `config.Cat_Setting` con `SQL_VARIANT`, insertar valores de al menos 5 tipos distintos (con `CAST` explícito) y listar el `BaseType` de cada uno.

### Ejercicio 2: Categorías jerárquicas

Crear una tabla de categorías con `HIERARCHYID`, sus dos índices (profundidad y anchura) y consultas para hijos directos, padre y subárbol completo. Insertar un nodo nuevo con `GetDescendant`.

### Ejercicio 3: Tipo de tabla

Crear un tipo de tabla para los accesorios de una cotización (`accessory_id`, `quantity`, `unit_price`) y un procedimiento transaccional que los inserte en `ventas.Cat_QuoteAccessory`.

### Ejercicio 4: Auditoría de tipos

Revisar las tablas de tu proyecto y proponer, con justificación, al menos 3 cambios de tipo según la tabla de la sección 0.

---

## 9. Preguntas de Autoevaluación

1. ¿Por qué `DECIMAL` y no `FLOAT` para montos de dinero?
2. ¿Qué ventajas tiene `DATETIME2` frente a `DATETIME`?
3. ¿Qué tipos **no** se pueden almacenar en `SQL_VARIANT` y cuál es su tamaño máximo?
4. ¿Por qué un modelo EAV con `SQL_VARIANT` choca con la 1FN?
5. ¿Qué nivel tiene el nodo `'/1/'` y por qué?
6. ¿Qué garantiza una lista de adyacencia con FK que `HIERARCHYID` no garantiza?
7. ¿Cuál es el orden de los argumentos en `geography::Point` y en el texto WKT?
8. ¿Cuándo usar un tipo de tabla en lugar de llamar N veces a un procedimiento?
9. ¿Qué pasos hay que seguir para "modificar" un alias de tipo?
10. ¿Qué permisos necesita un usuario para usar un TVP o un alias de tipo de otro esquema?

---

## 10. Recursos Adicionales

- [Data types (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/data-types/data-types-transact-sql)
- [sql_variant](https://learn.microsoft.com/en-us/sql/t-sql/data-types/sql-variant-transact-sql)
- [hierarchyid data type method reference](https://learn.microsoft.com/en-us/sql/t-sql/data-types/hierarchyid-data-type-method-reference)
- [Spatial data (SQL Server)](https://learn.microsoft.com/en-us/sql/relational-databases/spatial/spatial-data-sql-server)
- [Use table-valued parameters](https://learn.microsoft.com/en-us/sql/relational-databases/tables/use-table-valued-parameters-database-engine)
- [CREATE TYPE](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-type-transact-sql)
