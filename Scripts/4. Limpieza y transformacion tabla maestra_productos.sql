--Transformacion de la tabla de productos

SELECT TOP 5 * FROM stg_products;

DROP VIEW IF EXISTS vw_Productos;
GO

CREATE VIEW vw_Productos AS
SELECT 
    Id_producto,
    Rubro,
    Volume,
    CASE 
        WHEN LOWER(Rubro) LIKE '%cola%' THEN 'Cola'
        WHEN LOWER(Rubro) LIKE '%beer%' THEN 'Beer'
        WHEN LOWER(Rubro) LIKE '%soda%' THEN 'Soda'
        WHEN LOWER(Rubro) LIKE '%juice%' THEN 'Juice'
        WHEN LOWER(Rubro) LIKE '%energy drink%' THEN 'Energy drink'
        ELSE Rubro
    END AS Rubro_Limpio,
    CASE 
        WHEN LOWER(Rubro) LIKE '%diet%' THEN 1 ELSE 0 
    END AS es_dietetico,
    CASE 
        WHEN LOWER(Volume) LIKE '%1 liter%' THEN 1
        WHEN LOWER(Volume) LIKE '%2 liter%' THEN 2
        WHEN LOWER(Volume) LIKE '%330%' THEN 0.330
        WHEN LOWER(Volume) LIKE '%500%' THEN 0.5
        WHEN LOWER(Volume) LIKE '%670%' THEN 0.670
        ELSE 0
    END AS Capacidad_en_Litros
FROM stg_products; -- Sin paréntesis al final, solo punto y coma
GO


DROP VIEW IF EXISTS vw_Maestra_Productos;
GO

CREATE VIEW vw_Maestra_Productos AS
SELECT 
    PBN.PRODUCT_ID,
    PBN.PRICE,
    PBN.DATE,
    VP.Capacidad_en_Litros,
    VP.Rubro,               -- Dejamos Rubro una sola vez acá
    VP.Volume,
    CAST(VP.es_dietetico AS BIT) AS es_dietetico
FROM stg_prices PBN 
LEFT JOIN vw_Productos VP ON PBN.PRODUCT_ID = VP.Id_producto;
GO