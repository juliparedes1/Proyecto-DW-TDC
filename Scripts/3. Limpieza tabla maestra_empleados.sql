--Tabla empleados
select * from stg_employee

-- Eliminamos los nulos
delete from stg_employee where EMPLOYEE_ID is null	

-- analizamos si todas las PK son unicas
SELECT  COUNT(EMPLOYEE_ID) FROM stg_employee GROUP BY EMPLOYEE_ID HAVING COUNT(EMPLOYEE_ID) != 1

-- Con esto podemos analizar que no hay espacios en blanco que puedan causar duplicados erroneos en el nombre, el nivel de educacion y la categoria
SELECT 
    EMPLOYEE_ID, 
    FULL_NAME, 
    CATEGORY, 
    EDUCATION_LEVEL
FROM stg_employee 
WHERE 
    FULL_NAME LIKE ' %' OR FULL_NAME LIKE '% ' OR FULL_NAME LIKE '%  %' OR
    CATEGORY LIKE ' %' OR CATEGORY LIKE '% ' OR CATEGORY LIKE '%  %' OR
    EDUCATION_LEVEL LIKE ' %' OR EDUCATION_LEVEL LIKE '% ' OR EDUCATION_LEVEL LIKE '%  %';


-- Verificamos que cada uno de las fechas de los empleados sean validas
SELECT EMPLOYEE_ID, EMPLOYMENT_DATE, BIRTH_DATE FROM stg_employee WHERE ISDATE(EMPLOYMENT_DATE)  != 1 OR ISDATE(BIRTH_DATE) != 1

-- observamos cuales son los generos
select DISTINCT GENDER from stg_employee 

-- Actualización de la vista maestra de empleados 

GO

DROP VIEW IF EXISTS vw_maestra_empleados;
GO

CREATE VIEW vw_maestra_empleados AS
   SELECT 
   CAST(EMPLOYEE_ID AS INT) AS EMPLOYEE_ID,
   FULL_NAME,
   CATEGORY,
   CAST(EMPLOYMENT_DATE AS DATE) AS EMPLOYMENT_DATE,
   CAST(BIRTH_DATE AS DATE) AS BIRTH_DATE,
   EDUCATION_LEVEL,
   GENDER
   FROM stg_employee;