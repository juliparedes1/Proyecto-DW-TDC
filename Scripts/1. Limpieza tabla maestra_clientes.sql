--DATA PROFILING TABLA CLIENTES
GO 
CREATE VIEW vw_clientes AS 
    SELECT CUSTOMER_ID,
            FULL_NAME,
            BIRTH_DATE,
            CITY,
            STATE,
            ZIPCODE,
            TIPO_CLIENTE = 'Retail' FROM stg_customers_r
    UNION 
    SELECT CUSTOMER_ID,
            FULL_NAME,
            BIRTH_DATE,
            CITY,
            STATE,
            ZIPCODE,
            TIPO_CLIENTE = 'Wholesale' FROM stg_customers_w
GO 

SELECT * FROM vw_clientes

--COLUMNA PK
--verificamos que no haya pk duplicadas
SELECT CUSTOMER_ID, COUNT(*) FROM vw_clientes GROUP BY CUSTOMER_ID HAVING COUNT(*) != 1;

--Columna ciudad
-- verificamos que no haya valores nulos o espacios antes o despues de la ciudad
SELECT * FROM vw_clientes WHERE CITY IS NULL OR LTRIM(RTRIM(CAST(CITY AS VARCHAR))) = '';

--Columna Fecha_cumpleanios
-- verificamos si existen valores atipicos o errores logicos en las fechas
SELECT MIN(BIRTH_DATE), MAX(BIRTH_DATE) FROM vw_clientes ;
-- SELECT BIRTH_DATE FROM vw_clientes_fechas_limpias WHERE ISDATE(BIRTH_DATE) != 1

--Encontramos errores en las fechas, a partir de la creacion de la funcion f_limpiar_fechas, trycast e isnull corregimos los errores
GO 
CREATE VIEW vw_clientes_fechas_limpias_L2 AS (
	SELECT CUSTOMER_ID, 
    FULL_NAME, 
    ISNULL(TRY_CAST( dbo.f_limpiar_fechas(BIRTH_DATE) AS DATE), '1900-01-01') AS BIRTH_DATE, 
    CITY, 
    [STATE], 
    ZIPCODE,
    TIPO_CLIENTE
    FROM vw_clientes)
GO

select * from vw_clientes_fechas_limpias_L2

--Columna zipcode
-- verificamos que todos los zipcodes en la tabla de regiones contienen 5 como maximo por lo tanto un numero menos a 5 no representa un lugar
select distinct count(Zipcode) from stg_regions where LEN(LTRIM(RTRIM(ZIPCODE)))  = 5 
select distinct count(Zipcode) from stg_regions
select * from stg_regions

-- Limpiamos todos los zipcodes y a los invalidos los hemos eliminado
GO 
CREATE VIEW L3_vw_clientes_limpieza_zipcode AS (
SELECT 
    CUSTOMER_ID,
    FULL_NAME,
    BIRTH_DATE,
    CITY,
    STATE,
    CASE 
        WHEN LEN(LTRIM(RTRIM(ZIPCODE))) <> 5 
          OR LTRIM(RTRIM(ZIPCODE)) LIKE '%[^0-9]%' 
        THEN '00000'
        ELSE LTRIM(RTRIM(ZIPCODE)) 
    END AS ZIPCODE,
    TIPO_CLIENTE
FROM vw_clientes_fechas_limpias_L2);
GO

--Columna estados, ciudad y nombre_completo
GO 
CREATE VIEW L4_vw_clientes_final AS(
   SELECT CUSTOMER_ID, 
    FULL_NAME, 
    BIRTH_DATE, 
    ISNULL(UPPER(LTRIM(RTRIM(CITY))), 'SIN CIUDAD') AS CITY,
    ISNULL(UPPER(LTRIM(RTRIM([STATE]))), 'SIN ESTADO') AS [STATE], 
    ZIPCODE,
    TIPO_CLIENTE
    FROM L3_vw_clientes_limpieza_zipcode);
GO

--Los estados estan limpios
SELECT 
    STATE, 
    COUNT(*) as Cantidad_Clientes
FROM L3_vw_clientes_limpieza_zipcode
GROUP BY STATE
ORDER BY STATE;

--Las ciudades estan limpias
SELECT 
    CITY, 
    COUNT(*) as Cantidad_Clientes
FROM L3_vw_clientes_limpieza_zipcode
GROUP BY CITY
ORDER BY CITY;

--Los nombres estan limpios
SELECT 
    FULL_NAME, 
    COUNT(*) as Cantidad_Clientes
FROM L3_vw_clientes_limpieza_zipcode
GROUP BY FULL_NAME
ORDER BY FULL_NAME;

-- Busca nombres que NO tengan coma
SELECT 
    CUSTOMER_ID, 
    FULL_NAME
FROM L3_vw_clientes_limpieza_zipcode
WHERE CHARINDEX(',', FULL_NAME) = 0; 

-- Busca nombres que contenga numeros
SELECT 
    CUSTOMER_ID, 
    FULL_NAME
FROM L3_vw_clientes_limpieza_zipcode
WHERE FULL_NAME LIKE '%[0-9]%';

-- Busca nombres que tengan mas de un espacio
SELECT 
    CUSTOMER_ID, 
    FULL_NAME
FROM L3_vw_clientes_limpieza_zipcode
WHERE FULL_NAME LIKE '%  %';

--Concluimos que la columna nombres esta limpia
SELECT * FROM L4_vw_clientes_final