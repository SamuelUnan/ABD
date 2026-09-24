# 01. Transacciones y Manejo de Errores

## 1. Conceptos Fundamentales

### 1.1 ¿Qué es una Transacción?

Una **transacción** es una secuencia de operaciones que se ejecutan como una **unidad indivisible**. O **todas** las operaciones tienen éxito, o **ninguna** se aplica.

**Ejemplo cotidiano:** Transferencia bancaria
- Paso 1: Descontar $100 de Cuenta A
- Paso 2: Acreditar $100 en Cuenta B

Si falla el Paso 2 después de completar el Paso 1, se perderían $100. La transacción garantiza que **ambos pasos** ocurran o **ninguno**.

### 1.2 Propiedades ACID

| Propiedad | Significado | Ejemplo |
|-----------|-------------|---------|
| **A**tómica | Todo o nada: todas las operaciones se completan o ninguna | Si falla la inserción de un detalle, se deshace el pedido completo |
| **C**onsistente | La base de datos pasa de un estado válido a otro válido | Las FK siempre apuntan a registros existentes |
| **A**islada | Las transacciones concurrentes no se interfieren | Dos usuarios no pueden modificar la misma fila al mismo tiempo |
| **D**urable | Los cambios confirmados sobreviven fallos del sistema | Después de COMMIT, los datos persisten aunque el servidor falle |

### 1.3 ¿Cuándo Usar Transacciones?

**SIEMPRE** cuando una operación involucre múltiples pasos que deban ser atómicos:

- Transferencias bancarias
- Pedidos con múltiples detalles
- Actualización de inventario + venta
- Migraciones de datos
- Cualquier operación que modifique datos en múltiples tablas

**NO es necesario** para:
- Consultas SELECT
- Operaciones INSERT/UPDATE/DELETE simples sobre una tabla
- Vistas de solo lectura

---

## 2. Sentencias de Transacción

### 2.1 BEGIN TRANSACTION

Marca el inicio de una transacción.

```sql
BEGIN TRANSACTION;
-- Opcional: nombre de la transacción para debugging
BEGIN TRANSACTION tx_Transferencia;
```

### 2.2 COMMIT TRANSACTION

Confirma todos los cambios realizados desde el BEGIN.

```sql
BEGIN TRANSACTION;
    UPDATE Cuenta SET saldo = saldo - 100 WHERE id_cuenta = 1;
    UPDATE Cuenta SET saldo = saldo + 100 WHERE id_cuenta = 2;
COMMIT TRANSACTION;
-- Los cambios ahora son permanentes
```

### 2.3 ROLLBACK TRANSACTION

Deshace todos los cambios realizados desde el BEGIN.

```sql
BEGIN TRANSACTION;
    UPDATE Cuenta SET saldo = saldo - 100 WHERE id_cuenta = 1;
    UPDATE Cuenta SET saldo = saldo + 100 WHERE id_cuenta = 2;
ROLLBACK TRANSACTION;
-- Los cambios se deshiceron; la base está como antes del BEGIN
```

### 2.4 SAVE TRANSACTION

Crea un **punto de control** parcial dentro de la transacción. Permite deshacer hasta un punto específico sin abortar toda la transacción.

```sql
BEGIN TRANSACTION;
    INSERT INTO Pedido (id_cliente, fecha) VALUES (1, GETDATE());
    SAVE TRANSACTION sp_PedidoCreado;
    
    INSERT INTO DetallePedido (id_pedido, id_producto, cantidad)
    VALUES (SCOPE_IDENTITY(), 10, 5);
    -- Si falla aquí, podemos volver al punto sp_PedidoCreado
ROLLBACK TRANSACTION sp_PedidoCreado;
-- El pedido existe, pero el detalle no
COMMIT TRANSACTION;
```

---

## 3. Manejo de Errores con TRY...CATCH

### 3.1 Sintaxis Básica

```sql
BEGIN TRY
    -- Código que podría fallar
    BEGIN TRANSACTION;
        INSERT INTO Paciente (nombre) VALUES ('Test');
        UPDATE Cita SET id_paciente = 999 WHERE id_cita = 1;  -- FK inexistente
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    -- Código que se ejecuta si hay error
    ROLLBACK TRANSACTION;
    PRINT 'Error: ' + ERROR_MESSAGE();
END CATCH;
```

### 3.2 Funciones de Error

| Función | Retorna | Descripción |
|---------|---------|-------------|
| `ERROR_NUMBER()` | INT | Número del error |
| `ERROR_MESSAGE()` | NVARCHAR(4000) | Mensaje del error |
| `ERROR_SEVERITY()` | INT | Severidad del error |
| `ERROR_STATE()` | INT | Estado del error |
| `ERROR_LINE()` | INT | Línea donde ocurrió el error |
| `ERROR_PROCEDURE()` | NVARCHAR(128) | Nombre del procedimiento (NULL si no está en uno) |

### 3.3 Ejemplo Completo con Logging

```sql
-- Tabla de log de errores
CREATE TABLE LogErrores (
    id_error INT IDENTITY(1,1) PRIMARY KEY,
    fecha DATETIME DEFAULT GETDATE(),
    numero_error INT,
    mensaje NVARCHAR(4000),
    severidad INT,
    estado INT,
    linea INT,
    procedimiento NVARCHAR(128)
);

-- Procedimiento con manejo de errores
CREATE PROCEDURE sp_RegistrarPaciente
    @nombre VARCHAR(80),
    @email VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        INSERT INTO Paciente (nombre, email)
        VALUES (@nombre, @email);
        
        SELECT SCOPE_IDENTITY() AS nuevo_id;
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        -- Registrar error en log
        INSERT INTO LogErrores (numero_error, mensaje, severidad, estado, linea, procedimiento)
        VALUES (
            ERROR_NUMBER(),
            ERROR_MESSAGE(),
            ERROR_SEVERITY(),
            ERROR_STATE(),
            ERROR_LINE(),
            ERROR_PROCEDURE()
        );
        
        -- Re-lanzar el error para que el cliente lo vea
        THROW;
    END CATCH;
END;
```

### 3.4 THROW vs RAISERROR

```sql
-- THROW (recomendado, moderno)
THROW 50001, 'Error personalizado: el email ya existe', 1;

-- RAISERROR (legado, aún válido)
RAISERROR('Error personalizado: el email ya existe', 16, 1);
```

**Diferencias:**
- `THROW`: más simple, requiere número de error y mensaje
- `RAISERROR`: más flexible, permite formato de mensajes, nivel de severidad

---

## 4. Niveles de Aislamiento

### 4.1 ¿Qué es el Aislamiento?

El nivel de aislamiento controla cómo las transacciones concurrentes interactúan entre sí. Determina si una transacción puede **ver** los cambios de otra transacción que aún no se han confirmado.

### 4.2 Niveles Disponibles

| Nivel | Problema | Lecturas Sucias | Lecturas No Repetibles | Phantom Reads |
|-------|----------|-----------------|------------------------|---------------|
| READ UNCOMMITTED | Mínimo | Sí | Sí | Sí |
| READ COMMITTED | Por defecto | No | Sí | Sí |
| REPEATABLE READ | Moderado | No | No | Sí |
| SERIALIZABLE | Máximo | No | No | No |
| SNAPSHOT | Basado en versión | No | No | No |

### 4.3 Lecturas Sucias, No Repetibles y Phantom

**Lectura sucia:** Lees datos que otra transacción aún no ha confirmado.

```
Transacción A: UPDATE saldo SET monto = 100 (sin COMMIT)
Transacción B: SELECT saldo → lee 100
Transacción A: ROLLBACK (se deshace)
Transacción B: ¡Error! Leyó un dato que nunca existió
```

**Lectura no repetible:** Lees los mismos datos dos veces y obtienes valores diferentes.

```
Transacción A: SELECT saldo FROM cuenta WHERE id=1 → 100
Transacción B: UPDATE cuenta SET saldo = 200 WHERE id=1; COMMIT;
Transacción A: SELECT saldo FROM cuenta WHERE id=1 → 200 (¡cambió!)
```

**Phantom read:** Una transacción lee filas que aparecen o desaparecen.

```
Transacción A: SELECT COUNT(*) FROM pedido WHERE fecha = '2026-08-20' → 5
Transacción B: INSERT INTO pedido... (nuevo pedido con esa fecha); COMMIT;
Transacción A: SELECT COUNT(*) FROM pedido WHERE fecha = '2026-08-20' → 6 (¡apareció una!)
```

### 4.4 Establecer Nivel de Aislamiento

```sql
-- Para una sesión completa
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- Para una transacción específica
BEGIN TRANSACTION;
    -- nivel específico
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
    SELECT * FROM Cuenta WHERE id = 1;
COMMIT TRANSACTION;
```

---

## 5. Deadlocks (Bloqueos Mutuos)

### 5.1 ¿Qué es un Deadlock?

Ocurre cuando dos transacciones esperan mutuamente que la otra libere un recurso. **Ninguna puede avanzar.**

```
Transacción A: Bloquea fila 1, espera fila 2
Transacción B: Bloquea fila 2, espera fila 1
→ ¡DEADLOCK! SQL Server mata a una de las dos (víctima)
```

### 5.2 Cómo Detectar y Manejar

```sql
BEGIN TRY
    BEGIN TRANSACTION;
    
    -- Operación que podría causar deadlock
    UPDATE Cuenta SET saldo = saldo - 100 WHERE id = 1;
    UPDATE Cuenta SET saldo = saldo + 100 WHERE id = 2;
    
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    -- Error 1205 = deadlock victim
    IF ERROR_NUMBER() = 1205
    BEGIN
        PRINT 'Deadlock detectado. Reintentando...';
        -- Lógica de reintento
    END
    ELSE
    BEGIN
        THROW;
    END
END CATCH;
```

### 5.3 Estrategias para Evitar Deadlocks

| Estrategia | Descripción |
|------------|-------------|
| **Orden consistente** | Siempre acceder a las tablas en el mismo orden |
| **Transacciones cortas** | Minimizar el tiempo que se mantienen bloqueos |
| **Índices adecuados** | Reducir el número de filas bloqueadas |
| **NO usar NOLOCK** | Puede causar lecturas sucias |
| **Timeouts** | Establecer timeout de deadlock más bajo |

---

## 6. Patrones Comunes

### 6.1 Patrón Básico (Recomendado)

```sql
CREATE PROCEDURE sp_Transferencia
    @cuenta_origen INT,
    @cuenta_destino INT,
    @monto DECIMAL(12,2)
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Validaciones
        IF NOT EXISTS (SELECT 1 FROM Cuenta WHERE id_cuenta = @cuenta_origen AND saldo >= @monto)
        BEGIN
            RAISERROR('Saldo insuficiente o cuenta origen inexistente', 16, 1);
            RETURN;
        END
        
        -- Operaciones
        UPDATE Cuenta SET saldo = saldo - @monto WHERE id_cuenta = @cuenta_origen;
        UPDATE Cuenta SET saldo = saldo + @monto WHERE id_cuenta = @cuenta_destino;
        
        -- Registrar movimiento
        INSERT INTO Movimiento (cuenta_origen, cuenta_destino, monto, fecha)
        VALUES (@cuenta_origen, @cuenta_destino, @monto, GETDATE());
        
        COMMIT TRANSACTION;
        
        PRINT 'Transferencia exitosa';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        -- Log del error
        INSERT INTO LogErrores (numero_error, mensaje, fecha)
        VALUES (ERROR_NUMBER(), ERROR_MESSAGE(), GETDATE());
        
        -- Re-lanzar
        THROW;
    END CATCH;
END;
```

### 6.2 Transacciones con SAVE TRANSACTION

```sql
CREATE PROCEDURE sp_ProcesoCompleto
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Paso 1: Crear pedido
        INSERT INTO Pedido (id_cliente, fecha) VALUES (1, GETDATE());
        DECLARE @id_pedido INT = SCOPE_IDENTITY();
        SAVE TRANSACTION sp_PedidoCreado;
        
        -- Paso 2: Agregar detalles (puede fallar)
        INSERT INTO DetallePedido (id_pedido, id_producto, cantidad)
        VALUES (@id_pedido, 10, 5);
        
        -- Paso 3: Actualizar inventario (puede fallar)
        UPDATE Producto SET stock = stock - 5 WHERE id_producto = 10;
        
        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR('Producto no encontrado o stock insuficiente', 16, 1);
        END
        
        COMMIT TRANSACTION;
        
        PRINT 'Proceso completado exitosamente';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        THROW;
    END CATCH;
END;
```

### 6.3 Verificación Previa de Condiciones

```sql
CREATE PROCEDURE sp_EliminarCliente
    @id_cliente INT
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        -- Verificar que no tenga pedidos activos
        IF EXISTS (SELECT 1 FROM Pedido WHERE id_cliente = @id_cliente AND estado = 'Activo')
        BEGIN
            RAISERROR('No se puede eliminar: el cliente tiene pedidos activos', 16, 1);
            RETURN;
        END
        
        BEGIN TRANSACTION;
        
        -- Eliminar en orden correcto (hijos primero)
        DELETE FROM DetallePedido WHERE id_pedido IN (
            SELECT id_pedido FROM Pedido WHERE id_cliente = @id_cliente
        );
        DELETE FROM Pedido WHERE id_cliente = @id_cliente;
        DELETE FROM Cliente WHERE id_cliente = @id_cliente;
        
        COMMIT TRANSACTION;
        
        PRINT 'Cliente eliminado exitosamente';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        THROW;
    END CATCH;
END;
```

---

## 7. Funciones Útiles

### 7.1 @@TRANCOUNT

Retorna el número de transacciones activas.

```sql
BEGIN TRANSACTION;
    PRINT @@TRANCOUNT;  -- 1
    BEGIN TRANSACTION;
        PRINT @@TRANCOUNT;  -- 2
    COMMIT;
    PRINT @@TRANCOUNT;  -- 1
COMMIT;
PRINT @@TRANCOUNT;  -- 0
```

**Uso práctico:** Verificar si hay una transacción activa antes de hacer ROLLBACK.

```sql
IF @@TRANCOUNT > 0
    ROLLBACK TRANSACTION;
```

### 7.2 XACT_STATE()

Retorna el estado de la transacción actual.

| Valor | Significado |
|-------|-------------|
| 1 | Transacción activa y con COMMIT posible |
| -1 | Transacción activa pero solo ROLLBACK posible (disconnected) |
| 0 | Sin transacción activa |

```sql
BEGIN TRY
    BEGIN TRANSACTION;
        -- código
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() = -1
        ROLLBACK TRANSACTION;
    ELSE IF XACT_STATE() = 1
        COMMIT TRANSACTION;
    
    THROW;
END CATCH;
```

---

## 8. Ejercicios Prácticos

### Ejercicio 1: Transferencia Bancaria

Crear un procedimiento `sp_TransferenciaBancaria` que:
1. Valide que ambas cuentas existan
2. Valide saldo suficiente
3. Realice la transferencia de forma atómica
4. Registre el movimiento en tabla `Movimiento`
5. Maneje errores correctamente

### Ejercicio 2: Pedido con Inventario

Crear un procedimiento `sp_CrearPedido` que:
1. Inserte un pedido
2. Inserte múltiples detalles
3. Actualice el inventario de cada producto
4. Valide que haya stock suficiente para cada producto
5. Use SAVE TRANSACTION para poder deshacer parcialmente

### Ejercicio 3: Migración de Datos

Crear un procedimiento `sp_MigrarClientes` que:
1. Lea clientes de una tabla origen
2. Los inserte en una tabla destino
3. Use transacciones por lotes (cada 100 registros)
4. Registre errores sin abortar toda la migración

---

## 9. Preguntas de Autoevaluación

1. ¿Cuáles son las 4 propiedades ACID? Da un ejemplo práctico de cada una.

2. ¿Cuándo usarías ROLLBACK TRANSACTION en lugar de COMMIT TRANSACTION?

3. ¿Qué diferencia hay entre TRY/CATCH y las validaciones IF...ELSE?

4. ¿Qué es un deadlock y cómo se puede evitar?

5. ¿Cuándo usarías SAVE TRANSACTION?

6. ¿Qué retorna XACT_STATE() y por qué es importante en el manejo de errores?

7. ¿Por qué se recomienda usar SET NOCOUNT ON al inicio de los procedimientos?

8. ¿Qué sucede si no verificas @@TRANCOUNT antes de hacer ROLLBACK?

9. ¿Cuál es la diferencia entre THROW y RAISERROR?

10. ¿Por qué es importante registrar errores en una tabla de log?

---

## 10. Recursos Adicionales

### Documentación Oficial
- [BEGIN TRANSACTION (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/begin-transaction-transact-sql)
- [TRY...CATCH (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/try-catch-transact-sql)
- [Transaction Locking and Row Versioning Guide](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide)

### Buenas Prácticas
- Siempre usar TRY...CATCH en procedimientos que modifican datos
- Verificar @@TRANCOUNT antes de ROLLBACK
- Usar SET NOCOUNT ON para mejorar rendimiento
- Registrar errores en tabla de log
- Mantener transacciones lo más cortas posible
