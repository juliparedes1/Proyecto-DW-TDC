# Proyecto-DW-TDC

# Pipeline ELT y Modelado Dimensional de Data Warehouse (End-to-End)

## 📋 Descripción del Proyecto
Este proyecto consiste en el diseño e implementación de una solución integral de Business Intelligence (BI) y Arquitectura de Datos. El objetivo principal fue transformar un ecosistema transaccional desnormalizado y con problemas de calidad de datos en un **Data Warehouse (DW) empresarial** optimizado para analítica avanzada, utilizando la metodología de Ralph Kimball.

La solución procesa e integra de manera eficiente un volumen de facturación de **más de 1.6 millones de registros** de ventas e inventario, automatizando todo el flujo mediante un pipeline orquestado.

---

## Modelo Dimensional

![Image alt](https://github.com/juliparedes1/Proyecto-DW-TDC/blob/42654e9505157826eee1676372cc6d07426a3807/Modelo%20dimensional%20tdc.png)


---

## 🛠️ Tecnologías y Herramientas
* **Motor de Base de Datos:** SQL Server (T-SQL)
* **Orquestación y ETL/ELT:** SQL Server Integration Services (SSIS)
* **Entorno de Desarrollo:** Visual Studio
* **Modelado Dimensional:** Esquema en Estrella (Star Schema) / Copo de Nieve (Snowflake)

---

## 🏗️ Arquitectura del Pipeline: Enfoque ELT
A diferencia de los procesos ETL tradicionales que sobrecargan la memoria intermedia del servidor de integración, este proyecto implementa un enfoque **ELT (Extract, Load, Transform)** impulsado por código SQL optimizado. 

1.  **Extract & Load (Staging):** Los datos crudos se extraen de los sistemas de origen y se cargan en paralelo en un área de aterrizaje (`Staging_tdc`). Las tareas se ejecutan de forma simultánea para maximizar el rendimiento de la red.
2.  **Transform (Data Warehouse):** Toda la lógica pesada de negocio, cálculo de métricas (`MontoBrutoLinea`, `LitrosTotalesLinea`) y la traducción de Claves Naturales a Claves Sustitutas se delega directamente al motor de SQL Server mediante sentencias relacionales avanzadas, garantizando una velocidad de procesamiento óptima.

---

## 📐 Modelo de Datos (Diseño Dimensional)
El Data Warehouse final (`DW_TDC`) se estructuró para garantizar un rendimiento analítico de alta velocidad:

* **Tablas de Hechos (Facts):**
    * `Fac_venta`: Registra las transacciones históricas de facturación a nivel de línea de detalle.
    * `Fact_Stock`: Una tabla de tipo **Instantánea Periódica (Periodic Snapshot)** para auditar balances de inventario, controlando métricas no aditivas a través del tiempo.
* **Tablas de Dimensiones:**
    * `Dim_cliente` & `Dim_empleado`: Dimensiones principales del negocio.
    * `Dim_geografia`: Conectada jerárquicamente para análisis territorial.
    * `Dim_Calendario`: Dimensión optimizada a nivel de bytes mediante tipos de datos mínimos (`TINYINT`, `SMALLINT`) para acelerar filtros temporales y funciones de Inteligencia de Tiempo.
    * `Dim_grupo_etario`: Dimensión estática para segmentación demográfica.

---

## 🚀 Desafíos Técnicos y Soluciones de Ingeniería

El mayor valor de este proyecto radica en la resolución de escenarios complejos de calidad de datos e integridad referencial:

### 1. Control del Efecto "Fan-Out" en SCD Tipo 2
* **Problema:** La dimensión de productos maneja historial de cambios (SCD Tipo 2) pero carecía de una fecha de fin de vigencia (`Fecha_Hasta`). Al realizar un `LEFT JOIN` tradicional por el ID del producto, las facturas se multiplicaban de forma cartesiana por cada cambio histórico, inflando el volumen de 1.6 a 5 millones de filas.
* **Solución:** Se reemplazó el join por un operador `OUTER APPLY` combinando un filtro temporal de frontera (`Fecha_Desde <= FechaVenta`) con un ordenamiento descendente y un `TOP 1`. Esto forzó al motor a capturar únicamente el estado exacto del producto al momento de la venta, restituyendo el volumen a los 1.6 millones reales.

### 2. Imputación de Precios ante Atributos Temporales Nulos
* **Problema:** El sistema transaccional presentaba facturas huérfanas sin fecha de venta (`FechaVenta IS NULL`). Al no tener fecha, la lógica de rangos fallaba y devolvía métricas financieras en `NULL`, lo que destruiría la consistencia de la recaudación total.
* **Solución:** Se diseñó una regla de negocio mediante lógica de conjuntos en el `WHERE` del producto. Si la venta tiene fecha, se busca su precio histórico; si es nula, el sistema ignora la restricción temporal y hereda automáticamente el **último precio conocido** (donde la fecha hasta de la ventana es nula), salvando el registro de venta.

### 3. Blindaje de Integridad Referencial (Miembros Inferidos)
* **Problema:** El motor rechazaba inserciones en la tabla fáctica debido a violaciones de claves foráneas provocadas por registros de clientes o empleados inexistentes o corruptos en Staging.
* **Solución:** Se implementó el patrón de **Miembros Inferidos (Dummys)**. Se automatizó la inyección de registros comodín con ID `-1` ("Desconocido") utilizando `SET IDENTITY_INSERT ON` dentro del flujo secuencial de SSIS. En la carga de la fáctica, se envolvieron las claves con `ISNULL(campo, -1)`, garantizando que ninguna venta se pierda y permitiendo la auditoría visual de datos huérfanos.

---

## 📈 Orquestación en SSIS
El flujo de control se diseñó respetando la dependencia estricta de base de datos (carga en cascada):

[Limpieza / Truncate Inicial]

[Carga de Dimensiones Base: Geografía / Calendario]
[Carga de Dimensiones Dependientes: Clientes / Empleados]
[Inyección Automática de Registros dummys]
[Carga Simultánea de Tablas Fácticas: Fac_venta & Fact_Stock]

---

## 💻 Cómo Ejecutar el Proyecto
1.  Clonar este repositorio.
2.  Ejecutar los scripts SQL de la carpeta `/Scripts/DDL` para crear las estructuras de Staging y DW.
3.  Ejecutar las vistas alojadas en `/Scripts/Views` (Capas de transformación L1 a L4).
4.  Abrir el proyecto de Integration Services (`.sln`) en Visual Studio.
5.  Configurar el Administrador de Conexiones OLE DB hacia tu instancia local de SQL Server.
6.  Ejecutar el paquete `Carga al DW.dtsx`.
