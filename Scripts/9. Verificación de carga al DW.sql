-- ============================================================================
-- PASO 1: CREACIÓN DE LOS MIEMBROS DESCONOCIDOS (Dummys -1 / 1900-01-01)
-- ============================================================================
-- Esto se hace ANTES que las fácticas para que Power BI y SQL no fallen con nulos.

-- 1.1 Dummy en Clientes
SET IDENTITY_INSERT Dim_cliente ON;
INSERT INTO Dim_cliente (sk_cliente, Id_cliente, Nombre_cliente, Tipo_cliente)
VALUES (-1, -1, 'Cliente Desconocido', 'Desconocido');
SET IDENTITY_INSERT Dim_cliente OFF;
GO

-- 1.2 Dummy en Empleados
SET IDENTITY_INSERT Dim_empleado ON;
INSERT INTO Dim_empleado (sk_empleado, Id_empleado, Nombre_empleado)
VALUES (-1, -1, 'Empleado Desconocido');
SET IDENTITY_INSERT Dim_empleado OFF;
GO

-- 1.3 Registro base en el Calendario para ventas sin fecha
IF NOT EXISTS (SELECT 1 FROM Dim_Calendario WHERE sk_fecha = '1900-01-01')
BEGIN
    INSERT INTO Dim_Calendario (sk_fecha, Dia, Mes, Año, Nombre_dia, Nombre_mes)
    VALUES ('1900-01-01', 1, 1, 1900, 'Desconocido', 'Desconocido');
END
GO

-- ============================================================================
-- PASO 2: INGESTIÓN DE DIMENSIONES MAESTRAS (Clientes)
-- ============================================================================
INSERT INTO Dim_cliente (
    Id_cliente, 
    sk_geografia,       -- Clave foránea que apunta a la dimensión geografía
    Nombre_cliente, 
    Tipo_cliente, 
    Fecha_nacimiento
)
SELECT 
    stg.CUSTOMER_ID,
    geo.sk_geografia,   -- Traemos la SK generada en lugar del texto crudo
    stg.FULL_NAME,
    stg.TIPO_CLIENTE,
    stg.BIRTH_DATE
FROM L4_vw_clientes_final stg
LEFT JOIN Dim_geografia geo ON stg.ZIPCODE = geo.Codigo_postal;
GO

-- ============================================================================
-- PASO 3: INGESTIÓN DE LA FACT TABLE DE VENTAS (Cerebro Comercial)
-- ============================================================================
-- Limpiamos nulos mapeando directo a los dummys (-1) que creamos en el Paso 1

INSERT INTO Fac_venta (
    SK_Cliente,
    SK_Empleado,
    SK_Producto,
    sk_fecha_venta,
    sk_grupo_etario,
    Nro_factura,
    Region,
    Edad_cliente,
    Edad_empleado,
    Antiguedad_empleado,
    Sistema_origen,
    Cantidad_producto,
    Litros_totales,
    Precio_individual,
    Precio_final,
    Descuento,
    Precio_final_descuento
)
SELECT 
    -- 3.1 Claves Subrogadas (Mapeo a -1 si el ID no existe en la dimensión)
    ISNULL(dc.sk_cliente, -1) AS SK_Cliente,
    ISNULL(de.sk_empleado, -1) AS SK_Empleado,
    ISNULL(dp.sk_producto, -1) AS SK_Producto,
    
    -- 3.2 Atributos de Dimensión Directos e Inyección de Limpieza para Power BI
    ISNULL(f.FechaVenta, '1900-01-01') AS sk_fecha_venta,      
    ISNULL(f.id_rango_etario_cliente, -1) AS sk_grupo_etario, 
    f.billing_id AS Nro_factura,
    ISNULL(f.region, 'Región Desconocida') AS Region,
    ISNULL(f.EdadClienteAlComprar, 0) AS Edad_cliente,
    ISNULL(f.EdadEmpleadoAlVender, 0) AS Edad_empleado,
    ISNULL(f.AntiguedadEmpleadoAlVender, 0) AS Antiguedad_empleado,

    -- 3.3 Métricas puras calculadas en la vista final
    f.sis_origen AS Sistema_origen,                  
    f.CantidadVendida AS Cantidad_producto,
    f.LitrosTotalesLinea AS Litros_totales,
    f.PrecioUnitarioHistorico AS Precio_individual,
    f.MontoBrutoLinea AS Precio_final,
    f.PorcentajeDescuentoAplicado AS Descuento,
    f.MontoNetoFinalLinea AS Precio_final_descuento
FROM vw_L4_Fact_Billings_Final f
LEFT JOIN Dim_cliente dc ON f.customer_id = dc.Id_cliente
LEFT JOIN Dim_empleado de ON f.employee_id = de.Id_empleado
OUTER APPLY (
    -- Captura la versión histórica correcta del producto (SCD Tipo 2)
    SELECT TOP 1 sk_producto FROM Dim_producto
    WHERE Id_producto = f.product_id AND Fecha_Desde <= f.FechaVenta 
    ORDER BY Fecha_Desde DESC
) dp;
GO

-- ============================================================================
-- PASO 4: INGESTIÓN DE LA FACT TABLE DE STOCK (Inventario)
-- ============================================================================
INSERT INTO Fac_stock (
    Id_fecha_stock,
    Id_producto, -- Clave subrogada (SK) apuntando a Dim_producto
    Cantidad
)
SELECT 
    st.Fecha AS Id_fecha_stock, 
    ISNULL(dp.sk_producto, -1) AS Id_producto, -- Mapea a -1 si no se encuentra
    st.Cantidad_producto AS Cantidad
FROM vw_stock st
LEFT JOIN Dim_producto dp ON st.Id_producto = dp.Id_producto;
GO

-- ============================================================================
-- PASO 5: CONSULTAS DE VALIDACIÓN RÁPIDA
-- ============================================================================
SELECT TOP 10 * FROM Fac_venta;
SELECT TOP 10 * FROM Fac_stock;
SELECT TOP 5 * FROM Dim_cliente WHERE sk_cliente = -1;
