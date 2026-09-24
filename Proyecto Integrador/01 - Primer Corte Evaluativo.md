# Entregable 1 — Semana 8

## Documento de ajustes de seguridad previstos

### Objetivo

Elaborar un documento que detalle los ajustes de seguridad previstos para la Base de Datos OLTP, estableciendo la línea base sobre la cual se implementará el script del segundo entregable.

### Contenido requerido

El documento debe abordar los siguientes puntos:

- [ ] **Modelado de la Base de Datos**: descripción del modelo de datos que cumpla la normalización hasta la tercera forma normal (3FN).
- [ ] **Roles previstos**: definición de los roles necesarios para la operación del sistema.
- [ ] **Usuarios a crear**: identificación de los usuarios que se crearán y a qué rol pertenecen.
- [ ] **Definición de grupos de permisos**: grupos de permisos que agrupan privilegios según el tipo de operación.
- [ ] **Asignación de grupos de permisos**: distribución de los grupos de permisos entre roles y usuarios.
- [ ] **Justificación del nivel de acceso de cada grupo de permisos**: fundamentación del nivel de acceso otorgado a cada grupo.
- [ ] **Definición de esquemas a integrar**: esquemas que se incorporarán a la base de datos y su propósito.
- [ ] **Justificación del o los tipos de Backup a efectuar**: fundamentación de las estrategias de respaldo seleccionadas para la base de datos.
- [ ] **Justificación de Triggers a crear**: fundamentación de los triggers propuestos y las operaciones que automatizan.
- [ ] **Justificación de Tareas Programadas a crear**: fundamentación de las tareas programadas y los procesos que ejecutan.

### Rúbrica de evaluación

Escala de puntuación aplicada a cada criterio:

| Puntaje | Nivel |
|---------|-------|
| 2 | Insuficiente |
| 3 | Regular |
| 4 | Aprobatorio |
| 5 | Sobresaliente |

| Criterio | 2 · Insuficiente | 3 · Regular | 4 · Aprobatorio | 5 · Sobresaliente |
|----------|------------------|-------------|-----------------|-------------------|
| Modelado de la Base de Datos | El modelo no cumple la normalización hasta la 3FN o presenta errores de diseño graves. | El modelo alcanza parcialmente la 3FN con anomalías pendientes. | El modelo cumple la 3FN, aunque con detalles menores de diseño. | El modelo cumple la 3FN con un diseño sólido y justificado. |
| Buenas prácticas (temas 00, 01, 05 y 06) | No se evidencia aplicación de los temas del componente. | Aplica los temas de forma parcial o inconsistente. | Aplica los temas con criterio y de forma consistente. | Aplica y justifica los temas de forma integral y ejemplar. |
| Definición de jerarquía de acceso | No se definen roles, permisos, usuarios ni asignaciones, o lo hacen de forma incompleta. | La jerarquía está definida pero con vacíos o inconsistencias. | La jerarquía de acceso es clara y completa. | La jerarquía de acceso es completa y su asignación está correctamente justificada. |
| Justificación de los esquemas creados | No se justifican los esquemas o la justificación carece de fundamento. | Justificación débil o poco relacionada con la seguridad. | Justificación clara y alineada con el objetivo del proyecto. | Justificación técnica sólida que evidencia dominio del tema. |
| Justificación de triggers y tareas programadas | No se justifican los triggers ni las tareas programadas. | Justificación parcial o superficial de alguno de ellos. | Justificación clara de triggers y tareas programadas. | Justificación detallada y bien fundamentada de ambos elementos. |
| Validación de conocimientos adquiridos | No se evidencia dominio de los contenidos del componente. | Dominio parcial de los contenidos. | Dominio adecuado de los contenidos. | Dominio completo y demostrado del conocimiento adquirido. |