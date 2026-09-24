# 02. Triggers DML

## 1. Conceptos Fundamentales

### 1.1 ¿Qué es un Trigger?

Un **trigger** es código T-SQL que se ejecuta **automáticamente** cuando ocurre un evento DML (INSERT, UPDATE, DELETE) en una tabla.

**Características:**
- Se ejecuta **después** o **en lugar de** la operación
- No acepta parámetros explícitos
- Usa tablas virtuales `INSERTED` y `DELETED`
- Se ejecuta **una vez por sentencia** (no por fila)

### 1.2 ¿Cuándo Usar Triggers?

| Usar para | NO usar para |
|-----------|--------------|
| Auditoría (bitácoras) | Validaciones simples (usar CHECK) |
| Integridad compleja | Relaciones entre tablas (usar FK) |
| Cascada personalizada | Lógica de negocio (usar SP) |
| Sincronización de resúmenes | Operaciones frecuentes (afecta rendimiento) |

---

## 2. Tablas Virtuales: INSERTED y DELETED

| Tabla | INSERT | UPDATE | DELETE |
|-------|--------|--------|--------|
| `INSERTED` | Filas nuevas | Valores nuevos | Vacía |
| `DELETED` | Vacía | Valores anteriores | Filas eliminadas |

**Ejemplo UPDATE:**
```sql
-- Producto: id=1, precio=100
UPDATE Producto SET precio = 150 WHERE id = 1;

-- INSERTED: (id=1, precio=150)  ← nuevo
-- DELETED:  (id=1, precio=100)  ← anterior
```

**Comparar valores:**
```sql
SELECT 
    d.precio AS precio_anterior,
    i.precio AS precio_nuevo,
    i.precio - d.precio AS diferencia
FROM DELETED d
JOIN INSERTED i ON d.id_producto = i.id_producto;
```

---

## 3. Triggers AFTER

### 3.1 Sintaxis

```sql
CREATE TRIGGER tr_nombre
ON tabla
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    -- Lógica
END;
```

### 3.2 Auditoría INSERT

```sql
CREATE TABLE AuditoriaProducto (
    id_auditoria INT IDENTITY(1,1) PRIMARY KEY,
    id_producto INT,
    accion VARCHAR(10),
    usuario VARCHAR(50) DEFAULT SYSTEM_USER,
    fecha DATETIME DEFAULT GETDATE(),
    valores_nuevos VARCHAR(MAX)
);

CREATE TRIGGER tr_Producto_Audit_Insert
ON Producto
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO AuditoriaProducto (id_producto, accion, valores_nuevos)
    SELECT id_producto, 'INSERT', 'Nombre: ' + nombre + ', Precio: ' + CAST(precio AS VARCHAR)
    FROM INSERTED;
END;
```

### 3.3 Auditoría UPDATE

```sql
CREATE TRIGGER tr_Producto_Audit_Update
ON Producto
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO AuditoriaProducto (id_producto, accion, valores_nuevos)
    SELECT 
        i.id_producto,
        'UPDATE',
        'Antes: $' + CAST(d.precio AS VARCHAR) + ' → Después: $' + CAST(i.precio AS VARCHAR)
    FROM DELETED d
    JOIN INSERTED i ON d.id_producto = i.id_producto
    WHERE d.precio <> i.precio;
END;
```

### 3.4 Auditoría DELETE

```sql
CREATE TRIGGER tr_Producto_Audit_Delete
ON Producto
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO AuditoriaProducto (id_producto, accion, valores_nuevos)
    SELECT id_producto, 'DELETE', 'Eliminado: ' + nombre
    FROM DELETED;
END;
```

### 3.5 Trigger Combinado (INSERT, UPDATE, DELETE)

```sql
CREATE TRIGGER tr_Producto_Audit_All
ON Producto
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (SELECT * FROM INSERTED) AND NOT EXISTS (SELECT * FROM DELETED)
    BEGIN
        -- INSERT
        INSERT INTO AuditoriaProducto (id_producto, accion, valores_nuevos)
        SELECT id_producto, 'INSERT', nombre FROM INSERTED;
    END
    ELSE IF EXISTS (SELECT * FROM INSERTED) AND EXISTS (SELECT * FROM DELETED)
    BEGIN
        -- UPDATE
        INSERT INTO AuditoriaProducto (id_producto, accion, valores_nuevos)
        SELECT i.id_producto, 'UPDATE', CAST(d.precio AS VARCHAR) + ' → ' + CAST(i.precio AS VARCHAR)
        FROM DELETED d JOIN INSERTED i ON d.id_producto = i.id_producto;
    END
    ELSE
    BEGIN
        -- DELETE
        INSERT INTO AuditoriaProducto (id_producto, accion, valores_nuevos)
        SELECT id_producto, 'DELETE', nombre FROM DELETED;
    END
END;
```

---

## 4. Triggers INSTEAD OF

### 4.1 ¿Cuándo Usar?

- Para **interceptar** y modificar el comportamiento
- Para **validar** datos antes de permitir la operación
- Para **redirigir** la operación a otra tabla

### 4.2 Validación Compleja

```sql
CREATE TRIGGER tr_Producto_Validar_Precio
ON Producto
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (SELECT * FROM INSERTED WHERE precio <= 0)
    BEGIN
        RAISERROR('El precio debe ser mayor que cero', 16, 1);
        RETURN;
    END
    
    IF EXISTS (SELECT * FROM INSERTED WHERE LEN(TRIM(nombre)) = 0)
    BEGIN
        RAISERROR('El nombre no puede estar vacío', 16, 1);
        RETURN;
    END
    
    INSERT INTO Producto (nombre, precio, stock)
    SELECT nombre, precio, stock FROM INSERTED;
END;
```

### 4.3 Redirigir DELETE a Histórico

```sql
CREATE TABLE ProductoHistorico (
    id_historico INT IDENTITY(1,1) PRIMARY KEY,
    id_producto INT,
    nombre VARCHAR(100),
    precio DECIMAL(10,2),
    fecha_eliminacion DATETIME DEFAULT GETDATE()
);

CREATE TRIGGER tr_Producto_Delete_Historico
ON Producto
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO ProductoHistorico (id_producto, nombre, precio)
    SELECT id_producto, nombre, precio FROM DELETED;
    
    DELETE FROM Producto WHERE id_producto IN (SELECT id_producto FROM DELETED);
END;
```

---

## 5. Gestión de Triggers

### 5.1 Ver Triggers

```sql
-- Todos los triggers de la BD
SELECT t.name AS trigger_name, o.name AS tabla
FROM sys.triggers t
INNER JOIN sys.objects o ON t.parent_id = o.object_id;

-- Ver definición
EXEC sp_helptext 'tr_Producto_Audit_Insert';
```

### 5.2 Habilitar/Deshabilitar

```sql
DISABLE TRIGGER tr_Producto_Audit_Insert ON Producto;
ENABLE TRIGGER tr_Producto_Audit_Insert ON Producto;

DISABLE TRIGGER ALL ON Producto;
ENABLE TRIGGER ALL ON Producto;
```

### 5.3 Eliminar/Modificar

```sql
DROP TRIGGER IF EXISTS tr_Producto_Audit_Insert;

ALTER TRIGGER tr_Producto_Audit_Insert
ON Producto
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    -- Nueva lógica
END;
```

---

## 6. Buenas Prácticas

| Regla | Por qué |
|-------|---------|
| `SET NOCOUNT ON` | Mejora rendimiento |
| Un trigger = una responsabilidad | Mantener código simple |
| Documentar el propósito | Facilita mantenimiento |
| Evitar lógica compleja | Usar procedimientos almacenados |
| No usar para validaciones simples | Usar CHECK o FK |
| Prevenir recursión | Deshabilitar triggers anidados |

**Evitar recursión:**
```sql
CREATE TRIGGER tr_SinRecursion
ON Producto
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    DISABLE TRIGGER ALL ON Producto;
    
    UPDATE Producto SET fecha_modificacion = GETDATE()
    WHERE id_producto IN (SELECT id_producto FROM INSERTED);
    
    ENABLE TRIGGER ALL ON Producto;
END;
```

**Nomenclatura:**
- `tr_Tabla_Audit_Insert`
- `tr_Tabla_Validar_Condicion`
- `tr_Tabla_Sync_Objetivo`

---

## 7. Ejercicios Prácticos

### Ejercicio 1: Auditoría Completa

Crear auditoría para tabla `Empleado`:
1. Trigger INSERT para nuevas contrataciones
2. Trigger UPDATE para cambios de salario
3. Trigger DELETE para bajas

### Ejercicio 2: Validación con INSTEAD OF

Crear trigger en `Pedido` que:
1. Valide cliente activo
2. Valide fecha no futura
3. Inserte si todo está correcto

---

## 8. Preguntas de Autoevaluación

1. ¿Cuál es la diferencia entre AFTER e INSTEAD OF?
2. ¿Qué contienen INSERTED y DELETED en cada operación?
3. ¿Cómo se evita un trigger recursivo?
4. ¿Cuándo usarías INSTEAD OF en lugar de AFTER?
5. ¿Por qué SET NOCOUNT ON es importante?

---

## 9. Recursos Adicionales

- [DML Triggers - Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/triggers/dml-triggers)
- [Create Trigger - Microsoft Learn](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-trigger-transact-sql)
