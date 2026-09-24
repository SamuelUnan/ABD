# 03. Esquemas y Organización de Objetos

## 1. ¿Qué es un Esquema?

Un **esquema** es un **contenedor lógico** para objetos de base de datos (tablas, vistas, procedimientos, etc.). Es como una "carpeta" que organiza y agrupa objetos relacionados.

**Analogía:** Piensa en un esquema como las secciones de una biblioteca:
- `dbo` → Sección general
- `ventas` → Libros de ventas
- `reportes` → Libros de reportes
- `auditoria` → Registros de auditoría

### Beneficios de los Esquemas

| Beneficio | Descripción |
|-----------|-------------|
| **Organización** | Agrupar objetos por área funcional |
| **Mantenimiento** | Administrar objetos relacionados juntos |
| **Escalabilidad** | Facilita el crecimiento de la base de datos |
| **Separación** | Distintos departamentos o módulos |

---

## 2. Gestión de Esquemas

### 2.1 Crear Esquema

```sql
-- Sintaxis básica
CREATE SCHEMA nombre_esquema;

-- Con autorización (propietario)
CREATE SCHEMA ventas AUTHORIZATION dbo;

-- Con comentarios
CREATE SCHEMA auditoria;
```

### 2.2 Esquemas Predeterminados

SQL Server tiene esquemas predefinidos:

| Esquema | Uso |
|---------|-----|
| `dbo` | Propietario de la base de datos (predeterminado) |
| `guest` | Para usuarios sin esquema asignado |
| `sys` | Objetos del sistema |
| `INFORMATION_SCHEMA` | Metadatos de la base de datos |

### 2.3 Ver Esquemas Existentes

```sql
-- Ver todos los esquemas
SELECT * FROM sys.schemas;

-- Ver esquemas con sus objetos
SELECT 
    s.name AS esquema,
    o.name AS objeto,
    o.type_desc AS tipo
FROM sys.schemas s
INNER JOIN sys.objects o ON s.schema_id = o.schema_id
ORDER BY s.name, o.name;
```

### 2.4 Modificar Esquema

```sql
-- Cambiar propietario
ALTER SCHEMA ventas TRANSFER dbo.Producto;

-- Eliminar esquema (debe estar vacío)
DROP SCHEMA IF EXISTS auditoria;
```

---

## 3. Asignar Objetos a Esquemas

### 3.1 Al Crear el Objeto

```sql
-- Tabla en esquema ventas
CREATE TABLE ventas.Cliente (
    id_cliente INT IDENTITY(1,1) PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL,
    email VARCHAR(100)
);

-- Vista en esquema reportes
CREATE VIEW reportes.VentasMensuales AS
SELECT 
    MONTH(fecha) AS mes,
    SUM(total) AS total_ventas
FROM ventas.Factura
GROUP BY MONTH(fecha);

-- Procedimiento en esquema administracion
CREATE PROCEDURE administracion.sp_BackupLog
AS
BEGIN
    PRINT 'Ejecutando backup log...';
END;
```

### 3.2 Mover Objeto a Otro Esquema

```sql
-- Mover tabla de dbo a ventas
ALTER SCHEMA ventas TRANSFER dbo.Inventario;

-- Mover stored procedure
ALTER SCHEMA administracion TRANSFER dbo.sp_Reporte;
```

### 3.3 Referenciar Objetos en Otro Esquema

```sql
-- Sintaxis: esquema.objeto
SELECT * FROM ventas.Cliente;
SELECT * FROM reportes.VentasMensuales;

-- Si el esquema es el predeterminado (dbo)
SELECT * FROM Cliente;  -- Equivale a dbo.Cliente
```

---

## 4. Organización con Esquemas

### 4.1 Modelo Recomendado para Aplicaciones

```
Base de datos: ClinicaDB
│
├── dbo              → Objetos generales
├── pacientes        → Tablas de pacientes
├── medicos          → Tablas de médicos
├── citas            → Tablas de citas
├── reportes         → Vistas de reportes
├── administracion   → Procedimientos de admin
└── auditoria        → Triggers y bitácoras
```

### 4.2 Ejemplo de Esquemas para Sistema de Ventas

```sql
-- Esquema de productos
CREATE SCHEMA productos;
CREATE TABLE productos.Categoria (...);
CREATE TABLE productos.Producto (...);

-- Esquema de ventas
CREATE SCHEMA ventas;
CREATE TABLE ventas.Cliente (...);
CREATE TABLE ventas.Pedido (...);
CREATE TABLE ventas.DetallePedido (...);

-- Esquema de inventario
CREATE SCHEMA inventario;
CREATE TABLE inventario.Stock (...);
CREATE TABLE inventario.Movimiento (...);

-- Esquema de reportes
CREATE SCHEMA reportes;
CREATE VIEW reportes.VentasPorDia AS ...;
CREATE VIEW reportes.ProductosMasVendidos AS ...;
```

---

## 5. Buenas Prácticas

### 5.1 Organización

| Práctica | Descripción |
|----------|-------------|
| Un esquema por módulo | ventas, compras, inventario, etc. |
| No abusar de dbo | Usar esquemas específicos |
| Nombres descriptivos | `ventas.Cliente` mejor que `dbo.C1` |
| Documentar esquemas | Mantener un mapa de la estructura |

### 5.2 Nomenclatura

```
Esquema:     ventas, productos, reportes, administracion
Tabla:       Cliente, Producto, Pedido (PascalCase o snake_case)
Vista:       v_VentasMensuales (prefijo v_)
Procedimiento: sp_RegistrarCliente (prefijo sp_)
Trigger:     tr_Producto_Audit (prefijo tr_)
```

---

## 6. Ejercicios Prácticos

### Ejercicio 1: Crear Esquemas

Crear una base de datos `UniversidadDB` con los siguientes esquemas:
1. `estudiantes` - Tablas de estudiantes
2. `docentes` - Tablas de docentes
3. `materias` - Tablas de materias
4. `calificaciones` - Tablas de calificaciones
5. `reportes` - Vistas de reportes

### Ejercicio 2: Mover Objetos

Mover una tabla de `dbo` a un esquema específico y verificar que siga consultándose desde el nuevo esquema.

---

## 7. Preguntas de Autoevaluación

1. ¿Qué es un esquema y por qué es importante?
2. ¿Cuál es la diferencia entre `dbo` y un esquema personalizado?
3. ¿Cómo se asigna un objeto a un esquema?
4. ¿Cómo se mueve un objeto de un esquema a otro?
5. ¿Qué esquemas predeterminados tiene SQL Server?
6. ¿Cómo se verifica a qué esquema pertenece un objeto?
7. ¿Por qué no se recomienda usar `dbo` para todo?

---

## 8. Recursos Adicionales

- [Schemas (Database Engine)](https://learn.microsoft.com/en-us/sql/relational-databases/security/schemas-database-engine)
