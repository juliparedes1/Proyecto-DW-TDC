-- Aseguramos que los textos estén en español
SET LANGUAGE Spanish;

-- Declaramos los límites del calendario
DECLARE @FechaActual DATE = '2000-01-01';
DECLARE @FechaFin DATE = '2030-12-31';

-- Llenado automático
WHILE @FechaActual <= @FechaFin
BEGIN
    INSERT INTO Dim_Calendario(
        sk_fecha, 
        dia, 
        mes, 
        año, 
        feriado, 
        nombre_dia, 
        nombre_mes, 
        semestre, 
        trimestre
    )
    VALUES (
        @FechaActual,
        DAY(@FechaActual),
        MONTH(@FechaActual),
        YEAR(@FechaActual),
        0, -- Dejamos los feriados en 0 por defecto
        DATENAME(WEEKDAY, @FechaActual),
        DATENAME(MONTH, @FechaActual),
        CASE WHEN MONTH(@FechaActual) <= 6 THEN 1 ELSE 2 END,
        DATEPART(QUARTER, @FechaActual)
    );

    -- Avanzamos un día para la próxima vuelta del bucle
    SET @FechaActual = DATEADD(DAY, 1, @FechaActual);
END;

-- Actualizamos la columna "feriado" poniéndola en 1 
UPDATE dt
SET dt.feriado = 1
FROM Dim_Calendario dt

-- Cruzamos con la tabla de feriados del 2005
INNER JOIN stg_holidays f
    ON DAY(dt.sk_fecha) = DAY(f.[Date])
   AND MONTH(dt.sk_fecha) = MONTH(f.[Date]);