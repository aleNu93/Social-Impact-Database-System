/************** Proyecto Final. Casa de Seguimiento y Tratamiento de Adicciones **************/
/*********************** Query 3. Consultas, Views y Triggers ***********************/


/* Conexión entre TSE y Teléfonos */

SELECT 
      v.Cedula,
      v.Nombre,
      v.Apellido1,
      v.Apellido2,
      t.Telefono
FROM dbo.tb_Votante v
INNER JOIN dbo.Telefonos_General t
      ON v.Cedula = t.Cedula;

SELECT 
    v.Cedula,
    v.Nombre,
    v.Apellido1,
    v.Apellido2,
    p.Provincia,
    c.Canton,
    d.Distrito,
    t.Telefono
FROM dbo.tb_Votante v
INNER JOIN dbo.tb_Provincia_Canton_Distrito d ON v.id_Distrito = d.id_Distrito
INNER JOIN dbo.tb_Provincia_Canton c ON d.id_Canton = c.id_Canton
INNER JOIN dbo.tb_Provincia p ON c.id_Provincia = p.id_Provincia
INNER JOIN dbo.Telefonos_General t ON v.Cedula = t.Cedula;

/* TRIGGERS */

/* 1. Trigger que bloquea inserciones en alguna tabla */
CREATE OR ALTER TRIGGER trg_NoInsert_Paciente
ON dbo.tb_Paciente
AFTER INSERT
AS
BEGIN
    RAISERROR('No se permiten INSERT directos en tb_Paciente. Use el procedimiento almacenado.',16,1);
    ROLLBACK TRANSACTION;
END;
GO

/* 2. Trigger que registra UPDATE/DELETE en tb_Log_Acciones */
CREATE OR ALTER TRIGGER trg_Log_Paciente
ON dbo.tb_Paciente
AFTER DELETE, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @usuario NVARCHAR(100);
    DECLARE @accion NVARCHAR(20);

    SELECT @usuario = login_name
    FROM sys.dm_exec_sessions
    WHERE session_id = @@SPID;

    IF EXISTS (SELECT * FROM inserted) AND EXISTS (SELECT * FROM deleted)
        SET @accion = 'UPDATE';
    ELSE IF EXISTS (SELECT * FROM deleted)
        SET @accion = 'DELETE';
    
    INSERT INTO dbo.tb_Log_Acciones (usuario, accion, tabla)
    VALUES (@usuario, @accion, 'tb_Paciente');
END;
GO

/* VIEW */
/*  Personas del TSE que vivan en Cartago y tengan al menos un teléfono */

CREATE OR ALTER VIEW dbo.Visualizar_Consulta
AS
SELECT 
    v.Cedula,
    v.Nombre,
    v.Apellido1,
    v.Apellido2,
    p.Provincia,
    c.Canton,
    d.Distrito,
    t.Telefono
FROM dbo.tb_Votante v
INNER JOIN dbo.tb_Provincia_Canton_Distrito d
    ON v.id_Distrito = d.id_Distrito
INNER JOIN dbo.tb_Provincia_Canton c
    ON d.id_Canton = c.id_Canton
INNER JOIN dbo.tb_Provincia p
    ON c.id_Provincia = p.id_Provincia
INNER JOIN dbo.Telefonos_General t
    ON v.Cedula = t.Cedula
WHERE p.Provincia = 'Cartago'
  AND t.Telefono >= 1;
GO

SELECT * FROM dbo.Visualizar_Consulta



