# 04. Common Table Expressions (CTE)

## 1. ¿Qué es una CTE?

Una **Common Table Expression (CTE)** es un resultado temporal nombrado que se define con la palabra clave `WITH`. Se puede usar una sola vez en una consulta `SELECT`, `INSERT`, `UPDATE` o `DELETE`.

### 1.1 Ventajas

| Ventaja | Descripción |
|---------|-------------|
| **Legibilidad** | Divide consultas complejas en pasos lógicos |
| **Reutilización** | Se puede referenciar múltiples veces en la misma consulta |
| **Recursión** | Permite consultar datos jerárquicos |
| **Mantenimiento** | Más fácil de entender y modificar que subqueries |

---

## 2. Sintaxis Básica

```sql
WITH nombre_cte AS (
    -- Consulta que define la CTE
    SELECT columna1, columna2
    FROM tabla
    WHERE condicion
)
-- Consulta principal que usa la CTE
SELECT *
FROM nombre_cte;
```

---

## 3. CTE No Recursivo

### 3.1 Ejemplo Simple

```sql
-- Empleados con salario mayor al promedio
WITH EmpleadosAltoSalario AS (
    SELECT 
        nombre,
        departamento,
        salario
    FROM Empleado
    WHERE salario > (SELECT AVG(salario) FROM Empleado)
)
SELECT * FROM EmpleadosAltoSalario;
```

### 3.2 Múltiples CTEs

```sql
-- Podemos definir varias CTEs separadas por comas
WITH 
VentasPorCliente AS (
    SELECT 
        id_cliente,
        SUM(monto) AS total_ventas
    FROM Venta
    GROUP BY id_cliente
),
TopClientes AS (
    SELECT 
        id_cliente,
        total_ventas,
        ROW_NUMBER() OVER (ORDER BY total_ventas DESC) AS ranking
    FROM VentasPorCliente
)
SELECT 
    c.nombre,
    tc.total_ventas,
    tc.ranking
FROM TopClientes tc
INNER JOIN Cliente c ON tc.id_cliente = c.id_cliente
WHERE tc.ranking <= 10;
```

### 3.3 CTE para Actualización

```sql
-- Actualizar precios de productos con stock bajo
WITH ProductosStockBajo AS (
    SELECT id_producto, precio
    FROM Producto
    WHERE stock < 10
)
UPDATE ProductosStockBajo
SET precio = precio * 1.10;  -- Aumentar 10%

-- Eliminar registros duplicados
WITH Duplicados AS (
    SELECT 
        id,
        ROW_NUMBER() OVER (PARTITION BY email ORDER BY id) AS rn
    FROM Cliente
)
DELETE FROM Duplicados WHERE rn > 1;
```

---

## 4. CTE Recursivo

### 4.1 ¿Qué es?

Un CTE recursivo se llama a **sí mismo** para procesar datos jerárquicos (árboles, estructuras organizacionales, categorías anidadas).

### 4.2 Sintaxis

```sql
WITH nombre_cte AS (
    -- Caso base (anchor member)
    SELECT columnas
    FROM tabla
    WHERE condicion_inicial
    
    UNION ALL
    
    -- Caso recursivo (recursive member)
    SELECT columnas
    FROM tabla
    INNER JOIN nombre_cte ON tabla.padre = nombre_cte.id
)
SELECT * FROM nombre_cte
OPTION (MAXRECURSION 100);  -- Límite de recursión
```

### 4.3 Ejemplo: Estructura Organizacional

```sql
-- Tabla de empleados con jefe
CREATE TABLE Empleado (
    id_empleado INT PRIMARY KEY,
    nombre VARCHAR(80),
    id_jefe INT NULL,
    FOREIGN KEY (id_jefe) REFERENCES Empleado(id_empleado)
);

-- CTE recursivo para obtener toda la jerarquía
WITH Jerarquia AS (
    -- Caso base: empleados sin jefe (raíz)
    SELECT 
        id_empleado,
        nombre,
        id_jefe,
        0 AS nivel,
        CAST(nombre AS VARCHAR(MAX)) AS ruta
    FROM Empleado
    WHERE id_jefe IS NULL
    
    UNION ALL
    
    -- Caso recursivo: empleados con jefe
    SELECT 
        e.id_empleado,
        e.nombre,
        e.id_jefe,
        j.nivel + 1,
        CAST(j.ruta + ' → ' + e.nombre AS VARCHAR(MAX))
    FROM Empleado e
    INNER JOIN Jerarquia j ON e.id_jefe = j.id_empleado
)
SELECT 
    id_empleado,
    nombre,
    nivel,
    ruta
FROM Jerarquia
ORDER BY ruta
OPTION (MAXRECURSION 10);
```

**Resultado:**
| id_empleado | nombre | nivel | ruta |
|-------------|--------|-------|------|
| 1 | Director | 0 | Director |
| 2 | Gerente Ventas | 1 | Director → Gerente Ventas |
| 3 | Gerente IT | 1 | Director → Gerente IT |
| 4 | Vendedor | 2 | Director → Gerente Ventas → Vendedor |
| 5 | Desarrollador | 2 | Director → Gerente IT → Desarrollador |

### 4.4 Ejemplo: Categorías de Productos

```sql
-- Tabla de categorías anidadas
CREATE TABLE Categoria (
    id_categoria INT PRIMARY KEY,
    nombre VARCHAR(50),
    id_padre INT NULL,
    FOREIGN KEY (id_padre) REFERENCES Categoria(id_categoria)
);

-- Obtener ruta completa de cada categoría
WITH RutaCategoria AS (
    SELECT 
        id_categoria,
        nombre,
        id_padre,
        CAST(nombre AS VARCHAR(200)) AS ruta_completa
    FROM Categoria
    WHERE id_padre IS NULL
    
    UNION ALL
    
    SELECT 
        c.id_categoria,
        c.nombre,
        c.id_padre,
        CAST(rc.ruta_completa + ' > ' + c.nombre AS VARCHAR(200))
    FROM Categoria c
    INNER JOIN RutaCategoria rc ON c.id_padre = rc.id_categoria
)
SELECT * FROM RutaCategoria;
```

### 4.5 Ejemplo: Numeración de Niveles

```sql
-- Árbol genealógico con numeración
WITH Arbol AS (
    SELECT 
        id,
        nombre,
        id_padre,
        0 AS nivel,
        CAST(RIGHT('000' + CAST(id AS VARCHAR), 4) AS VARCHAR(MAX)) AS orden
    FROM Persona
    WHERE id_padre IS NULL
    
    UNION ALL
    
    SELECT 
        p.id,
        p.nombre,
        p.id_padre,
        a.nivel + 1,
        CAST(a.orden + '.' + RIGHT('000' + CAST(p.id AS VARCHAR), 4) AS VARCHAR(MAX))
    FROM Persona p
    INNER JOIN Arbol a ON p.id_padre = a.id
)
SELECT 
    REPEAT('  ', nivel) + nombre AS estructura,
    nivel,
    orden
FROM Arbol
ORDER BY orden;
```

---

## 5. CTE vs Subquery vs Vista

| Característica | CTE | Subquery | Vista |
|----------------|-----|----------|-------|
| Reutilización | Una vez en la consulta | Una vez por ubicación | Múltiples veces |
| Recursión | Sí | No | No |
| Almacenamiento | No persiste | No persiste | Sí (en metadatos) |
| Legibilidad | Alta | Baja | Media |
| Rendimiento | Similar a subquery | Similar a CTE | Indexable |

---

## 6. Buenas Prácticas

### 6.1 Cuándo Usar CTE

| Usar CTE | No usar CTE |
|----------|-------------|
| Consultas jerárquicas | Para algo que una vista resuelve |
| Consultas complejas que necesitan reutilización | Para consultas simples |
| Cuando necesitas legibilidad | Cuando la vista ya existe |
| Para actualizaciones con lógica compleja | |

### 6.2 Limitaciones

```sql
-- La CTE solo se usa una vez (a menos que se referencie múltiples veces)
WITH MiCTE AS (
    SELECT * FROM Tabla
)
SELECT * FROM MiCTE
UNION ALL
SELECT * FROM MiCTE;  -- Esto funciona, pero se ejecuta dos veces
```

### 6.3 MAXRECURSION

```sql
-- Por defecto es 100, se puede ajustar
WITH Jerarquia AS (
    ...
)
SELECT * FROM Jerarquia
OPTION (MAXRECURSION 0);  -- Sin límite (usar con precaución)
```

---

## 7. Ejercicios Prácticos

### Ejercicio 1: Jerarquía de Empleados

Dada una tabla `Empleado` con `id_empleado`, `nombre`, `id_jefe`:
1. Obtener la jerarquía completa con nivel
2. Obtener la ruta de cada empleado
3. Contar subordinados por cada jefe

### Ejercicio 2: Datos Jerárquicos de Categorías

Dada una tabla `Categoria` con `id_categoria`, `nombre`, `id_padre`:
1. Obtener todas las subcategorías de una categoría padre
2. Obtener la profundidad máxima del árbol
3. Obtener hojas (categorías sin hijas)

### Ejercicio 3: Consultas Complejas

Usar CTEs para:
1. Calcular el promedio de ventas por cliente y comparar con el global
2. Identificar clientes que no han comprado en los últimos 3 meses
3. Generar un reporte con acumulados mensuales

---

## 8. Preguntas de Autoevaluación

1. ¿Qué es una CTE y cuándo usarla?
2. ¿Cuál es la diferencia entre CTE no recursivo y recursivo?
3. ¿Qué es el "caso base" en un CTE recursivo?
4. ¿Cómo se controla el número máximo de recursiones?
5. ¿Cuándo usar CTE en lugar de subquery?
6. ¿Cuándo usar CTE en lugar de vista?
7. ¿Cómo se actualizan datos usando una CTE?
8. ¿Qué datos se pueden almacenar en una CTE recursiva?
9. ¿Por qué es importante la legibilidad en CTEs complejas?
10. ¿Cuáles son las limitaciones de las CTEs?

---

## 9. Recursos Adicionales

- [WITH Common Table Expression](https://learn.microsoft.com/en-us/sql/t-sql/queries/with-common-table-expression-transact-sql)
- [Recursive CTE Examples](https://learn.microsoft.com/en-us/sql/relational-databases/hierarchical-data-sql-server)
