

CREATE FUNCTION f_limpiar_fechas (@TextoFecha VARCHAR(100))
RETURNS VARCHAR(100)
AS
BEGIN
    -- Mientras encuentre un carácter que NO sea un número del 0 al 9, ni un guion o slash 
    WHILE PATINDEX('%[^0-9/-]%', @TextoFecha) > 0
    BEGIN
        -- Reemplaza ese carácter extraño por 'nada' (lo elimina)
        SET @TextoFecha = STUFF(@TextoFecha, PATINDEX('%[^0-9/-]%', @TextoFecha), 1, '')
    END
    
    RETURN @TextoFecha
END;