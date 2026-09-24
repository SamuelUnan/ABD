# 06. Índices y Optimización de Consultas

## 1. ¿Qué es un Índice?

Un **índice** es una estructura que acelera la búsqueda de registros en una tabla. Es como el índice de un libro: permite encontrar información sin leer todo el contenido.

### 1.1 Sin índice vs Con índice

| Sin índice | Con índice |
|------------|------------|
| Escaneo completo de tabla | Búsqueda dirigida |
| O(n) complejidad | O(log n) complejidad |
| Lento para tablas grandes | Rápido incluso con millones de filas |

---

## 2. Tipos de Índices

### 2.1 Índice Clustered

- **Reorganiza físicamente** las filas de la tabla según el orden del índice
- Solo **UNO por tabla** (la tabla solo tiene un "orden físico")
- Es la estructura de la tabla misma
- Cada tabla tiene un clustered index (creado con PK)

```sql
-- Crear clustered index (generalmente se crea con PK)
CREATE CLUSTERED INDEX ix_producto_id
ON Producto(id_producto);

-- Nota: Generalmente se crea con PRIMARY KEY
CREATE TABLE Producto (
    id_producto INT IDENTITY PRIMARY KEY,  -- Crea clustered index automáticamente
    nombre VARCHAR(100)
);
```

### 2.2 Índice Non-Clustered

- Crea una **estructura separada** con punteros a las filas
- Puede haber **múltiples** non-clustered indexes (hasta 999)
- No altera el orden físico de la tabla
- Ideal para búsquedas frecuentes

```sql
-- Crear non-clustered index
CREATE NONCLUSTERED INDEX ix_producto_nombre
ON Producto(nombre);

-- Crear con columnas incluidas (covering index)
CREATE NONCLUSTERED INDEX ix_producto_categoria
ON Producto(id_categoria)
INCLUDE (nombre, precio);  -- Estas columnas se almacenan en el índice
```

### 2.3 Columnstore Index

- Optimizado para **consultas analíticas** (OLAP)
- Almacena datos **por columnas** en lugar de por filas
- Excelente para SUM, COUNT, AVG, GROUP BY
- Ideal para tablas grandes de solo lectura

```sql
-- Crear columnstore index
CREATE NONCLUSTERED COLUMNSTORE INDEX ix_venta_analitico
ON Venta (id_producto, fecha, monto, cantidad);
```

### 2.4 Índice Filtrado

- Solo indexa filas que cumplen una **condición**
- Útil cuando se consultan subconjuntos específicos

```sql
-- Solo indexar clientes activos
CREATE NONCLUSTERED INDEX ix_cliente_activo
ON Cliente(nombre, email)
WHERE estado = 'Activo';
```

---

## 3. Crear Índices

### 3.1 Sintaxis Completa

```sql
CREATE [NONCLUSTERED] INDEX nombre_index
ON tabla (columna1, columna2, ...)
INCLUDE (columna3, columna4)  -- Opcional
WITH (
    ONLINE = ON,              -- Crear sin bloquear la tabla
    FILLFACTOR = 80,          -- Porcentaje de llenado inicial
    DROP_EXISTING = ON        -- Reemplazar índice existente
);
```

### 3.2 Ejemplos Prácticos

```sql
-- Índice simple
CREATE NONCLUSTERED INDEX ix_venta_fecha
ON Venta(fecha);

-- Índice compuesto
CREATE NONCLUSTERED INDEX ix_venta_cliente_producto
ON Venta(id_cliente, id_producto);

-- Índice covering (con INCLUDE)
CREATE NONCLUSTERED INDEX ix_venta_reporte
ON Venta(fecha, id_cliente)
INCLUDE (monto, estado);

-- Índice filtrado
CREATE NONCLUSTERED INDEX ix_venta_activas
ON Venta(fecha)
WHERE estado = 'Completada';
```

---

## 4. Gestión de Índices

### 4.1 Ver Índices Existentes

```sql
-- Ver todos los índices de una tabla
EXEC sp_helpindex 'Producto';

-- Ver índices con más detalle
SELECT 
    i.name AS indice,
    i.type_desc AS tipo,
    COL_NAME(ic.object_id, ic.column_id) AS columna
FROM sys.indexes i
INNER JOIN sys.index_columns ic 
    ON i.object_id = ic.object_id AND i.index_id = ic.index_id
WHERE i.object_id = OBJECT_ID('Producto');
```

### 4.2 Reorganizar y Reconstruir

```sql
-- Reorganizar (menos intensivo, mantiene la tabla disponible)
ALTER INDEX ix_producto_nombre ON Producto REORGANIZE;

-- Reconstruir (más intensivo, pero más efectivo)
ALTER INDEX ix_producto_nombre ON Producto REBUILD;

-- Reconstruir todos los índices de una tabla
ALTER INDEX ALL ON Producto REBUILD;
```

### 4.3 Deshabilitar/Eliminar

```sql
-- Deshabilitar (mantiene la estructura)
ALTER INDEX ix_producto_nombre ON Producto DISABLE;

-- Habilitar
ALTER INDEX ix_producto_nombre ON Producto REBUILD;

-- Eliminar
DROP INDEX ix_producto_nombre ON Producto;
```

---

## 5. Estadísticas

### 5.1 ¿Qué son?

Las **estadísticas** son objetos que contienen información sobre la **distribución de valores** en las columnas. SQL Server las usa para crear planes de ejecución óptimos.

### 5.2 Ver Estadísticas

```sql
-- Ver estadísticas de una tabla
SELECT 
    name AS estadistica,
    auto_created,
    user_created
FROM sys.stats
WHERE object_id = OBJECT_ID('Producto');

-- Ver detalles de una estadística
DBCC SHOW_STATISTICS ('Producto', 'ix_producto_nombre');
```

### 5.3 Actualizar Estadísticas

```sql
-- Actualizar estadísticas de una tabla
UPDATE STATISTICS Producto;

-- Actualizar todas las estadísticas de la BD
EXEC sp_updatestats;
```

---

## 6. Planes de Ejecución

### 6.1 Ver Plan de Ejecución

```sql
-- Habilitar plan de ejecución
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- Ejecutar consulta
SELECT * FROM Producto WHERE nombre = 'Laptop';

-- Ver plan (en SSMS: Ctrl + M para "Include Actual Execution Plan")
```

### 6.2 Operadores Comunes

| Operador | Significado |
|----------|-------------|
| **Table Scan** | Escaneo completo (sin índice) |
| **Index Scan** | Usa índice pero lee todas las filas |
| **Index Seek** | Búsqueda eficiente en índice |
| **Nested Loops** | Join para tablas pequeñas |
| **Hash Match** | Join para tablas grandes |
| **Sort** | Ordenamiento (puede ser costoso) |

### 6.3 Indicadores de Rendimiento

| Indicador | Bueno | Malo |
|-----------|-------|------|
| **Estimated vs Actual Rows** | Cercanos | Muy diferentes |
| **Key Lookups** | Pocos | Muchos |
| **Table Scan** | En tablas pequeñas | En tablas grandes |
| **Cost %** | Bajo | Alto (>50%) |

---

## 7. Buenas Prácticas

### 7.1 Cuándo Crear Índices

| Crear índice en | No crear índice en |
|-----------------|---------------------|
| Columnas en WHERE | Tablas muy pequeñas |
| Columnas en JOIN | Columnas con baja selectividad |
| Columnas en ORDER BY | Columnas que cambian mucho |
| Columnas en GROUP BY | Tablas de escritura intensiva |

### 7.2 Reglas de Oro

| Regla | Descripción |
|-------|-------------|
| PK siempre crea clustered | No crear otro clustered |
| Índices en columnas de filtro | WHERE, JOIN, ORDER BY |
| INCLUDE para covering index | Evitar key lookups |
| No abusar | Cada índice afecta INSERT/UPDATE |
| Monitorear uso | Eliminar índices no usados |
| REBUILD periódicamente | Mantener estadísticas actualizadas |

### 7.3 Errores Comunes

```sql
-- ❌ ERROR: Crear índice en columna con poca selectividad
CREATE INDEX ix_estado ON Pedido(estado);  -- Solo 3 valores posibles

-- ✅ CORRECTO: Crear índice en columna con alta selectividad
CREATE INDEX ix_fecha ON Pedido(fecha_pedido);
```

---

## 8. SET STATISTICS

```sql
-- Mostrar operaciones de E/S
SET STATISTICS IO ON;
SET STATISTICS IO OFF;

-- Mostrar tiempo de ejecución
SET STATISTICS TIME ON;
SET STATISTICS TIME OFF;

-- Ejemplo de salida
/*
Table 'Producto'. Scan count 1, logical reads 5, physical reads 0, read-ahead reads 0.
SQL Server Execution Times:
   CPU time = 0 ms,  elapsed time = 1 ms.
*/
```

---

## 9. Ejercicios Prácticos

### Ejercicio 1: Analizar Rendimiento

1. Crear tabla con 100,000 registros
2. Ejecutar consulta sin índice y medir tiempo
3. Crear índice apropiado
4. Ejecutar la misma consulta y comparar

### Ejercicio 2: Diseñar Índices

Para una tabla `Venta` con columnas: id_venta, id_cliente, id_producto, fecha, monto:
1. Identificar las columnas más consultadas
2. Crear índices apropiados
3. Crear un covering index para un reporte específico

### Ejercicio 3: Monitorear Rendimiento

1. Usar SET STATISTICS IO/TIME
2. Analizar el plan de ejecución
3. Identificar cuellos de botella
4. Optimizar la consulta

---

## 10. Preguntas de Autoevaluación

1. ¿Cuál es la diferencia entre clustered y non-clustered?
2. ¿Cuántos clustered indexes puede tener una tabla?
3. ¿Qué es un covering index?
4. ¿Cuándo usar un columnstore index?
5. ¿Qué es un filtered index?
6. ¿Cuándo usar REBUILD vs REORGANIZE?
7. ¿Qué indican las estadísticas?
8. ¿Cómo se interpreta un plan de ejecución?
9. ¿Qué significa "Key Lookup"?
10. ¿Por qué no se debe crear demasiados índices?

---

## 11. Recursos Adicionales

- [Create Index](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-index-transact-sql)
- [Index Design Guidelines](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/index-design-guidance)
- [Execution Plans](https://learn.microsoft.com/en-us/sql/relational-databases/performance/execution-plans)
