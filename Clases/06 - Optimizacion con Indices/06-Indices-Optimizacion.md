# 06. Índices y Optimización de Consultas

## 1. ¿Qué es un Índice?

Un **índice** es una estructura adicional, organizada como **árbol B+ (B-tree)**, que permite localizar filas sin leer toda la tabla. Funciona como el índice de un libro: se busca la clave y se llega directamente a la página.

### 1.1 Sin índice vs Con índice

| Sin índice adecuado | Con índice adecuado |
|---------------------|---------------------|
| Recorrido completo (*scan*) de la tabla | Búsqueda dirigida (*seek*) |
| Costo proporcional a **n** filas | Costo proporcional a la **altura del árbol** (≈ log n: 3–4 niveles para millones de filas) |
| Lento en tablas grandes | Rápido incluso con millones de filas |

### 1.2 Cómo se almacenan los datos

- SQL Server guarda los datos en **páginas de 8 KB**. Las lecturas se miden en páginas (*logical reads*).
- Una tabla **sin índice clustered** se llama **heap** (montón): las filas no tienen orden y se localizan por su **RID** (archivo:página:fila).
- Una tabla **con índice clustered** guarda las filas **en las hojas** de ese índice, ordenadas **lógicamente** por la clave.

---

## 2. Tipos de Índices

### 2.1 Índice Clustered

- **Es la tabla misma**: el nivel hoja del árbol contiene las filas completas.
- Define el **orden lógico** de las filas según la clave. Las páginas **no** quedan necesariamente contiguas en disco: se enlazan entre sí, y con el tiempo aparece la **fragmentación** (sección 4).
- Solo puede haber **uno por tabla**.
- **No toda tabla lo tiene**: una tabla sin clustered es un *heap*.
- `PRIMARY KEY` crea un clustered **por defecto**, solo si la tabla aún no tiene uno. Se puede declarar `PRIMARY KEY NONCLUSTERED` y usar otra columna como clave clustered.

**Buena clave clustered:** estrecha, única, estática y creciente. Un `INT IDENTITY` cumple todo eso, y por eso ConcessionaireDB usa `invoice_id INT IDENTITY` como PK.

```sql
-- La PK crea el índice clustered (opción por defecto)
CREATE TABLE Producto (
    id_producto INT IDENTITY(1,1) NOT NULL,
    id_categoria INT NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    precio DECIMAL(12,2) NOT NULL,
    CONSTRAINT PK_Producto PRIMARY KEY CLUSTERED (id_producto)
);

-- Alternativa: PK no clustered y clustered sobre otra columna
CREATE TABLE Bitacora (
    bitacora_id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
    fecha DATETIME2(0) NOT NULL,
    CONSTRAINT PK_Bitacora PRIMARY KEY NONCLUSTERED (bitacora_id)
);
CREATE CLUSTERED INDEX CIX_Bitacora_Fecha ON Bitacora(fecha);
```

### 2.2 Índice Non-Clustered

- Es una **estructura separada** que contiene la clave del índice y un **localizador** de la fila:
  - en un **heap**, el **RID**;
  - en una tabla con clustered, la **clave clustered** (por eso conviene que sea estrecha).
- Puede haber hasta **999** por tabla.
- Si la consulta pide columnas que **no** están en el índice, SQL Server debe ir a buscarlas a la tabla con un **Key Lookup** (o RID Lookup), **una vez por fila**.

```sql
CREATE NONCLUSTERED INDEX IX_Producto_Nombre
ON Producto(nombre);

-- Índice "de cobertura" (covering): INCLUDE guarda columnas extra solo en la hoja
CREATE NONCLUSTERED INDEX IX_Producto_Categoria
ON Producto(id_categoria)
INCLUDE (nombre, precio);
```

> **Punto de inflexión (*tipping point*).** Si un *seek* + *lookups* devolvería un porcentaje alto de la tabla (a menudo apenas un 1–5 % de las filas), el optimizador prefiere **recorrer toda la tabla**: miles de lookups cuestan más que un *scan*. `INCLUDE` elimina los lookups y evita ese problema.

### 2.3 Índices que se crean solos (y los que NO)

| Restricción | ¿Crea índice? |
|-------------|---------------|
| `PRIMARY KEY` | **Sí** (clustered por defecto) |
| `UNIQUE` | **Sí** (non-clustered único) |
| `FOREIGN KEY` | **No** |

**Las FK no se indexan automáticamente en SQL Server.** Sin índice en la columna FK:

- los `JOIN` entre padre e hijo recorren la tabla hija completa;
- cada `DELETE`/`UPDATE` de la PK en la tabla padre recorre la hija para validar la FK, con más bloqueos.

Inventario de FK de ConcessionaireDB que conviene indexar (aquí, una cobertura por `UNIQUE` significa que ya existe un índice cuya **primera** columna es la FK):

| Tabla | Columna FK | ¿Cubierta por PK/UNIQUE? | Recomendación |
|-------|------------|---------------------------|---------------|
| `ventas.Cat_Quote` | `client_id`, `vehicle_id`, `employee_id`, `branch_id` | No | Indexar `client_id` y `vehicle_id` (consultas frecuentes) |
| `ventas.Cat_QuoteRevision` | `quote_id` | No | Indexar |
| `ventas.Cat_QuoteAccessory` | `quote_id` / `accessory_id` | `quote_id` sí (primera columna de la PK) | Indexar `accessory_id` |
| `ventas.Cat_Invoice` | `quote_id` | Sí (`UQ_Invoice_Quote`) | — |
| `ventas.Cat_Invoice` | `client_id`, `branch_id`, `vehicle_id` | No | Indexar según reportes (Asignación 06) |
| `ventas.Cat_Payment` | `invoice_id` | No | Indexar |
| `ventas.Cat_Registration`, `ventas.Cat_Delivery` | `invoice_id` | Sí (`UQ_*_Invoice`) | — |
| `catalogo.Cat_Vehicle` | `model_id` | No | Indexar (filtrado en la Asignación 06) |
| `catalogo.Cat_Model` | `brand_id` | Sí (`UQ_Model_Brand_Name`) | — |
| `personas.Cat_Employee` | `boss_id`, `branch_id` | No | Indexar `boss_id` (CTE recursiva, Tema 04) |

### 2.4 Columnstore

- Almacena los datos **por columna** y comprimidos. Es excelente para `SUM`, `COUNT`, `AVG` y `GROUP BY` sobre millones de filas (cargas **analíticas**, OLAP).
- En una base **OLTP** como la del proyecto se usa con cautela: un *non-clustered columnstore* sobre una tabla con mucha escritura puede servir para reportes en tiempo real, pero añade costo a cada `INSERT`/`UPDATE`.

```sql
CREATE NONCLUSTERED COLUMNSTORE INDEX NCCI_Invoice_Analitico
ON ventas.Cat_Invoice (invoice_date, branch_id, total);
```

### 2.5 Índice Filtrado

Solo indexa las filas que cumplen un `WHERE`. Es más pequeño, más barato de mantener y tiene **estadísticas más precisas**.

```sql
-- Solo vehículos disponibles (subconjunto consultado constantemente)
CREATE NONCLUSTERED INDEX IX_Vehicle_Available_Model
ON catalogo.Cat_Vehicle(model_id)
INCLUDE (vehicle_sale_price)
WHERE vehicle_state = 'Available';
```

Requisitos y advertencias:

- La consulta debe incluir un predicado **compatible** con el filtro: `WHERE vehicle_state = 'Available'` literal.
- Con consultas **parametrizadas** (`WHERE vehicle_state = @estado`) el optimizador **no** puede usar el índice, porque el plan debe servir para cualquier valor del parámetro.
- Las sesiones que modifican la tabla deben tener `ANSI_NULLS ON` y `QUOTED_IDENTIFIER ON` (valores por defecto en SSMS), o fallarán los `INSERT`/`UPDATE`.
- El filtro solo admite comparaciones simples (`=`, `<>`, `IN`, `IS NULL`…), no funciones ni `LIKE`.
- Caso clásico: `UNIQUE` que ignora los NULL, como `CREATE UNIQUE INDEX ... WHERE client_email IS NOT NULL`.

---

## 3. Diseño de Índices

### 3.1 Sintaxis

```sql
CREATE [UNIQUE] [CLUSTERED | NONCLUSTERED] INDEX nombre_indice
ON esquema.tabla (columna1 [ASC|DESC], columna2, ...)
[INCLUDE (columna3, columna4)]
[WHERE filtro]
[WITH (
    FILLFACTOR = 90,          -- % de llenado de las páginas hoja al crear/reconstruir
    PAD_INDEX = ON,           -- aplicar FILLFACTOR también a niveles intermedios
    ONLINE = ON,              -- sin bloquear la tabla: SOLO ediciones Enterprise/Developer
    DROP_EXISTING = ON        -- reemplazar un índice que YA EXISTE con el mismo nombre
)];
```

> `ONLINE = ON` falla en **Express** y **Standard** (Msg 1712). `DROP_EXISTING = ON` falla si el índice no existe (Msg 7999).

### 3.2 Orden de columnas en un índice compuesto

Un índice `(A, B, C)` está ordenado primero por `A`, luego por `B` dentro de `A`, y así sucesivamente. Por eso:

| Consulta | ¿Puede hacer *seek* en `(A, B, C)`? |
|----------|-------------------------------------|
| `WHERE A = 1` | Si |
| `WHERE A = 1 AND B = 2` | Si |
| `WHERE B = 2` | No (falta la columna **izquierda**) → scan |
| `WHERE A = 1 AND C = 3` | Si sobre `A`; `C` se filtra después |

**Reglas:**

1. Las columnas de **igualdad** van primero y las de **rango** (`>`, `BETWEEN`, `LIKE 'x%'`) después.
2. Entre las de igualdad, primero la **más usada** por las consultas.
3. Las columnas que solo se **muestran** van en `INCLUDE`, no en la clave.

### 3.3 Consultas SARGables (*Search ARGument ABLE*)

El índice solo sirve para buscar si la **columna queda "limpia"** en el predicado.

| No SARGable (scan) | SARGable (seek) |
|-----------------------|-------------------|
| `WHERE YEAR(invoice_date) = 2026 AND MONTH(invoice_date) = 10` | `WHERE invoice_date >= '2026-10-01' AND invoice_date < '2026-11-01'` |
| `WHERE CAST(invoice_date AS DATE) = '2026-10-08'` ¹ | `WHERE invoice_date >= '2026-10-08' AND invoice_date < '2026-10-09'` |
| `WHERE total * 1.15 > 30000` | `WHERE total > 30000 / 1.15` |
| `WHERE LEFT(client_lastname, 3) = 'Lop'` | `WHERE client_lastname LIKE 'Lop%'` |
| `WHERE client_lastname LIKE '%pez'` | *(comodín inicial: no tiene arreglo con un índice normal)* |
| `WHERE client_cedula = @p` con `@p NVARCHAR` y columna `VARCHAR` | Declarar `@p VARCHAR(20)` (mismo tipo, **Tema 05**) |

¹ `CAST(col AS DATE)` es una excepción que el optimizador sí sabe convertir en rango, pero conviene no depender de ella.

---

## 4. Fragmentación y Mantenimiento

### 4.1 *Page splits* y FILLFACTOR

Al insertar o actualizar una fila en una página **llena**, SQL Server la **divide** (*page split*): mueve la mitad de las filas a una página nueva. Esto produce:

- **fragmentación lógica**: el orden de las páginas ya no coincide con el orden de la clave;
- **páginas medio vacías**: más lecturas para los mismos datos.

`FILLFACTOR = 90` deja un 10 % libre en cada página para absorber inserciones intermedias. En claves **crecientes** (`IDENTITY`, fechas de alta) las inserciones van al final, así que conviene dejarlo en 100 (el valor por defecto, equivalente a 0).

### 4.2 Medir la fragmentación

```sql
SELECT OBJECT_SCHEMA_NAME(ips.object_id) + '.' + OBJECT_NAME(ips.object_id) AS tabla,
       i.name AS indice,
       ips.index_type_desc,
       ips.avg_fragmentation_in_percent,
       ips.page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
INNER JOIN sys.indexes i ON i.object_id = ips.object_id AND i.index_id = ips.index_id
WHERE ips.page_count > 100          -- en índices pequeños la fragmentación es irrelevante
ORDER BY ips.avg_fragmentation_in_percent DESC;
```

### 4.3 REORGANIZE vs REBUILD

| | `REORGANIZE` | `REBUILD` |
|---|---|---|
| Qué hace | Reordena y compacta las páginas hoja **en su lugar** | **Recrea** el índice desde cero |
| Bloqueo | Siempre en línea, con bloqueos breves | Bloquea la tabla (salvo `ONLINE = ON` en Enterprise) |
| Se puede interrumpir | Sí, sin perder lo avanzado | Si se cancela, se revierte todo |
| Estadísticas | **No** las actualiza | **Sí**, con `FULLSCAN` (solo las del índice) |
| Aplica FILLFACTOR | No | Sí |
| Log de transacciones | Moderado | Alto (modelo FULL) |
| Umbral orientativo ² | Fragmentación **5–30 %** | Fragmentación **> 30 %** |

² Son los umbrales clásicos de la documentación de Microsoft. Con almacenamiento SSD, muchos DBA priorizan la **densidad de páginas** y las **estadísticas** sobre el porcentaje de fragmentación. Lo importante es **medir antes de actuar**.

```sql
-- Índice de la T2 de la Asignación 06 (fecha de factura, incluye sucursal y total)
CREATE NONCLUSTERED INDEX IX_Invoice_Date
ON ventas.Cat_Invoice(invoice_date)
INCLUDE (branch_id, total);

ALTER INDEX IX_Invoice_Date ON ventas.Cat_Invoice REORGANIZE;
ALTER INDEX IX_Invoice_Date ON ventas.Cat_Invoice REBUILD WITH (FILLFACTOR = 90);
ALTER INDEX ALL ON ventas.Cat_Invoice REBUILD;
```

### 4.4 Deshabilitar y eliminar

```sql
ALTER INDEX IX_Producto_Nombre ON Producto DISABLE;   -- conserva la definición, descarta los datos
ALTER INDEX IX_Producto_Nombre ON Producto REBUILD;   -- habilitar = reconstruir
DROP INDEX IX_Producto_Nombre ON Producto;
```

> **Deshabilitar el índice clustered deja la tabla inaccesible** (Msg 8655) y deshabilita también sus non-clustered y las FK que la referencian. Solo se hace como paso previo a una reconstrucción controlada.

### 4.5 Mantenimiento como tarea programada (vínculo con el Entregable 1)

El mantenimiento de índices y estadísticas es una de las **tareas programadas** típicas de un DBA. Un trabajo de **SQL Server Agent** semanal, en horario de baja carga, puede:

1. consultar `sys.dm_db_index_physical_stats`;
2. ejecutar `REORGANIZE` o `REBUILD` según los umbrales;
3. ejecutar `UPDATE STATISTICS` en las tablas cuyas estadísticas **no** se reconstruyeron.

> SQL Server **Express** no incluye SQL Server Agent. La alternativa es un script `.sql` ejecutado con `sqlcmd` desde el **Programador de tareas de Windows**.

---

## 5. Estadísticas

### 5.1 ¿Qué son?

Son objetos con la **distribución de valores** de una o varias columnas: un **histograma** de hasta 200 pasos y la **densidad**. El optimizador las usa para **estimar cuántas filas** devolverá cada operador y elegir el plan.

- Cada índice tiene sus estadísticas.
- Con `AUTO_CREATE_STATISTICS ON` (el valor por defecto) se crean estadísticas de columna (`_WA_Sys_...`) cuando una consulta las necesita.
- Con `AUTO_UPDATE_STATISTICS ON` se actualizan cuando cambia un porcentaje significativo de filas.

### 5.2 Ver estadísticas

```sql
SELECT s.name AS estadistica, s.auto_created, s.user_created,
       STATS_DATE(s.object_id, s.stats_id) AS ultima_actualizacion
FROM sys.stats s
WHERE s.object_id = OBJECT_ID('ventas.Cat_Invoice');

DBCC SHOW_STATISTICS ('ventas.Cat_Invoice', 'IX_Invoice_Date');
```

### 5.3 Actualizar estadísticas

```sql
UPDATE STATISTICS ventas.Cat_Invoice;                 -- todas las de la tabla (muestreo)
UPDATE STATISTICS ventas.Cat_Invoice WITH FULLSCAN;   -- lectura completa
EXEC sp_updatestats;                                  -- toda la BD (solo las que tienen cambios)
```

> **Síntoma de estadísticas desactualizadas:** en el plan real, las *Estimated Rows* son muy distintas de las *Actual Rows*.

---

## 6. Planes de Ejecución

### 6.1 Cómo obtenerlos

| Herramienta | Qué muestra |
|-------------|-------------|
| SSMS → **Ctrl + L** | Plan **estimado** (no ejecuta la consulta) |
| SSMS → **Ctrl + M** (Include Actual Execution Plan) y luego ejecutar | Plan **real**, con las filas reales |
| `SET STATISTICS XML ON` | Plan real en XML (sin interfaz gráfica) |
| `SET STATISTICS IO ON` | **Lecturas** por tabla. **No** muestra el plan. |
| `SET STATISTICS TIME ON` | Tiempos de **compilación** y **ejecución**. **No** muestra el plan. |

```sql
SET STATISTICS IO, TIME ON;

SELECT invoice_number, branch_id, total
FROM ventas.Cat_Invoice
WHERE invoice_date >= '2026-10-01' AND invoice_date < '2026-11-01';

SET STATISTICS IO, TIME OFF;
/*
Table 'Cat_Invoice'. Scan count 1, logical reads 3, physical reads 0, ...
 SQL Server Execution Times:
   CPU time = 0 ms,  elapsed time = 1 ms.
*/
```

> Para comparar antes y después, lo que hay que mirar son las **lecturas lógicas**: son estables entre ejecuciones. El tiempo varía según la caché y la carga del equipo.

### 6.2 Operadores comunes

| Operador | Significado |
|----------|-------------|
| **Table Scan** | Recorrido completo de un **heap** |
| **Clustered Index Scan** | Recorrido completo de una tabla con clustered (equivale a leer toda la tabla) |
| **Index Scan** | Recorrido completo de un non-clustered |
| **Index Seek / Clustered Index Seek** | Búsqueda dirigida por la clave |
| **Key Lookup / RID Lookup** | Ir a la tabla a buscar columnas que el índice no tiene (una vez por fila) |
| **Nested Loops** | Join eficiente cuando una entrada es pequeña |
| **Hash Match** | Join o agregación sobre entradas grandes sin orden |
| **Merge Join** | Join de dos entradas ya ordenadas por la clave del join |
| **Sort** | Ordenamiento (costoso en memoria; puede desbordar a tempdb) |

### 6.3 Indicadores de rendimiento

| Indicador | Bueno | Señal de alerta |
|-----------|-------|-----------------|
| Estimated vs Actual Rows | Cercanos | Diferencia de órdenes de magnitud (estadísticas) |
| Key Lookups | Pocas filas | Miles de ejecuciones → falta un `INCLUDE` |
| Scan | En tablas pequeñas | En tablas grandes con un filtro selectivo |
| Advertencias (⚠) en un operador | Ninguna | Conversión implícita, desbordamiento a tempdb |
| *Missing Index* (texto verde) | — | Sugerencia que hay que **evaluar**, no aplicar a ciegas |

---

## 7. Monitoreo del Uso de Índices

```sql
-- ¿Qué índices se usan y cuáles solo cuestan escrituras?
SELECT OBJECT_SCHEMA_NAME(i.object_id) + '.' + OBJECT_NAME(i.object_id) AS tabla,
       i.name AS indice,
       us.user_seeks, us.user_scans, us.user_lookups, us.user_updates
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats us
       ON us.object_id = i.object_id AND us.index_id = i.index_id AND us.database_id = DB_ID()
WHERE OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
ORDER BY us.user_updates DESC;

-- Sugerencias del optimizador (evaluarlas; pueden solaparse con índices existentes)
SELECT d.statement AS tabla, d.equality_columns, d.inequality_columns, d.included_columns,
       s.user_seeks, s.avg_user_impact
FROM sys.dm_db_missing_index_details d
INNER JOIN sys.dm_db_missing_index_groups g ON g.index_handle = d.index_handle
INNER JOIN sys.dm_db_missing_index_group_stats s ON s.group_handle = g.index_group_handle
WHERE d.database_id = DB_ID();
```

> Estas DMV **se reinician al reiniciar el servicio**. Un índice con 0 lecturas tras una semana de operación normal es candidato a eliminarse.

---

## 8. Buenas Prácticas

### 8.1 Cuándo crear índices

| Crear índice en | Pensarlo dos veces en |
|-----------------|-----------------------|
| Columnas FK usadas en `JOIN` | Tablas muy pequeñas (unas pocas páginas) |
| Columnas de filtros frecuentes y selectivos (`WHERE`) | Columnas de baja selectividad con distribución **uniforme** |
| Columnas de `ORDER BY` / `GROUP BY` en consultas frecuentes | Columnas que cambian constantemente |
| Columnas mostradas en reportes frecuentes → `INCLUDE` | Tablas de escritura intensiva (cada índice extra encarece cada `INSERT`) |

### 8.2 Reglas de oro

| Regla | Descripción |
|-------|-------------|
| Un solo clustered, bien elegido | Estrecho, único, estático y creciente |
| Indexar las FK | SQL Server no lo hace automáticamente |
| Consultas SARGables | No envolver la columna en funciones; mismos tipos de dato |
| `INCLUDE` para cubrir | Evita Key Lookups en consultas frecuentes |
| No abusar | Cada índice cuesta en `INSERT`/`UPDATE`/`DELETE` y en espacio |
| Medir antes y después | `SET STATISTICS IO` + plan real |
| Mantenimiento según fragmentación | `REORGANIZE` 5–30 %, `REBUILD` > 30 % (orientativo) |
| Estadísticas al día | `REBUILD` las actualiza; tras `REORGANIZE` hay que hacerlo aparte |

### 8.3 Baja selectividad: depende de la distribución

```sql
-- Generalmente inútil: estado con pocos valores repartidos de forma pareja
CREATE INDEX IX_Vehicle_State ON catalogo.Cat_Vehicle(vehicle_state);

-- Útil: el valor buscado es MINORITARIO → índice filtrado
CREATE INDEX IX_Quote_Pending ON ventas.Cat_Quote(quote_date)
WHERE quote_state = 'Pending';
```

---

## 9. Laboratorio: generar volumen para medir

Con 5 filas el optimizador **siempre** elige un *scan* (leer una página es lo más barato), así que para ver el efecto de un índice hacen falta datos. Para no romper las reglas de negocio de `ventas.Cat_Invoice` (FK, `UQ_Invoice_Quote`, trigger `INSTEAD OF`), se usa una **tabla de laboratorio** con la misma forma. Los números se generan con una **CTE recursiva** (Tema 04).

```sql
DROP TABLE IF EXISTS dbo.Lab_Invoice;
CREATE TABLE dbo.Lab_Invoice (
    invoice_id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Lab_Invoice PRIMARY KEY,
    invoice_number VARCHAR(20) NOT NULL,
    client_id INT NOT NULL,
    branch_id INT NOT NULL,
    invoice_date DATETIME NOT NULL,
    total DECIMAL(12,2) NOT NULL,
    invoice_state VARCHAR(20) NOT NULL
);

WITH Numeros AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM Numeros WHERE n < 200000
)
INSERT INTO dbo.Lab_Invoice (invoice_number, client_id, branch_id, invoice_date, total, invoice_state)
SELECT 'LAB-' + RIGHT('000000' + CAST(n AS VARCHAR(6)), 6),
       1 + n % 5000,
       1 + n % 4,
       DATEADD(MINUTE, -n * 5, '2026-10-31'),          -- ~2 años hacia atrás
       15000 + (n % 300) * 100,
       CASE WHEN n % 50 = 0 THEN 'Cancelled' ELSE 'Issued' END
FROM Numeros
OPTION (MAXRECURSION 0);                               -- 200 000 niveles: se desactiva el límite
```

```sql
-- Medición ANTES
SET STATISTICS IO ON;
SELECT invoice_number, branch_id, total
FROM dbo.Lab_Invoice
WHERE invoice_date >= '2026-10-01' AND invoice_date < '2026-11-01';
SET STATISTICS IO OFF;     -- anotar las lecturas lógicas (scan del clustered)

-- Índice de cobertura para la consulta
CREATE NONCLUSTERED INDEX IX_Lab_Invoice_Date
ON dbo.Lab_Invoice(invoice_date)
INCLUDE (branch_id, total, invoice_number);

-- Medición DESPUÉS: el plan debe mostrar Index Seek y muchas menos lecturas
SET STATISTICS IO ON;
SELECT invoice_number, branch_id, total
FROM dbo.Lab_Invoice
WHERE invoice_date >= '2026-10-01' AND invoice_date < '2026-11-01';

-- Contraste: la misma consulta NO SARGable vuelve a recorrer todo el índice
SELECT invoice_number, branch_id, total
FROM dbo.Lab_Invoice
WHERE YEAR(invoice_date) = 2026 AND MONTH(invoice_date) = 10;
SET STATISTICS IO OFF;
```

Registro sugerido para la **T6 de la Asignación 06**:

| Consulta | Índice | Operador del plan | Lecturas lógicas | CPU (ms) |
|----------|--------|-------------------|------------------|----------|
| Facturas del mes (rango) | Ninguno | Clustered Index Scan | … | … |
| Facturas del mes (rango) | `IX_Lab_Invoice_Date` | Index Seek | … | … |
| Facturas del mes (`YEAR`/`MONTH`) | `IX_Lab_Invoice_Date` | Index Scan | … | … |

> **Referencia medida** (SQL Server 2025 Express LocalDB, 200 000 filas, ~8 600 del mes): sin índice, **1 500** lecturas lógicas; con `IX_Lab_Invoice_Date` y rango, **52**; con `YEAR`/`MONTH` sobre el mismo índice, **1 123**. El índice solo ayuda si la consulta es SARGable.

---

## 10. Ejercicios Prácticos

### Ejercicio 1: Analizar rendimiento

1. Cargar la tabla de laboratorio (sección 9).
2. Ejecutar la consulta sin índice y registrar las lecturas lógicas.
3. Crear el índice apropiado.
4. Ejecutar la misma consulta y comparar. Repetir con la versión no SARGable.

### Ejercicio 2: Diseñar índices para ConcessionaireDB

1. Listar las FK sin índice (sección 2.3) y crear los índices que justifiques.
2. Crear un índice de cobertura para "clientes por apellido" que incluya nombre y correo.
3. Crear un índice filtrado para vehículos `Available` por modelo.

### Ejercicio 3: Mantenimiento

1. Medir la fragmentación con `sys.dm_db_index_physical_stats`.
2. Decidir entre `REORGANIZE` y `REBUILD` para cada índice y justificar.
3. Escribir el script que ejecutaría la tarea programada semanal.

---

## 11. Preguntas de Autoevaluación

1. ¿Cuál es la diferencia entre clustered y non-clustered? ¿Qué es un *heap*?
2. ¿Cuántos clustered puede tener una tabla? ¿Toda tabla tiene uno?
3. ¿Qué contiene el localizador de un non-clustered en un heap y en una tabla con clustered?
4. ¿Qué es un covering index y qué operador del plan elimina?
5. ¿Por qué se deben indexar manualmente las FK en SQL Server?
6. ¿Por qué `WHERE YEAR(fecha) = 2026` no aprovecha un índice sobre `fecha`?
7. ¿Por qué importa el orden de las columnas en un índice compuesto?
8. ¿Cuándo usar `REORGANIZE` y cuándo `REBUILD`? ¿Cuál actualiza las estadísticas?
9. ¿Qué indica una gran diferencia entre las filas estimadas y las reales?
10. ¿Por qué un índice filtrado puede no usarse en una consulta parametrizada?

---

## 12. Recursos Adicionales

- [CREATE INDEX (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-index-transact-sql)
- [SQL Server index architecture and design guide](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-index-design-guide)
- [Optimize index maintenance](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/reorganize-and-rebuild-indexes)
- [Statistics](https://learn.microsoft.com/en-us/sql/relational-databases/statistics/statistics)
- [Execution plans](https://learn.microsoft.com/en-us/sql/relational-databases/performance/execution-plans)
