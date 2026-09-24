# Administración de Bases de Datos

Repositorio central de la asignatura **Administración de Bases de Datos** (UNAN-Managua, 2° Semestre 2026). Centraliza el material de clases, las tareas asignadas y la ruta del proyecto integrador.

## Estructura del repositorio

```
ABD/
├── Actividades/
│   └── Refuerzo Normalización/
│       └── Escenarios de Normalizacion.md
├── Clases/                       # Material de clases
│   ├── README.md                 # Escenario Modelo: Concesionario
│   ├── ConcessionaireDB Script.sql   # Script consolidado
│   ├── AuxiliaryScript.sql       # Script auxiliar
│   ├── 00 - Repaso Fundamentos SQL/
│   │   ├── 00-Fundamentos-Llaves-SQL.md
│   │   ├── Asignacion-00.md
│   │   └── Resolucion-Asignacion-00.sql
│   ├── 01 - Transacciones/
│   │   ├── 01-Transacciones-y-Manejo-Errores.md
│   │   └── Asignacion-01-Transacciones.md
│   ├── 02 - Triggers/
│   │   ├── 02-Triggers-DML.md
│   │   └── Asignacion-02-Triggers.md
│   ├── 03 - Esquemas/
│   │   ├── 03-Esquemas-y-Organizacion-Objetos.md
│   │   └── Asignacion-03-Esquemas.md
├── Proyecto Integrador/          # Ruta del proyecto final
│   ├── README.md                 # Índice de la sección
│   ├── 00 - Contexto.md
│   ├── 01 - Primer Corte Evaluativo.md
│   └── 02 - Segundo Corte Evaluativo.md
├── LICENSE
└── README.md
```

## Índice de directorios

### Actividades

| Ubicación | Descripción |
|-----------|-------------|
| `Actividades/` | Registro de las tareas asignadas. |

### Clases

| Ubicación | Descripción |
|-----------|-------------|
| `Clases/README.md` | **Escenario Modelo: Concesionario.** Descripción del proyecto y problemática a abordar. |
| `Clases/ConcessionaireDB Script.sql` | Script de base de datos. |
| `Clases/AuxiliaryScript.sql` | Script de apoyo. |
| `Clases/NN - Tema/` | Carpeta por clase con el material (`.md`), la guía de trabajo (`Asignacion-NN.md`) y la resolución correspondiente (`.sql`). |

| Clase | Material | Guía de trabajo |
|-------|----------|-----------------|
| `00 - Repaso Fundamentos SQL` | [`00-Fundamentos-Llaves-SQL.md`](Clases/00%20-%20Repaso%20Fundamentos%20SQL/00-Fundamentos-Llaves-SQL.md) | [`Asignacion-00.md`](Clases/00%20-%20Repaso%20Fundamentos%20SQL/Asignacion-00.md) |
| `01 - Transacciones` | [`01-Transacciones-y-Manejo-Errores.md`](Clases/01%20-%20Transacciones/01-Transacciones-y-Manejo-Errores.md) | [`Asignacion-01-Transacciones.md`](Clases/01%20-%20Transacciones/Asignacion-01-Transacciones.md) |
| `02 - Triggers` | [`02-Triggers-DML.md`](Clases/02%20-%20Triggers/02-Triggers-DML.md) | [`Asignacion-02-Triggers.md`](Clases/02%20-%20Triggers/Asignacion-02-Triggers.md) |
| `03 - Esquemas` | [`03-Esquemas-y-Organizacion-Objetos.md`](Clases/03%20-%20Esquemas/03-Esquemas-y-Organizacion-Objetos.md) | [`Asignacion-03-Esquemas.md`](Clases/03%20-%20Esquemas/Asignacion-03-Esquemas.md) |

### Proyecto Integrador

| Ubicación | Descripción |
|-----------|-------------|
| `Proyecto Integrador/` | Definición de la ruta del proyecto final: [índice](Proyecto%20Integrador/README.md), contexto, entregables (Semana 8 y Semana 14) y rúbrica de evaluación. |

## Escenario Modelo

El componente se trabaja sobre una base de datos de práctica **Concesionario**, construida gradualmente para aplicar los conceptos de cada tema.

[Ver descripción del escenario en `Clases/README.md`](Clases/README.md)

## Convenciones de nombrado

| Objeto | Formato | Ejemplo |
|--------|---------|---------|
| Carpeta de clase | `NN - Tema` | `01 - Transacciones` |
| Material de clase | `NN-Tema.md` | `01-Transacciones-y-Manejo-Errores.md` |
| Guía de trabajo | `Asignacion-NN-Tema.md` | `Asignacion-01-Transacciones.md` |
| Resolución de guía | `Resolucion-Asignacion-NN.*` | `Resolucion-Asignacion-00.sql` |

## Licencia

Distribuido bajo la [licencia MIT](LICENSE).