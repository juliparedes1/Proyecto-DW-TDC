USE Staging_tdc;
GO

DROP TABLE IF EXISTS Fac_venta;
DROP TABLE IF EXISTS Fac_stock;
DROP TABLE IF EXISTS Dim_Calendario;
DROP TABLE IF EXISTS Dim_producto;
DROP TABLE IF EXISTS Dim_grupo_etario;
DROP TABLE IF EXISTS Dim_empleado;
DROP TABLE IF EXISTS Dim_cliente;
DROP TABLE IF EXISTS Dim_geografia;
GO



CREATE TABLE Dim_geografia (
                            sk_geografia INT PRIMARY KEY IDENTITY(10,1) NOT NULL,
							Codigo_postal VARCHAR(255),
							Ciudad VARCHAR(255),
							Estado VARCHAR(255),
							Region VARCHAR(255)
							);

CREATE TABLE Dim_cliente(
                         sk_cliente INT PRIMARY KEY IDENTITY(10,1) NOT NULL,
						 Id_cliente INT,
						 sk_geografia INT,
						 Nombre_cliente VARCHAR(255),
                         Tipo_cliente VARCHAR(255),
						 Fecha_nacimiento DATE,
						 FOREIGN KEY (sk_geografia) REFERENCES Dim_geografia(sk_geografia)
						 );

CREATE TABLE Dim_empleado(
                          sk_Empleado INT PRIMARY KEY IDENTITY(10,1) NOT NULL,
						  Id_empleado INT,
						  Nombre_empleado VARCHAR(255),
						  Genero VARCHAR(255),
						  Categoria VARCHAR(255),
                          Nivel_educativo VARCHAR(255),
						  Fecha_nacimiento DATE,
						  Fecha_ingreso DATE
						  );

CREATE TABLE Dim_grupo_etario(
                        sk_grupo_etario INT PRIMARY KEY NOT NULL,
						Edad_desde VARCHAR(255),
						Edad_hasta VARCHAR(255),
						Descripcion VARCHAR(255)
						);

CREATE TABLE Dim_producto (
                            sk_producto INT PRIMARY KEY IDENTITY(10,1) NOT NULL,
                            Id_producto INT,
                            Rubro VARCHAR(12),
                            Descripcion VARCHAR(50),
                            Envase VARCHAR(50),
                            Capacidad_litros NUMERIC(4,3),
                            Precio FLOAT,
                            Fecha_desde DATETIME,
                            Es_dietetico BIT
                            );

CREATE TABLE Dim_Calendario(

                            sk_fecha DATE PRIMARY KEY NOT NULL,
                            Dia TINYINT,
                            Mes TINYINT,
                            Trimestre TINYINT,
                            Semestre TINYINT,
                            Año SMALLINT,
                            Feriado BIT,
                            Nombre_dia VARCHAR(255),
                            Nombre_mes VARCHAR(255)
                            );

CREATE TABLE Fac_venta(
                       sk_venta_producto INT PRIMARY KEY IDENTITY(1,1) NOT NULL,
                       Nro_factura INT,
                       sk_empleado INT,
                       sk_grupo_etario INT,
                       sk_cliente INT,
                       sk_producto INT,
                       sk_fecha_venta DATE,
                       Region NVARCHAR(90),
                       Sistema_origen VARCHAR(255),
                       Edad_cliente NUMERIC(18,0),
                       Edad_empleado NUMERIC(18,0),
                       Antiguedad_empleado NUMERIC(18,0),
                       Litros_totales NUMERIC(15,3),
                       Precio_individual FLOAT,
                       Cantidad_producto INT,
                       Precio_final FLOAT,
                       Descuento FLOAT,
                       Precio_final_descuento FLOAT,
                       FOREIGN KEY (sk_empleado) REFERENCES Dim_empleado(sk_empleado),
                       FOREIGN KEY (sk_grupo_etario) REFERENCES Dim_grupo_etario(sk_grupo_etario),
                       FOREIGN KEY (sk_cliente) REFERENCES Dim_cliente(sk_cliente),
                       FOREIGN KEY (sk_producto) REFERENCES Dim_producto(sk_producto),
                       FOREIGN KEY (sk_fecha_venta) REFERENCES Dim_calendario(sk_fecha)
                       );

CREATE TABLE Fac_stock(
                       sk_stock INT PRIMARY KEY IDENTITY(1,1) NOT NULL,
                       id_producto INT,
                       Id_fecha_stock DATE,
                       Cantidad INT,
                       FOREIGN KEY(Id_producto) REFERENCES Dim_producto(sk_producto),
                       FOREIGN KEY(Id_fecha_stock) REFERENCES Dim_calendario(sk_fecha)
                       );
