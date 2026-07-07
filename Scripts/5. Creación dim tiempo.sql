-- Creamos la estructura de la tabla calendario
CREATE TABLE Dim_Tiempo (
    fecha DATE PRIMARY KEY, 
    dia TINYINT,
    mes TINYINT,
    año SMALLINT,
    feriado BIT,
    nombre_dia VARCHAR(255),
    nombre_mes VARCHAR(255),
    semestre TINYINT,
    trimestre TINYINT
);
