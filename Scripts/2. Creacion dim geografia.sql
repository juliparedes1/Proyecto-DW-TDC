Select * from stg_regions

-- Observamos que no haya errores por espacios o caracteres invisibles en las regiones, los estados y ciudades
Select Distinct r.Region from stg_regions r
Select distinct r.State from stg_regions r
Select distinct r.City from stg_regions r
-- todas las filas tienen codigos validos
select LEN(RTRIM(LTRIM(Zipcode))) FROM stg_regions WHERE LEN(RTRIM(LTRIM(Zipcode))) != 5

GO

CREATE VIEW vw_Geografia as 
	select * from stg_regions



