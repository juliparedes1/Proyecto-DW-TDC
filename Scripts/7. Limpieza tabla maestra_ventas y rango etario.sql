-- ============================================================================
-- PASO 1: LIMPIEZA DE ESTRUCTURAS PREVIAS (Para evitar errores de duplicados)
-- ============================================================================
DROP VIEW IF EXISTS vw_stock;
DROP VIEW IF EXISTS vw_L4_Fact_Billings_Final;
DROP VIEW IF EXISTS vw_L3_Billings_Contexto;
DROP VIEW IF EXISTS vw_L2_Billings_Precios;
DROP VIEW IF EXISTS vw_rango_etario;
DROP VIEW IF EXISTS vw_L2_Billings;
DROP VIEW IF EXISTS vw_L1_Billings;
GO

-- ============================================================================
-- PASO 2: CONSOLIDACIÓN DE FUENTES Y AGREGACIONES BÁSICAS (Capa L1 y L2)
-- ============================================================================

-- 2.1 Unificación de Sistema Nuevo y Viejo con limpieza de duplicados históricos
CREATE VIEW vw_L1_Billings AS 
WITH billings_sin_duplicados AS (
    SELECT 
        billing_id,
        date, customer_id,
        employee_id,
        product_id,
        region,
        SUM(quantity) AS quantity 
    FROM stg_billing_antigua 
    GROUP BY billing_id, date, customer_id, employee_id, product_id, region
)
-- FACTURAS NUEVAS (Inner Join elimina huérfanas sin productos)
SELECT 
    BA.BILLING_ID,
    BA.DATE,
    BA.CUSTOMER_ID,
    BA.EMPLOYEE_ID,
    BDN.PRODUCT_ID,
    BDN.QUANTITY,
    BA.REGION,
    sis_origen = 'Sis nuevo'
FROM stg_billing BA
INNER JOIN stg_billing_detail BDN ON BA.BILLING_ID = BDN.BILLING_ID

UNION ALL -- Combina maximizando el rendimiento

-- FACTURAS ANTIGUAS (Sin duplicados y filtrando nulos)
SELECT
    billing_id,
    [date],
    customer_id,
    employee_id,
    product_id,
    quantity,
    region,
    sis_origen = 'Sis antiguo'
FROM billings_sin_duplicados
WHERE product_id IS NOT NULL;
GO

-- 2.2 Filtrado rápido de consistencia operativa
CREATE VIEW vw_L2_Billings AS 
SELECT * FROM vw_L1_Billings WHERE PRODUCT_ID IS NOT NULL AND QUANTITY IS NOT NULL;
GO

-- 2.3 Dimensión estática auxiliar de rangos etarios
CREATE VIEW vw_rango_etario AS
SELECT 1 AS id_rango, 0 AS edad_desde, 12 AS edad_hasta, 'Niño' AS descripcion UNION ALL
SELECT 2, 13, 19, 'Adolescente' UNION ALL
SELECT 3, 20, 39, 'Adulto joven' UNION ALL
SELECT 4, 40, 65, 'Adulto' UNION ALL
SELECT 5, 66, 66, 'consumidores de 66' UNION ALL
SELECT 6, 67, 120, 'Adultos mayores';
GO

-- ============================================================================
-- PASO 3: ANÁLISIS TEMPORAL DE PRECIOS E HISTORIAL DE PRODUCTOS (Capa L2 Precios)
-- ============================================================================
CREATE VIEW vw_L2_Billings_Precios AS
WITH PreciosConRango AS (
    SELECT 
        PRODUCT_ID, date AS FechaDesde, PRICE,
        -- LEAD calcula dinámicamente la fecha de fin de vigencia del precio (SCD Tipo 2)
        LEAD(date) OVER(PARTITION BY Product_ID ORDER BY date) AS FechaHasta
    FROM vw_Maestra_Productos
)
SELECT 
    B.billing_id,
    B.date AS FechaVenta,
    B.customer_id,
    B.employee_id,
    B.product_id,
    B.quantity,
    B.region,
    B.sis_origen,
    p.PRICE AS PrecioUnitarioHistorico,
   (B.quantity * p.PRICE) AS MontoBrutoLinea
FROM vw_L1_Billings B
LEFT JOIN PreciosConRango p ON B.product_id = p.Product_ID
    AND (
        -- CASO A: La venta cae exactamente en la vigencia del precio histórico
        (B.date >= p.FechaDesde AND (B.date < p.FechaHasta OR p.FechaHasta IS NULL))
        OR 
        -- CASO B: Venta sin fecha (asigna precio actual donde FechaHasta es nulo)
        (B.date IS NULL AND p.FechaHasta IS NULL)
    );
GO

-- ============================================================================
-- PASO 4: ENRIQUECIMIENTO DEMOGRÁFICO Y EDADES DEL MOMENTO (Capa L3 Contexto)
-- ============================================================================
CREATE VIEW vw_L3_Billings_Contexto AS
SELECT 
    f.billing_id,
    f.FechaVenta,
    f.customer_id,
    f.employee_id,
    f.product_id,
    f.quantity,
    f.region,
    f.PrecioUnitarioHistorico,
    f.sis_origen,
    f.MontoBrutoLinea,
    -- Edad exacta del cliente al momento de comprar
    FLOOR(DATEDIFF(DAY, c.BIRTH_DATE, f.FechaVenta) / 365.25) AS EdadClienteAlComprar,
    re.id_rango AS id_rango_etario_cliente,
    -- Edad exacta del empleado al vender
    FLOOR(DATEDIFF(DAY, e.BIRTH_DATE, f.FechaVenta) / 365.25) AS EdadEmpleadoAlVender,
    -- Antigüedad exacta del empleado al vender
    FLOOR(DATEDIFF(DAY, e.EMPLOYMENT_DATE, f.FechaVenta) / 365.25) AS AntiguedadEmpleadoAlVender
FROM vw_L2_Billings_Precios f
LEFT JOIN L4_vw_clientes_final c ON f.customer_id = c.CUSTOMER_ID
LEFT JOIN vw_maestra_empleados e ON f.employee_id = e.EMPLOYEE_ID
LEFT JOIN vw_rango_etario re ON FLOOR(DATEDIFF(DAY, c.BIRTH_DATE, f.FechaVenta) / 365.25) >= re.edad_desde
                            AND FLOOR(DATEDIFF(DAY, c.BIRTH_DATE, f.FechaVenta) / 365.25) <= re.edad_hasta;
GO

-- ============================================================================
-- PASO 5: CAPA FINAL DE HECHOS - VOLUMEN Y DESCUENTOS DINÁMICOS (Capa L4 Fact)
-- ============================================================================
CREATE VIEW vw_L4_Fact_Billings_Final AS
WITH CalculoTotalFactura AS (
    SELECT 
        f.billing_id,
        f.FechaVenta,
        f.customer_id,
        f.employee_id,
        f.product_id,
        f.region,
        f.quantity,
        f.PrecioUnitarioHistorico,
        f.MontoBrutoLinea,
        f.sis_origen,
        f.EdadClienteAlComprar,
        f.EdadEmpleadoAlVender,
        f.id_rango_etario_cliente,
        f.AntiguedadEmpleadoAlVender,
        ISNULL(p.Capacidad_en_Litros, 0) AS LitrosUnitarios,
        (f.quantity * ISNULL(p.Capacidad_en_Litros, 0)) AS LitrosTotalesLinea,
        -- Suma acumulada de la factura para evaluar escalonamiento de promociones
        SUM(f.MontoBrutoLinea) OVER(PARTITION BY f.billing_id) AS TotalFacturaFicticio
    FROM vw_L3_Billings_Contexto f
    OUTER APPLY (
        SELECT TOP 1 Capacidad_en_Litros FROM vw_Maestra_Productos dp
        WHERE dp.PRODUCT_ID = f.product_id
          AND ((f.FechaVenta IS NOT NULL AND dp.DATE <= f.FechaVenta) OR (f.FechaVenta IS NULL))
        ORDER BY dp.DATE DESC
    ) p
)
SELECT 
    c.billing_id,
    c.FechaVenta,
    c.customer_id,
    c.employee_id,
    c.product_id,
    c.region,
    c.EdadClienteAlComprar,
    c.id_rango_etario_cliente,
    c.AntiguedadEmpleadoAlVender,
    c.EdadEmpleadoAlVender,
    c.sis_origen,
    c.quantity AS CantidadVendida,
    c.LitrosTotalesLinea,
    c.PrecioUnitarioHistorico,
    c.MontoBrutoLinea,
    (CAST(ISNULL(desc_aplicado.PERCENTAGE, 0) AS FLOAT) / 100.0) AS PorcentajeDescuentoAplicado,
    -- Monto Neto Final con el descuento comercial ganador aplicado
    c.MontoBrutoLinea * (1.0 - (CAST(ISNULL(desc_aplicado.PERCENTAGE, 0) AS FLOAT) / 100.0)) AS MontoNetoFinalLinea
FROM CalculoTotalFactura c
OUTER APPLY (
    -- Busca dinámicamente la mejor promoción disponible para la fecha y volumen total facturado
    SELECT TOP 1 d.PERCENTAGE FROM stg_discounts d
    WHERE c.FechaVenta >= d.[FROM]
      AND (d.[UNTIL] IS NULL OR c.FechaVenta <= d.[UNTIL])
      AND c.TotalFacturaFicticio >= d.TOTAL_BILLING
    ORDER BY d.TOTAL_BILLING DESC
) desc_aplicado;
GO

-- ============================================================================
-- PASO 6: LIMPIEZA E INGESTIÓN DE LA SEGUNDA FACT TABLE (Stock)
-- ============================================================================
CREATE VIEW vw_stock AS 
SELECT 
    Id_producto,
    CAST(SUBSTRING(Fecha, 1, 10) as date) as Fecha,
    Cantidad_producto
FROM stg_stock;
GO

-- ============================================================================
-- PASO 7: AUDITORÍA Y CONTROL DE CALIDAD INTERNO (Ejecuciones de verificación)
-- ============================================================================
-- 7.1 Cruce de control de consistencia de clientes en el universo unificado vs maestro
SELECT COUNT(DISTINCT CUSTOMER_ID) AS Clientes_Unificados_L1 FROM vw_L1_Billings;
SELECT COUNT(DISTINCT CUSTOMER_ID) AS Clientes_Maestro_Final FROM L4_vw_clientes_final;

SELECT 
    BILLING_ID, DATE, B.CUSTOMER_ID, EMPLOYEE_ID, PRODUCT_ID, QUANTITY, REGION
FROM vw_L1_Billings B 
LEFT JOIN L4_vw_clientes_final C ON B.CUSTOMER_ID = C.CUSTOMER_ID;

-- 7.2 Muestra rápida del diccionario analítico de rangos
SELECT * FROM vw_rango_etario;

-- 7.3 Comprobación una factura con descuento y contexto demográfico
SELECT * FROM vw_L3_Billings_Contexto WHERE billing_id = 237022;
SELECT * FROM vw_L4_Fact_Billings_Final WHERE billing_id = 237022;