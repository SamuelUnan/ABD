# 04. Common Table Expressions (CTE)

## 1. ¿Qué es una CTE?

Una **Common Table Expression (CTE)** es un **conjunto de resultados temporal y con nombre** que se define con la palabra clave `WITH` y que existe **solo durante la ejecución de la sentencia inmediatamente siguiente** (`SELECT`, `INSERT`, `UPDATE`, `DELETE` o `MERGE`).

> **Alcance vs. número de referencias.** Una CTE *vive* una sola sentencia, pero **dentro de esa sentencia se puede referenciar varias veces** (por ejemplo, en un `JOIN` consigo misma). Cada referencia se **vuelve a evaluar**: SQL Server no "guarda" el resultado de la CTE como lo haría una tabla temporal.

### 1.1 Ventajas

| Ventaja | Descripción |
|---------|-------------|
| **Legibilidad** | Divide consultas complejas en pasos lógicos con nombre |
| **Reutilización dentro de la sentencia** | Se puede referenciar múltiples veces en la misma consulta |
| **Recursión** | Permite recorrer datos jerárquicos (árboles, organigramas) |
| **Mantenimiento** | Más fácil de leer y modificar que subconsultas anidadas |

### 1.2 Lo que una CTE **no** es

- **No** es una tabla temporal: no almacena datos ni tiene estadísticas propias.
- **No** mejora el rendimiento por sí misma: el optimizador la "expande" como si fuera una subconsulta.
- **No** persiste: al terminar la sentencia deja de existir (a diferencia de una vista).

---

## 2. Sintaxis Básica

```sql
WITH nombre_cte (columna1, columna2) AS (   -- lista de columnas opcional
    -- Consulta que define la CTE
    SELECT columna1, columna2
    FROM tabla
    WHERE condicion
)
-- Consulta principal que usa la CTE (debe ir INMEDIATAMENTE después)
SELECT *
FROM nombre_cte;
```

### 2.1 El punto y coma antes de `WITH`

`WITH` también se usa en otras cláusulas de T-SQL (`WITH (NOLOCK)`, `WITH CHECK OPTION`…). Por eso, **si la CTE no es la primera sentencia del lote, la sentencia anterior debe terminar en `;`**:

```sql
DECLARE @anio INT = 2026      -- ❌ sin ';' → Msg 319: Incorrect syntax near the keyword 'with'
WITH Ventas AS (SELECT 1 AS x)
SELECT * FROM Ventas;

DECLARE @anio INT = 2026;     -- ✅ terminar la sentencia previa
WITH Ventas AS (SELECT 1 AS x)
SELECT * FROM Ventas;
```

> Buena práctica: terminar **todas** las sentencias con `;` (obligatorio también antes de `THROW` y `MERGE`). Escribir `;WITH` es un parche, no un estilo.

---

## 3. CTE No Recursiva

### 3.1 Ejemplo Simple

```sql
-- Empleados con salario mayor al promedio
WITH EmpleadosAltoSalario AS (
    SELECT employee_name, employee_position, employee_salary
    FROM personas.Cat_Employee
    WHERE employee_salary > (SELECT AVG(employee_salary) FROM personas.Cat_Employee)
)
SELECT * FROM EmpleadosAltoSalario;
```

### 3.2 Múltiples CTEs encadenadas

Se separan por comas; cada CTE puede usar las definidas **antes** que ella.

```sql
WITH
VentasPorCliente AS (
    SELECT client_id, SUM(total) AS total_ventas
    FROM ventas.Cat_Invoice
    GROUP BY client_id
),
TopClientes AS (
    SELECT client_id,
           total_ventas,
           ROW_NUMBER() OVER (ORDER BY total_ventas DESC) AS ranking   -- Tema 07
    FROM VentasPorCliente
)
SELECT c.client_name, c.client_lastname, tc.total_ventas, tc.ranking
FROM TopClientes tc
INNER JOIN personas.Cat_Client c ON tc.client_id = c.client_id
WHERE tc.ranking <= 10;
```

> `ROW_NUMBER() OVER (...)` es una **función de ventana**; se estudia a fondo en el Tema 07. Aquí solo se usa para numerar.

### 3.3 CTE para Actualización y Eliminación

Una CTE es **actualizable** cuando el `UPDATE`/`DELETE` afecta a **una sola tabla base** y la CTE no usa `DISTINCT`, `GROUP BY`, agregados ni `UNION`. La modificación se aplica sobre la tabla subyacente.

```sql
-- Aumentar 10% el precio de repuestos con stock bajo
WITH RepuestosStockBajo AS (
    SELECT spare_part_id, spare_part_price
    FROM inventario.Cat_SparePart
    WHERE spare_part_stock < 10
)
UPDATE RepuestosStockBajo
SET spare_part_price = spare_part_price * 1.10;

-- Eliminar duplicados conservando el registro más antiguo
WITH Duplicados AS (
    SELECT client_id,
           ROW_NUMBER() OVER (PARTITION BY client_cedula ORDER BY client_id) AS rn
    FROM personas.Cat_Client
)
DELETE FROM Duplicados WHERE rn > 1;
```

> En ConcessionaireDB la restricción `UQ_Client_Cedula` **impide** que existan duplicados de cédula. El segundo ejemplo es la técnica para **limpiar datos heredados antes** de poder crear esa restricción: buena práctica de normalización (una cédula ⇒ un cliente).

---

## 4. CTE Recursiva

### 4.1 ¿Qué es?

Una CTE recursiva **se referencia a sí misma** para recorrer datos jerárquicos almacenados como **lista de adyacencia** (cada fila guarda el id de su padre, como `boss_id` en `Cat_Employee`).

### 4.2 Sintaxis

```sql
WITH nombre_cte AS (
    -- 1) Miembro ancla (anchor): se ejecuta UNA vez
    SELECT columnas
    FROM tabla
    WHERE condicion_inicial

    UNION ALL

    -- 2) Miembro recursivo: se une con la propia CTE
    SELECT columnas
    FROM tabla
    INNER JOIN nombre_cte ON tabla.padre = nombre_cte.id
)
SELECT * FROM nombre_cte
OPTION (MAXRECURSION 100);   -- Límite de niveles (por defecto 100)
```

### 4.3 ¿Cómo se ejecuta? (paso a paso)

1. Se ejecuta el **ancla** → resultado **R0** (por ejemplo, el director).
2. Se ejecuta el **miembro recursivo** usando **solo R0** como "la CTE" → **R1** (sus subordinados directos).
3. Se repite usando **solo R1** → **R2**, y así sucesivamente.
4. Se detiene cuando una iteración devuelve **0 filas**.
5. El resultado final es `R0 UNION ALL R1 UNION ALL R2 ...`.

| Iteración | Entrada (filas de la CTE) | Filas nuevas | Nivel |
|-----------|---------------------------|--------------|-------|
| Ancla | — | Director | 0 |
| 1 | Director | Gerente Ventas, Gerente Taller | 1 |
| 2 | Gerentes | Asesor 1, Asesor 2, Técnico 1 | 2 |
| 3 | Asesores/Técnicos | *(ninguna)* → fin | — |

### 4.4 Reglas del miembro recursivo

| Regla | Consecuencia si se incumple |
|-------|-----------------------------|
| Ancla y recursivo unidos con `UNION ALL` (no `UNION`) | Error de compilación |
| Mismo número de columnas y **mismos tipos exactos** (incluida longitud) | **Msg 240**: *Types don't match between the anchor and the recursive part* |
| El recursivo no puede usar `GROUP BY`, `TOP`, `DISTINCT`, agregados ni `OUTER JOIN` hacia la CTE | Error de compilación |
| La CTE se referencia una sola vez en el `FROM` del recursivo | Error de compilación |

> **¿Por qué tanto `CAST`?** `0 AS nivel` es `INT`, pero `nivel + 1` también: no hay problema. En cambio, `employee_name` es `VARCHAR(50)` y `ruta + ' > ' + employee_name` produce un `VARCHAR` de otra longitud → Msg 240. Por eso el ancla y el recursivo convierten la ruta al **mismo tipo**: `CAST(... AS VARCHAR(500))` o `VARCHAR(MAX)`.

### 4.5 Ejemplo: Organigrama de ConcessionaireDB

`personas.Cat_Employee` ya tiene la autorrelación `boss_id → employee_id` (`FK_Employee_Boss`).

> La Asignación 04 nombra las columnas en español (`id_jefe`, `cargo`, `nombre`). En el script del curso son `boss_id`, `employee_position` y `employee_name`.

```sql
-- Datos de prueba (T1 de la Asignación 04)
INSERT INTO personas.Cat_Employee (branch_id, boss_id, employee_name, employee_position, employee_salary)
VALUES (1, NULL, 'Ana Ruiz', 'Director', 5000.00);
DECLARE @dir INT = SCOPE_IDENTITY();

INSERT INTO personas.Cat_Employee (branch_id, boss_id, employee_name, employee_position, employee_salary)
VALUES (1, @dir, 'Luis Mena', 'Gerente Ventas', 3000.00);
DECLARE @gv INT = SCOPE_IDENTITY();

INSERT INTO personas.Cat_Employee (branch_id, boss_id, employee_name, employee_position, employee_salary)
VALUES (1, @dir, 'Carla Soto', 'Gerente Taller', 3000.00),
       (1, @gv,  'Pedro Gil',  'Asesor',         1500.00),
       (1, @gv,  'Rosa Pena',  'Asesor',         1500.00);
```

```sql
-- CTE recursiva: nivel y ruta completa
WITH Jerarquia AS (
    -- Ancla: empleados sin jefe (raíz)
    SELECT employee_id, employee_name, employee_position, boss_id,
           0 AS nivel,
           CAST(employee_name AS VARCHAR(500)) AS ruta
    FROM personas.Cat_Employee
    WHERE boss_id IS NULL

    UNION ALL

    -- Recursivo: subordinados de las filas de la iteración anterior
    SELECT e.employee_id, e.employee_name, e.employee_position, e.boss_id,
           j.nivel + 1,
           CAST(j.ruta + ' > ' + e.employee_name AS VARCHAR(500))   -- ' > ' en VARCHAR: un '→' requeriría NVARCHAR y N'→'
    FROM personas.Cat_Employee e
    INNER JOIN Jerarquia j ON e.boss_id = j.employee_id
)
SELECT employee_id, employee_name, employee_position, boss_id, nivel, ruta
FROM Jerarquia
ORDER BY ruta
OPTION (MAXRECURSION 10);
```

**Resultado esperado (parcial):**

| employee_name | employee_position | nivel | ruta |
|---------------|-------------------|-------|------|
| Ana Ruiz | Director | 0 | Ana Ruiz |
| Carla Soto | Gerente Taller | 1 | Ana Ruiz > Carla Soto |
| Luis Mena | Gerente Ventas | 1 | Ana Ruiz > Luis Mena |
| Pedro Gil | Asesor | 2 | Ana Ruiz > Luis Mena > Pedro Gil |

> Los empleados creados en temas anteriores con `boss_id = NULL` también aparecen como raíces (nivel 0). Es un hallazgo de **calidad de datos**: un organigrama bien definido tiene una única raíz.

```sql
-- Subordinados directos por jefe (T3)
WITH Jerarquia AS (
    SELECT employee_id, boss_id, 0 AS nivel
    FROM personas.Cat_Employee
    WHERE boss_id IS NULL
    UNION ALL
    SELECT e.employee_id, e.boss_id, j.nivel + 1
    FROM personas.Cat_Employee e
    INNER JOIN Jerarquia j ON e.boss_id = j.employee_id
)
SELECT jefe.employee_name AS jefe, COUNT(*) AS subordinados_directos
FROM Jerarquia h
INNER JOIN personas.Cat_Employee jefe ON jefe.employee_id = h.boss_id
GROUP BY jefe.employee_name;      -- el GROUP BY va FUERA de la CTE recursiva
```

### 4.6 Ejemplo: Categorías anidadas (genérico)

```sql
-- Tabla de categorías con autorrelación
CREATE TABLE Categoria (
    id_categoria INT PRIMARY KEY,
    nombre VARCHAR(50),
    id_padre INT NULL,
    FOREIGN KEY (id_padre) REFERENCES Categoria(id_categoria)
);

WITH RutaCategoria AS (
    SELECT id_categoria, nombre, id_padre,
           CAST(nombre AS VARCHAR(200)) AS ruta_completa
    FROM Categoria
    WHERE id_padre IS NULL

    UNION ALL

    SELECT c.id_categoria, c.nombre, c.id_padre,
           CAST(rc.ruta_completa + ' > ' + c.nombre AS VARCHAR(200))
    FROM Categoria c
    INNER JOIN RutaCategoria rc ON c.id_padre = rc.id_categoria
)
SELECT * FROM RutaCategoria;
```

### 4.7 Ejemplo: Indentación y orden jerárquico

```sql
WITH Arbol AS (
    SELECT employee_id, employee_name, boss_id, 0 AS nivel,
           CAST(RIGHT('0000' + CAST(employee_id AS VARCHAR(10)), 4) AS VARCHAR(MAX)) AS orden
    FROM personas.Cat_Employee
    WHERE boss_id IS NULL

    UNION ALL

    SELECT e.employee_id, e.employee_name, e.boss_id, a.nivel + 1,
           CAST(a.orden + '.' + RIGHT('0000' + CAST(e.employee_id AS VARCHAR(10)), 4) AS VARCHAR(MAX))
    FROM personas.Cat_Employee e
    INNER JOIN Arbol a ON e.boss_id = a.employee_id
)
SELECT REPLICATE('    ', nivel) + employee_name AS estructura,   -- REPLICATE (T-SQL no tiene REPEAT)
       nivel, orden
FROM Arbol
ORDER BY orden;
```

### 4.8 `MAXRECURSION`, ciclos y error 530

- Por defecto, SQL Server permite **100 niveles** de recursión.
- `OPTION (MAXRECURSION n)` acepta de `0` a `32767`; `0` = **sin límite** (solo si la jerarquía está garantizada sin ciclos).
- Al superar el límite, la sentencia **se aborta** con **Msg 530**: *The maximum recursion n has been exhausted before statement completion*.

**Ciclos.** Si los datos forman un ciclo (A es jefe de B y B es jefe de A), la recursión nunca termina y **siempre** se alcanza el límite. Comprobación (T6 de la Asignación 04):

```sql
-- Provocar un ciclo en una transacción y revertirlo
BEGIN TRANSACTION;
    UPDATE personas.Cat_Employee SET boss_id = (SELECT MAX(employee_id) FROM personas.Cat_Employee)
    WHERE boss_id IS NULL AND employee_name = 'Ana Ruiz';   -- la raíz pasa a depender de un subordinado

    WITH Jerarquia AS (
        SELECT employee_id, boss_id, 0 AS nivel FROM personas.Cat_Employee WHERE employee_name = 'Ana Ruiz'
        UNION ALL
        SELECT e.employee_id, e.boss_id, j.nivel + 1
        FROM personas.Cat_Employee e INNER JOIN Jerarquia j ON e.boss_id = j.employee_id
    )
    SELECT * FROM Jerarquia OPTION (MAXRECURSION 5);   -- Msg 530
ROLLBACK TRANSACTION;
```

Defensa ante ciclos: guardar la ruta de ids y cortar si el id ya aparece:

```sql
... WHERE CHARINDEX('/' + CAST(e.employee_id AS VARCHAR(10)) + '/', j.ruta_ids) = 0
```

---

## 5. CTE vs Subconsulta vs Vista vs Tabla temporal

| Característica | CTE | Subconsulta | Vista | Tabla temporal `#t` |
|----------------|-----|-------------|-------|---------------------|
| Alcance | Una sentencia | Su ubicación | Permanente (objeto de BD) | Sesión / procedimiento |
| Referencias múltiples | Sí, **reevaluada** cada vez | No (se repite el código) | Sí | Sí, **materializada** |
| Recursión | **Sí** | No | No (puede contener una CTE) | No |
| Almacena datos | No | No | No (solo la definición) | **Sí** |
| Estadísticas / índices | No | No | Solo **vista indexada** (`WITH SCHEMABINDING` + índice clustered único) | Sí |
| Permisos propios | No | No | **Sí** (GRANT sobre la vista) | No |
| Uso típico | Legibilidad, jerarquías | Filtros simples | Reutilizar lógica / seguridad | Resultados intermedios grandes reutilizados |

> **Regla práctica:** si el resultado intermedio se usa **varias veces y es costoso**, materializarlo en una tabla temporal suele ser más rápido que una CTE referenciada varias veces.

---

## 6. Buenas Prácticas

### 6.1 Cuándo usar CTE

| Usar CTE | Evitar CTE |
|----------|------------|
| Consultas jerárquicas (recursión) | Cuando la lógica se reutiliza en muchas consultas → **vista** |
| Consultas de varios pasos que ganan legibilidad | Resultados intermedios costosos usados varias veces → **tabla temporal** |
| `UPDATE`/`DELETE` sobre un subconjunto calculado (ej. duplicados) | Consultas triviales de un solo paso |

### 6.2 Errores comunes

| Error | Síntoma | Corrección |
|-------|---------|------------|
| Falta `;` antes de `WITH` | Msg 319 | Terminar la sentencia anterior con `;` |
| Tipos distintos entre ancla y recursivo | Msg 240 | `CAST` al mismo tipo y longitud |
| Ciclo en los datos | Msg 530 | Validar datos; cortar con ruta de ids |
| Usar la CTE en una segunda sentencia | Msg 208 (*Invalid object name*) | La CTE solo existe para la sentencia siguiente |
| Suponer que la CTE "cachea" el resultado | Lentitud inesperada | Usar tabla temporal si se reutiliza mucho |

### 6.3 Vínculo con normalización

La recursión existe porque el modelo **normalizado** guarda la jerarquía una sola vez (`boss_id`), sin repetir "nombre del jefe" ni "nivel" en cada fila (eso violaría la 3FN: `nivel` dependería de `boss_id`, no de la PK). La CTE **deriva** esos datos al consultar, en lugar de almacenarlos de forma redundante.

---

## 7. Ejercicios Prácticos

### Ejercicio 1: Jerarquía de Empleados (`personas.Cat_Employee`)

1. Obtener la jerarquía completa con nivel.
2. Obtener la ruta de cada empleado.
3. Contar subordinados directos por cada jefe.

### Ejercicio 2: Datos Jerárquicos de Categorías

Con la tabla `Categoria (id_categoria, nombre, id_padre)` del punto 4.6:

1. Obtener todas las subcategorías de una categoría padre.
2. Obtener la profundidad máxima del árbol.
3. Obtener las hojas (categorías sin hijas).

### Ejercicio 3: Reportes con varias CTEs (ConcessionaireDB)

1. Total facturado por modelo y marca (factura → vehículo → modelo → marca).
2. Ingresos por mes y sucursal comparados con el promedio mensual de la sucursal.
3. Clientes que no han comprado en los últimos 3 meses.

---

## 8. Preguntas de Autoevaluación

1. ¿Qué es una CTE y cuál es su alcance?
2. ¿Cuál es la diferencia entre una CTE no recursiva y una recursiva?
3. ¿Qué es el miembro ancla y qué es el miembro recursivo?
4. Describe, iteración por iteración, cómo se ejecuta una CTE recursiva.
5. ¿Cómo se controla el número máximo de recursiones y qué ocurre al superarlo?
6. ¿Por qué se produce el error 240 y cómo se corrige?
7. ¿Cuándo conviene una CTE, una vista o una tabla temporal?
8. ¿Qué condiciones debe cumplir una CTE para ser actualizable?
9. ¿Por qué hace falta `;` antes de `WITH`?
10. ¿Por qué almacenar el "nivel" de cada empleado en la tabla violaría la 3FN?

---

## 9. Recursos Adicionales

- [WITH common_table_expression (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/with-common-table-expression-transact-sql)
- [Hierarchical data (SQL Server)](https://learn.microsoft.com/en-us/sql/relational-databases/hierarchical-data-sql-server)
- [Query hints: MAXRECURSION](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-query)
