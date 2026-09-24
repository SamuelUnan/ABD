# 05. Tipos de Datos Avanzados

## 1. SQL_VARIANT

### 1.1 ¿Qué es?

`SQL_VARIANT` es un tipo de datos que puede almacenar **cualquier tipo** de datos (excepto `TIMESTAMP`, `VARCHAR(MAX)`, `NVARCHAR(MAX)`, `VARBINARY(MAX)` y tipos LOB).

### 1.2 ¿Cuándo Usar?

- Tablas que almacenan valores de **diferentes tipos**
- Columnas que pueden contener texto, números o fechas según la fila
- Flexible para esquemas que cambian frecuentemente

### 1.3 Ejemplo

```sql
CREATE TABLE Configuracion (
    id INT IDENTITY PRIMARY KEY,
    parametro VARCHAR(50) NOT NULL,
    valor SQL_VARIANT  -- Puede ser INT, VARCHAR, DATE, etc.
);

INSERT INTO Configuracion (parametro, valor) VALUES
('_max_conexiones', 100),           -- INT
('nombre_empresa', 'TechCorp'),     -- VARCHAR
('fecha_fundacion', '2020-01-15'),  -- DATE (como string)
('activo', 1);                      -- BIT

-- Consultar
SELECT 
    parametro,
    valor,
    SQL_VARIANT_PROPERTY(valor, 'BaseType') AS tipo_dato,
    SQL_VARIANT_PROPERTY(valor, 'Precision') AS precision
FROM Configuracion;
```

### 1.4 Funciones de SQL_VARIANT

```sql
-- Obtener el tipo base
SQL_VARIANT_PROPERTY(valor, 'BaseType')    -- 'int', 'varchar', etc.

-- Obtener precisión
SQL_VARIANT_PROPERTY(valor, 'Precision')   -- 10, 50, etc.

-- Obtener escala
SQL_VARIANT_PROPERTY(valor, 'Scale')       -- 2, 0, etc.

-- Obtener longitud máxima en bytes
SQL_VARIANT_PROPERTY(valor, 'MaxLength')   -- 8, 100, etc.
```

---

## 2. HIERARCHYID

### 2.1 ¿Qué es?

`HIERARCHYID` es un tipo de datos optimizado para almacenar **estructuras jerárquicas** (árboles). Permite representar la posición de un nodo en una jerarquía.

### 2.2 ¿Cuándo Usar?

- Estructuras organizacionales
- Categorías de productos anidadas
- Menús de navegación
- Árboles genealógicos
- Estructuras de archivos/carpetas

### 2.3 Ejemplo

```sql
-- Tabla de categorías
CREATE TABLE Categoria (
    id_categoria INT IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    nivel_jerarquia HIERARCHYID NOT NULL,
    nivel_int AS nivel_jerarquia.GetLevel() PERSISTED  -- Nivel calculado
);

-- Insertar categorías
INSERT INTO Categoria (nombre, nivel_jerarquia) VALUES
('Electrónica', '/1/'),           -- Nivel 0
('Computadoras', '/1/1/'),        -- Nivel 1
('Laptops', '/1/1/1/'),           -- Nivel 2
('Desktops', '/1/1/2/'),          -- Nivel 2
('Celulares', '/1/2/'),           -- Nivel 1
('Accesorios', '/1/3/');          -- Nivel 1

-- Consultar jerarquía
SELECT 
    nombre,
    nivel_jerarquia.ToString() AS ruta,
    nivel_jerarquia.GetLevel() AS nivel
FROM Categoria
ORDER BY nivel_jerarquia;
```

### 2.4 Operaciones con HIERARCHYID

```sql
-- Obtener hijos directos
SELECT * FROM Categoria
WHERE nivel_jerarquia.GetAncestor(1) = '/1/';

-- Obtener todos los descendientes
SELECT * FROM Categoria
WHERE nivel_jerarquia.IsDescendantOf('/1/1/') = 1;

-- Obtener padre
SELECT nivel_jerarquia.GetParent() AS padre
FROM Categoria
WHERE id_categoria = 3;

-- Obtener nivel
SELECT nivel_jerarquia.GetLevel() AS nivel
FROM Categoria;
```

---

## 3. GEOGRAPHY y GEOMETRY

### 3.1 GEOGRAPHY (Datos Geográficos)

Almacena datos de **latitud y longitud** en la superficie de la Tierra.

```sql
CREATE TABLE PuntoInteres (
    id INT IDENTITY PRIMARY KEY,
    nombre VARCHAR(100),
    ubicacion GEOGRAPHY
);

-- Insertar punto (latitud, longitud)
INSERT INTO PuntoInteres (nombre, ubicacion) VALUES
('UNAN-Managua', GEOGRAPHY::Point(12.0947, -86.2758, 4326)),
('Catedral', GEOGRAPHY::Point(12.1150, -86.2362, 4326));

-- Calcular distancia entre puntos (en metros)
SELECT 
    a.nombre AS punto_a,
    b.nombre AS punto_b,
    a.ubicacion.STDistance(b.ubicacion) AS distancia_metros
FROM PuntoInteres a, PuntoInteres b
WHERE a.id < b.id;
```

### 3.2 GEOMETRY (Datos Geométricos)

Almacena datos de **coordenadas planas** (2D).

```sql
CREATE TABLE Edificio (
    id INT IDENTITY PRIMARY KEY,
    nombre VARCHAR(100),
    forma GEOMETRY
);

-- Insertar polígono (rectángulo)
INSERT INTO Edificio (nombre, forma) VALUES
('Biblioteca', GEOMETRY::STGeomFromText('POLYGON((-86.2760 12.0948, -86.2755 12.0948, -86.2755 12.0950, -86.2760 12.0950, -86.2760 12.0948))', 4326));

-- Verificar si un punto está dentro de un polígono
SELECT nombre FROM Edificio
WHERE forma.STContains(GEOMETRY::Point(-86.2757, 12.0949, 4326)) = 1;
```

---

## 4. Tipos de Tabla Personalizados

### 4.1 ¿Qué es?

Permite definir un **tipo de tabla** que se puede reutilizar como tipo de parámetro en procedimientos almacenados.

### 4.2 Sintaxis

```sql
-- Crear tipo de tabla
CREATE TYPE TipoTablaProducto AS TABLE (
    id_producto INT,
    nombre VARCHAR(100),
    precio DECIMAL(10,2),
    cantidad INT
);
GO

-- Usar en procedimiento
CREATE PROCEDURE sp_InsertarProductos
    @productos TipoTablaProducto READONLY
AS
BEGIN
    INSERT INTO Producto (id_producto, nombre, precio, stock)
    SELECT id_producto, nombre, precio, cantidad
    FROM @productos;
END;
GO

-- Ejecutar
DECLARE @nuevosProductos TipoTablaProducto;
INSERT INTO @nuevosProductos VALUES (1, 'Producto A', 10.50, 100);
INSERT INTO @nuevosProductos VALUES (2, 'Producto B', 20.00, 50);

EXEC sp_InsertarProductos @nuevosProductos;
```

### 4.3 Ventajas

- Reutilización de estructura
- Tipado fuerte
- Mejor rendimiento que pasar múltiples parámetros
- Ideal para operaciones masivas

---

## 5. Alias de Tipos (User-Defined Types)

### 5.1 ¿Qué es?

Un alias de tipo es un nombre personalizado para un tipo de datos existente.

### 5.2 Sintaxis

```sql
-- Crear alias de tipo
CREATE TYPE Email FROM VARCHAR(100) NOT NULL;
CREATE TYPE Telefono FROM VARCHAR(20) NULL;
CREATE TYPE Cantidad FROM INT NOT NULL;
GO

-- Usar en tabla
CREATE TABLE Cliente (
    id_cliente INT IDENTITY PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL,
    email Email,
    telefono Telefono
);

-- Usar en procedimiento
CREATE PROCEDURE sp_BuscarCliente
    @email_busqueda Email
AS
BEGIN
    SELECT * FROM Cliente WHERE email = @email_busqueda;
END;
```

### 5.3 Eliminar Tipo

```sql
-- Primero eliminar objetos que lo usan
DROP TABLE IF EXISTS Cliente;
DROP PROCEDURE IF EXISTS sp_BuscarCliente;

-- Luego eliminar el tipo
DROP TYPE IF EXISTS Email;
```

---

## 6. Comparativa de Tipos

| Tipo | Uso Principal | Ventaja |
|------|---------------|---------|
| SQL_VARIANT | Almacenar múltiples tipos | Flexibilidad |
| HIERARCHYID | Estructuras jerárquicas | Rendimiento en árboles |
| GEOGRAPHY | Coordenadas geográficas | Cálculos de distancia |
| GEOMETRY | Coordenadas planas | Operaciones geométricas |
| Tipo de tabla | Parámetros de SP | Reutilización, tipado |
| Alias de tipo | Nombres personalizados | Legibilidad |

---

## 7. Ejercicios Prácticos

### Ejercicio 1: Configuración Flexible

Crear una tabla `Configuracion` usando `SQL_VARIANT` que almacene diferentes tipos de configuración del sistema.

### Ejercicio 2: Categorías Jerárquicas

Crear una tabla de categorías de productos usando `HIERARCHYID` y consultas para obtener hijos, padres y descendientes.

### Ejercicio 3: Tipo de Tabla

Crear un tipo de tabla para detalles de pedido y usarlo en un procedimiento que inserte múltiples detalles.

---

## 8. Preguntas de Autoevaluación

1. ¿Qué tipos de datos NO se pueden almacenar en SQL_VARIANT?
2. ¿Cómo se obtiene el nivel de un nodo con HIERARCHYID?
3. ¿Cuál es la diferencia entre GEOGRAPHY y GEOMETRY?
4. ¿Cuándo usar un tipo de tabla en lugar de múltiples parámetros?
5. ¿Cómo se crea un alias de tipo?
6. ¿Por qué HIERARCHYID es más eficiente que una jerarquía recursiva tradicional?
7. ¿Qué retorna SQL_VARIANT_PROPERTY?
8. ¿Cómo se verifica si un punto está dentro de un polígono?
9. ¿Cuáles son las ventajas de tipos de tabla personalizados?
10. ¿Cómo se eliminan tipos de datos personalizados?

---

## 9. Recursos Adicionales

- [SQL_VARIANT](https://learn.microsoft.com/en-us/sql/t-sql/data-types/sql-variant-transact-sql)
- [HierarchyID](https://learn.microsoft.com/en-us/sql/t-sql/data-types/hierarchyid-data-type)
- [Spatial Data](https://learn.microsoft.com/en-us/sql/relational-databases/spatial/spatial-data-sql-server)
