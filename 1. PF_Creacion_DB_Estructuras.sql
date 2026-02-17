/************** Proyecto Final. Casa de Seguimiento y Tratamiento de Adicciones **************/
/*********************** Query 1. Creación de Base de Datos y Tablas ***********************/

/* CREATE DATABASE ProyectoFinal;
GO */

USE ProyectoFinal;
GO 

CREATE OR ALTER PROCEDURE sp_Creacion_Estructura_Proyecto_Final
AS 
BEGIN
	PRINT 'Creando estructura de TSE, Teléfonos y Proyecto Final...';

	/* Creación de Tablas Casa de Seguimiento y Tratamiento de Adicciones */

	CREATE TABLE tb_Persona
	(	
	id_Persona		INT IDENTITY (1,1) NOT NULL,
	nombre			VARCHAR (100) NOT NULL,
	primer_Apellido VARCHAR (100) NOT NULL,
	segundo_Apellido VARCHAR (100),
	identificacion	VARCHAR (20) NOT NULL,
	fecha_Nacimiento DATE NOT NULL,
	sexo			CHAR (1),
	direccion		VARCHAR (255) NOT NULL,
	telefono		VARCHAR (20) NOT NULL,
	correo			VARCHAR (100) NOT NULL,
	fecha_Registro	DATETIME2 DEFAULT SYSDATETIME(),
	CONSTRAINT PK_tb_Persona PRIMARY KEY (id_Persona), 
	CONSTRAINT UQ_tb_Persona_identificacion UNIQUE (identificacion)
	);

	CREATE TABLE tb_Cargo
	(
	id_Cargo		INT IDENTITY (1,1) NOT NULL,
	nombre_Cargo	VARCHAR (100) NOT NULL,
	descripcion		VARCHAR (2000),
	fecha_Registro	DATETIME2 DEFAULT SYSDATETIME(),
	CONSTRAINT PK_tb_Cargo PRIMARY KEY (id_Cargo) 
	);

	CREATE TABLE tb_Empleado
	(
	id_Empleado		INT IDENTITY (1,1) NOT NULL,
	id_Persona		INT NOT NULL,
	id_Cargo		INT NOT NULL,
	fecha_Ingreso	DATE NOT NULL,
	salario_Mensual	DECIMAL (10,2) NOT NULL,
	estado			VARCHAR (50) NOT NULL,
	fecha_Registro	DATETIME2 DEFAULT SYSDATETIME(),
	CONSTRAINT PK_tb_Empleado PRIMARY KEY (id_Empleado),
	CONSTRAINT FK_tb_Empleado_Persona FOREIGN KEY (id_Persona)
	REFERENCES tb_Persona (id_Persona),
	CONSTRAINT FK_tb_Empleado_Cargo FOREIGN KEY (id_Cargo)
	REFERENCES tb_Cargo (id_Cargo)
	);

	CREATE TABLE tb_Fase_Tratamiento
	(
	id_Fase			INT IDENTITY (1,1) NOT NULL,
	nombre_Fase		VARCHAR (100) NOT NULL,
	descripcion		VARCHAR (2000),
	fecha_Registro	DATETIME2 DEFAULT SYSDATETIME(),
	CONSTRAINT PK_tb_Fase_Tratamiento PRIMARY KEY (id_Fase)
	);

	CREATE TABLE tb_Paciente
	(
	id_Paciente		INT IDENTITY (1,1) NOT NULL,
	id_Persona		INT NOT NULL,
	fecha_Ingreso	DATE NOT NULL,
	estado			VARCHAR (50) NOT NULL,
	observaciones	VARCHAR (2000),
	fecha_Registro	DATETIME2 DEFAULT SYSDATETIME(),
	CONSTRAINT PK_tb_Paciente PRIMARY KEY (id_Paciente),
	CONSTRAINT FK_tb_Paciente_Persona FOREIGN KEY (id_Persona)
	REFERENCES tb_Persona (id_Persona)
	);

	CREATE TABLE tb_Paciente_Fase
	(
	id_Paciente_Fase	INT IDENTITY (1,1) NOT NULL,
	id_Paciente			INT NOT NULL,
	id_Fase				INT NOT NULL,
	fecha_Inicio		DATE NOT NULL,
	fecha_Fin			DATE,
	estado				VARCHAR (50) NOT NULL,
	observaciones		VARCHAR (2000),
	fecha_Registro	DATETIME2 DEFAULT SYSDATETIME(),
	CONSTRAINT PK_tb_Paciente_Fase PRIMARY KEY (id_Paciente_Fase),
	CONSTRAINT FK_tb_Paciente_Fase_Paciente FOREIGN KEY (id_Paciente)
	REFERENCES tb_Paciente (id_Paciente),
	CONSTRAINT FK_tb_Paciente_Fase_Fase FOREIGN KEY (id_Fase)
	REFERENCES tb_Fase_Tratamiento (id_Fase)
	);

	CREATE TABLE tb_Diagnostico_CIE10
	(
	id_Diagnostico	INT IDENTITY (1,1) NOT NULL,
	codigo_CIE10	VARCHAR(10) NOT NULL,
	nombre_Diagnostico	VARCHAR(100) NOT NULL,
	descripcion		VARCHAR (255),
	fecha_Registro	DATETIME2 DEFAULT SYSDATETIME(),
	CONSTRAINT PK_tb_Diagnostico_CIE10 PRIMARY KEY (id_Diagnostico)
	);

	CREATE TABLE tb_Paciente_Diagnostico
	(
	id_Paciente			INT NOT NULL,
	id_Diagnostico		INT NOT NULL,
	id_Empleado			INT NOT NULL,
	fecha_Diagnostico	DATE NOT NULL,
	observaciones		VARCHAR (2000),
	fecha_Registro	DATETIME2 DEFAULT SYSDATETIME(),
	CONSTRAINT PK_tb_Paciente_Diagnostico PRIMARY KEY (id_Paciente, id_Diagnostico, id_Empleado),
	CONSTRAINT FK_tb_Paciente_Diagnostico_Paciente FOREIGN KEY (id_Paciente)
	REFERENCES tb_Paciente (id_Paciente),
	CONSTRAINT FK_tb_Paciente_Diagnostico_Diagnostico FOREIGN KEY (id_Diagnostico)
	REFERENCES tb_Diagnostico_CIE10 (id_Diagnostico),
	CONSTRAINT FK_tb_Paciente_Diagnostico_Empleado FOREIGN KEY (id_Empleado)
	REFERENCES tb_Empleado (id_Empleado)
	);

	CREATE TABLE tb_Medicamento
	(
	id_Medicamento		INT IDENTITY (1,1) NOT NULL,
	nombre_Comercial	VARCHAR (100) NOT NULL,
	nombre_Prospecto	VARCHAR (150) NOT NULL,
	presentacion		VARCHAR (50) NOT NULL,
	dosis				VARCHAR (50) NOT NULL,
	via_Administracion	VARCHAR (50) NOT NULL,
	efectos_Secundarios	VARCHAR (2000),
	Contraindicaciones	VARCHAR (2000),
	fecha_Registro	DATETIME2 DEFAULT SYSDATETIME(),
	CONSTRAINT PK_tb_Medicamento PRIMARY KEY (id_Medicamento)
	);

	CREATE TABLE tb_Actividad
	(
	id_Actividad	INT IDENTITY (1,1) NOT NULL,
	tipo			VARCHAR (50) NOT NULL,
	subtipo			VARCHAR (100) NOT NULL,
	nombre			VARCHAR (150) NOT NULL,
	fecha			DATE NOT NULL,
	lugar			VARCHAR (150),
	descripcion		VARCHAR (2000),
	id_Empleado		INT NOT NULL,
	fecha_Registro	DATETIME2 DEFAULT SYSDATETIME(),
	CONSTRAINT PK_tb_Actividad PRIMARY KEY (id_Actividad),
	CONSTRAINT FK_tb_Actividad_Empleado	FOREIGN KEY (id_Empleado)
	REFERENCES tb_Empleado (id_Empleado)
	);

	CREATE TABLE tb_Paciente_Actividad
	(
	id_Paciente		INT NOT NULL,
	id_Actividad	INT NOT NULL,
	id_Fase			INT NOT NULL,
	fecha_Inicio	DATE NOT NULL, 
	fecha_Fin		DATE,
	estado			VARCHAR (50) NOT NULL,
	observaciones	VARCHAR (2000),
	fecha_Registro	DATETIME2 DEFAULT SYSDATETIME(),
	CONSTRAINT PK_tb_Paciente_Actividad PRIMARY KEY (id_Paciente, id_Actividad),
	CONSTRAINT FK_tb_Paciente_Actividad_Paciente FOREIGN KEY (id_Paciente)
	REFERENCES tb_Paciente (id_Paciente),
	CONSTRAINT FK_tb_Paciente_Actividad_Actividad FOREIGN KEY (id_Actividad)
	REFERENCES tb_Actividad (id_Actividad),
	CONSTRAINT FK_tb_Paciente_Actividad_Fase FOREIGN KEY (id_Fase)
	REFERENCES tb_Fase_Tratamiento (id_Fase)
	);

	CREATE TABLE tb_Paciente_Actividad_Medicamento
	(
	id_Paciente		INT NOT NULL,
	id_Actividad	INT NOT NULL,
	id_Medicamento	INT NOT NULL,
	dosis			VARCHAR (50) NOT NULL,
	frecuencia		VARCHAR (50) NOT NULL,
	duracion		VARCHAR (50) NOT NULL,
	observaciones	VARCHAR (2000),
	fecha_Registro	DATETIME2 DEFAULT SYSDATETIME(),
	CONSTRAINT PK_tb_Paciente_Actividad_Medicamento PRIMARY KEY (id_Paciente, id_Actividad, id_Medicamento),
	CONSTRAINT FK_tb_Paciente_Actividad_Medicamento_Paciente FOREIGN KEY (id_Paciente)
	REFERENCES tb_Paciente (id_Paciente),
	CONSTRAINT FK_tb_Paciente_Actividad_Medicamento_Actividad FOREIGN KEY (id_Actividad)
	REFERENCES tb_Actividad (id_Actividad),
	CONSTRAINT FK_tb_Paciente_Actividad_Medicamento_Medicamento FOREIGN KEY (id_Medicamento)
	REFERENCES tb_Medicamento (id_Medicamento)
	);

	CREATE TABLE tb_Persona_Actividad
	(
	id_Persona		INT NOT NULL,
	id_Actividad	INT NOT NULL,
	rol				VARCHAR (50) NOT NULL,
	observaciones	VARCHAR (2000),
	fecha_Registro	DATETIME2 DEFAULT SYSDATETIME(),
	CONSTRAINT PK_tb_Persona_Actividad PRIMARY KEY (id_Persona,id_Actividad),
	CONSTRAINT FK_tb_Persona_Actividad_Persona FOREIGN KEY (id_Persona)
	REFERENCES tb_Persona (id_Persona),
	CONSTRAINT FK_tb_Persona_Actividad_Actividad FOREIGN KEY (id_Actividad)
	REFERENCES tb_Actividad (id_Actividad)
	);

	/* Creación de Tablas TSE normalizado */

	CREATE TABLE tb_Provincia
	(
	id_Provincia INT IDENTITY (1,1)
	,Provincia VARCHAR (20) NOT NULL
	CONSTRAINT PK_id_Provincia PRIMARY KEY (id_Provincia)
	);

	CREATE TABLE tb_Provincia_Canton
	(
	id_Canton INT IDENTITY (1,1)
	,id_Provincia INT NOT NULL
	,Canton VARCHAR (100) NOT NULL 
	CONSTRAINT PF_id_Canton PRIMARY KEY (id_Canton)
	,CONSTRAINT FK_id_Provincia_Canton FOREIGN KEY (id_Provincia)
	REFERENCES tb_Provincia (id_Provincia)
	,CONSTRAINT UQ_Provincia_Canton UNIQUE (id_Provincia,Canton)
	);

	CREATE TABLE tb_Provincia_Canton_Distrito
	(
	id_Distrito INT IDENTITY (1,1)
	,id_Canton INT NOT NULL
	,Distrito VARCHAR (100) NOT NULL 
	,cod_Electoral INT NOT NULL
	CONSTRAINT PF_id_Distrito PRIMARY KEY (id_Distrito)
	,CONSTRAINT FK_id_Provincia_Canton_Distrito FOREIGN KEY (id_Canton)
	REFERENCES tb_Provincia_Canton (id_Canton)
	);

	CREATE TABLE tb_Votante
	(
	id_Votante INT IDENTITY (1,1)
	,Cedula INT UNIQUE NOT NULL
	,Nombre VARCHAR (100) NOT NULL
	,Apellido1 VARCHAR (100) NOT NULL
	,Apellido2 VARCHAR (100)
	,Vencimiento_Cedula DATE NOT NULL
	,id_Distrito INT NOT NULL
	CONSTRAINT PK_id_Votante PRIMARY KEY (id_Votante)
	,CONSTRAINT FK_id_Votante_Distrito FOREIGN KEY (id_Distrito)
	REFERENCES tb_Provincia_Canton_Distrito (id_Distrito)
	);

	CREATE TABLE tb_Junta
	(
	id_Junta INT IDENTITY (1,1)
	,numero_Junta INT NOT NULL
	,id_Distrito INT NOT NULL
	CONSTRAINT PK_id_Junta PRIMARY KEY (id_Junta)
	,CONSTRAINT FK_id_Junta_Distrito FOREIGN KEY (id_Distrito)
	REFERENCES tb_Provincia_Canton_Distrito (id_Distrito)
	,CONSTRAINT UQ_Junta_Distrito UNIQUE (id_Distrito,numero_Junta)
	);

	CREATE TABLE tb_Votante_Junta
	(
	id_Votante_Junta INT IDENTITY (1,1)
	,id_Junta INT NOT NULL
	,id_Votante INT NOT NULL
	CONSTRAINT PK_Votante_Junta PRIMARY KEY (id_Votante_Junta)
	,CONSTRAINT FK_id_Votante_Junta_Junta FOREIGN KEY (id_Junta)
	REFERENCES tb_Junta (id_Junta)
	,CONSTRAINT FK_id_Votante_Junta_Votante FOREIGN KEY (id_Votante)
	REFERENCES  tb_Votante (id_Votante)
	);

	/* Creación de Tablas Telefonos General y Telefonos General Versión 2 */

	CREATE TABLE dbo.Telefonos_General 
	(
    Telefono INT,
    Cedula INT,
    Nombre_Cliente NVARCHAR (100)
	);

	CREATE TABLE dbo.Telefonos_General_V2 
	(
    Cedula INT,
    Nombre_Cliente NVARCHAR (100),
    Cantidad_Telefonos INT,
    Telefonos NVARCHAR(MAX)
	);

	/* Creación de Tablas Para Cargar DistElec y Padron Completo y Utilizar los Datos */

	CREATE TABLE TSE_DistElec_Base 
	(
    CODELEC INT,
    Provincia VARCHAR(50),
    Canton VARCHAR(100),
    Distrito VARCHAR(100)
	);

	CREATE TABLE TSE_Padron_Base 
	(
    Cedula INT,
    Codelec INT,
    Relleno CHAR(1),
    Fecha_Caducidad CHAR(8),
    Junta INT,
    Nombre VARCHAR(100),
    Apellido1 VARCHAR(100),
    Apellido2 VARCHAR(100)
	);

	/* Creación de Tablas Para Utilizar Triggers */
	CREATE TABLE tb_Log_Acciones 
	(
    id_Log INT IDENTITY PRIMARY KEY,
    usuario NVARCHAR(100),
    accion NVARCHAR(20),
    tabla NVARCHAR(50),
    fecha DATETIME2 DEFAULT SYSDATETIME()
	);

	PRINT 'Estructura creada correctamente.';
END;
GO

/* Ejecuta procedimiento almacenado */

EXEC sp_Creacion_Estructura_Proyecto_Final
