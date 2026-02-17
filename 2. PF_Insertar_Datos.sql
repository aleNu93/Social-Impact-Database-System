/************** Proyecto Final. Casa de Seguimiento y Tratamiento de Adicciones **************/
/*********************** Query 2. Insertar y Cargar Datos ***********************/

USE ProyectoFinal;
GO

/* Carga los Datos de DISTELEC.TXT a TSE_DistElec_Base */

CREATE OR ALTER PROCEDURE dbo.sp_Cargar_DistElec_Base
AS
BEGIN
    PRINT 'Iniciando carga de DISTELEC.TXT...';

    TRUNCATE TABLE dbo.TSE_DistElec_Base;

    DECLARE @data NVARCHAR(MAX);

    SELECT @data = BulkColumn
    FROM OPENROWSET(
        BULK 'C:\Users\jans8\Desktop\SQL\Lenguaje de Consulta de Base de Datos. V Cuatrimestre\padron_completo (1)\distelec.txt',
        SINGLE_CLOB
    ) AS RAWDATA;

    ;WITH lineas AS (
        SELECT value AS linea
        FROM STRING_SPLIT(@data, CHAR(10))
        WHERE value <> ''
    ),
    parsed AS (
        SELECT 
            TRY_CAST(PARSENAME(REPLACE(linea, ',', '.'), 4) AS INT) AS CODELEC,
            LTRIM(RTRIM(PARSENAME(REPLACE(linea, ',', '.'), 3))) AS Provincia,
            LTRIM(RTRIM(PARSENAME(REPLACE(linea, ',', '.'), 2))) AS Canton,
            LTRIM(RTRIM(PARSENAME(REPLACE(linea, ',', '.'), 1))) AS Distrito
        FROM lineas
    )
    INSERT INTO dbo.TSE_DistElec_Base (CODELEC, Provincia, Canton, Distrito)
    SELECT CODELEC, Provincia, Canton, Distrito
    FROM parsed
    WHERE CODELEC IS NOT NULL;

    PRINT 'DISTELEC.TXT cargado exitosamente.';
END;
GO

/* Carga los Datos de PADRON_COMPLETO.TXT a TSE_DistElec_Base */

CREATE OR ALTER PROCEDURE dbo.sp_Cargar_Padron_Base 
AS 
BEGIN 
    PRINT 'Iniciando carga de PADRON_COMPLETO.TXT en tabla base...'; 

    TRUNCATE TABLE dbo.TSE_Padron_Base; 

    BULK INSERT dbo.TSE_Padron_Base 
    FROM 'C:\Users\jans8\Desktop\SQL\Lenguaje de Consulta de Base de Datos. V Cuatrimestre\padron_completo (1)\PADRON_COMPLETO.txt'
    WITH (
        FIELDTERMINATOR = ',',   
        ROWTERMINATOR = '\n',    
        FIRSTROW = 1, 
        CODEPAGE='65001',
        TABLOCK
    ); 

    PRINT 'PADRON_COMPLETO.TXT cargado exitosamente en TSE_Padron_Base.'; 
END;
GO

/* Carga los Datos a las Tablas del TSE Normalizado */
GO
CREATE OR ALTER PROCEDURE dbo.sp_Normalizar_TSE
AS
BEGIN
    PRINT 'Iniciando normalización del TSE...';

    ----------------------------------------------------------
    -- 2) Insertar Provincias
    ----------------------------------------------------------
    INSERT INTO dbo.tb_Provincia (Provincia)
    SELECT DISTINCT LTRIM(RTRIM(Provincia))
    FROM dbo.TSE_DistElec_Base;

    ----------------------------------------------------------
    -- 3) Insertar Cantones
    ----------------------------------------------------------
    INSERT INTO dbo.tb_Provincia_Canton (id_Provincia, Canton)
    SELECT DISTINCT 
        p.id_Provincia,
        LTRIM(RTRIM(d.Canton))
    FROM dbo.TSE_DistElec_Base d
    INNER JOIN dbo.tb_Provincia p
        ON p.Provincia = LTRIM(RTRIM(d.Provincia));

    ----------------------------------------------------------
    -- 4) Insertar Distritos
    ----------------------------------------------------------
    INSERT INTO dbo.tb_Provincia_Canton_Distrito (id_Canton, Distrito, cod_Electoral)
    SELECT DISTINCT 
        c.id_Canton,
        LTRIM(RTRIM(d.Distrito)),
        TRY_CAST(d.CODELEC AS INT)
    FROM dbo.TSE_DistElec_Base d
    INNER JOIN dbo.tb_Provincia_Canton c
        ON c.Canton = LTRIM(RTRIM(d.Canton))
       AND c.id_Provincia = (
            SELECT id_Provincia 
            FROM dbo.tb_Provincia 
            WHERE Provincia = LTRIM(RTRIM(d.Provincia))
       );

    ----------------------------------------------------------
    -- 5) Insertar Votantes
    ----------------------------------------------------------
    INSERT INTO dbo.tb_Votante (Cedula, Nombre, Apellido1, Apellido2, Vencimiento_Cedula, id_Distrito)
    SELECT DISTINCT
        b.Cedula,
        LTRIM(RTRIM(b.Nombre)),
        LTRIM(RTRIM(b.Apellido1)),
        LTRIM(RTRIM(b.Apellido2)),
        CONVERT(DATE, b.Fecha_Caducidad),
        d.id_Distrito
    FROM dbo.TSE_Padron_Base b
    INNER JOIN dbo.tb_Provincia_Canton_Distrito d
        ON d.cod_Electoral = b.Codelec;

    ----------------------------------------------------------
    -- 6) Insertar Juntas Receptoras (evitar 00000)
    ----------------------------------------------------------
    INSERT INTO dbo.tb_Junta (numero_Junta, id_Distrito)
    SELECT DISTINCT 
        TRY_CAST(NULLIF(b.Junta,'00000') AS INT),
        d.id_Distrito
    FROM dbo.TSE_Padron_Base b
    INNER JOIN dbo.tb_Provincia_Canton_Distrito d
        ON d.cod_Electoral = b.Codelec
    WHERE NULLIF(b.Junta,'00000') IS NOT NULL;

    ----------------------------------------------------------
    -- 7) Relación Votante — Junta
    ----------------------------------------------------------
    INSERT INTO dbo.tb_Votante_Junta (id_Junta, id_Votante)
    SELECT DISTINCT 
        j.id_Junta,
        v.id_Votante
    FROM dbo.TSE_Padron_Base b
    INNER JOIN dbo.tb_Junta j 
        ON j.numero_Junta = TRY_CAST(NULLIF(b.Junta,'00000') AS INT)
    INNER JOIN dbo.tb_Votante v 
        ON v.Cedula = b.Cedula;

    PRINT 'Normalización del TSE completada exitosamente.';
END;
GO

/* Carga los Datos a las Tablas Telefonos_General */

CREATE OR ALTER PROCEDURE sp_Cargar_Telefonos_General
AS
BEGIN
    SET NOCOUNT ON;
    PRINT 'Iniciando carga de Telefonos a Telefonos_General ...';

    -----------------------------------------------------------
    -- 1) Limpiar tabla base
    -----------------------------------------------------------
    TRUNCATE TABLE dbo.Telefonos_General;

    -----------------------------------------------------------
    -- 2) Cargar archivos phonesX.txt
    -----------------------------------------------------------
    BULK INSERT dbo.Telefonos_General
    FROM 'C:\Users\jans8\Desktop\ULACIT\V cuatrimestre\Lenguaje de Consulta de Base de Datos\Trabajo Final\phones1.txt'
    WITH (FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', FIRSTROW = 2);

    BULK INSERT dbo.Telefonos_General
    FROM 'C:\Users\jans8\Desktop\ULACIT\V cuatrimestre\Lenguaje de Consulta de Base de Datos\Trabajo Final\phones2.txt'
    WITH (FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', FIRSTROW = 2);

    BULK INSERT dbo.Telefonos_General
    FROM 'C:\Users\jans8\Desktop\ULACIT\V cuatrimestre\Lenguaje de Consulta de Base de Datos\Trabajo Final\phones3.txt'
    WITH (FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', FIRSTROW = 2);

    BULK INSERT dbo.Telefonos_General
    FROM 'C:\Users\jans8\Desktop\ULACIT\V cuatrimestre\Lenguaje de Consulta de Base de Datos\Trabajo Final\phones4.txt'
    WITH (FIELDTERMINATOR = '\t', ROWTERMINATOR = '\n', FIRSTROW = 2);

    PRINT 'Archivos de teléfonos cargados. Procesando...';

END;
GO


/* Carga los Datos a la Tabla Telefonos_General_V2 con Cursores */

CREATE OR ALTER PROCEDURE sp_Cargar_Telefonos_General_V2_Cursor
AS
BEGIN
    SET NOCOUNT ON;
    PRINT 'Iniciando carga de Telefonos a Telefonos_General_V2 ...';

    -- Limpiar la tabla destino
    TRUNCATE TABLE dbo.Telefonos_General_V2;

    DECLARE @Cedula INT;
    DECLARE @Nombre_Cliente NVARCHAR(100);
    DECLARE @Telefono NVARCHAR(50);
    DECLARE @Cantidad_Telefonos INT;
    DECLARE @Telefonos NVARCHAR(MAX);

    DECLARE curPersonas CURSOR FOR 
        SELECT Cedula, Nombre_Cliente 
        FROM dbo.Telefonos_General
        GROUP BY Cedula, Nombre_Cliente;

    OPEN curPersonas;
    FETCH NEXT FROM curPersonas INTO @Cedula, @Nombre_Cliente;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @Telefonos = '';
        SET @Cantidad_Telefonos = 0;

        DECLARE curTelefonos CURSOR FOR
            SELECT DISTINCT Telefonos_General.Telefono
            FROM dbo.Telefonos_General
            WHERE Cedula = @Cedula;

        OPEN curTelefonos;
        FETCH NEXT FROM curTelefonos INTO @Telefono;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @Telefonos = ''
                SET @Telefonos = @Telefono;
            ELSE
                SET @Telefonos = @Telefonos + ', ' + @Telefono;

            SET @Cantidad_Telefonos = @Cantidad_Telefonos + 1;

            FETCH NEXT FROM curTelefonos INTO @Telefono;
        END

        CLOSE curTelefonos;
        DEALLOCATE curTelefonos;

        INSERT INTO dbo.Telefonos_General_V2 (Cedula, Nombre_Cliente, Cantidad_Telefonos, Telefonos)
        VALUES (@Cedula, @Nombre_Cliente, @Cantidad_Telefonos, @Telefonos);

        FETCH NEXT FROM curPersonas INTO @Cedula, @Nombre_Cliente;
    END

    CLOSE curPersonas;
    DEALLOCATE curPersonas;

    PRINT 'Proceso con CURSOR finalizado correctamente.';
END;
GO

/* Carga los Datos a las Tablas de Casa de Seguimiento y Tratamiento de Adicciones */
CREATE OR ALTER PROCEDURE sp_Insertar_Datos_Proyecto
AS
BEGIN
    SET NOCOUNT ON;
    PRINT 'Insertando datos del Proyecto HOMACE...';

    INSERT INTO tb_Persona (nombre, primer_Apellido, segundo_Apellido, identificacion, fecha_Nacimiento, sexo, direccion, telefono, correo) VALUES
    ('Lucila', 'Porras', 'Aguero', '101053316', '2017-03-04', 'M', 'San Francisco, Calle 29, Moravia, San José, Costa Rica. Casa 36', '+506 28196001', 'lucilaporras.316@ejemplo.cr'),
    ('Dinora', 'Obando', 'Garcia', '101086526', '2012-06-14', 'M', 'Centro, Avenida 23, Carrillo, Guanacaste, Costa Rica. Casa 51', '+506 46379402', 'dinoraobando.526@ejemplo.cr'),
    ('Trinidad', 'Vindas', 'Perez', '101141655', '2017-10-30', 'F', 'Los Ángeles, Calle 28, La Unión, Cartago, Costa Rica. Casa 196', '+506 71161559', 'trinidadvindas.655@ejemplo.cr'),
    ('Ana Maria', 'Perez', 'Perez', '101240037', '2012-12-19', 'M', 'San Miguel, Calle 16, Montes de Oro, Puntarenas, Costa Rica. Casa 97', '+506 28495931', 'anaperez.037@ejemplo.cr'),
    ('German', 'Carvajal', 'Bermudez', '101280947', '2010-07-07', 'M', 'San Martín, Calle 30, Siquirres, Limón, Costa Rica. Casa 26', '+506 84752553', 'germancarvajal.947@ejemplo.cr'),
    ('Jose Vicente', 'Acuña', 'Acuña', '101290149', '2017-07-08', 'F', 'San Martín, Avenida 29, Golfito, Puntarenas, Costa Rica. Casa 163', '+506 68327648', 'joseacua.149@ejemplo.cr'),
    ('Benitivo', 'Arias', 'Campos', '101290354', '2012-06-18', 'F', 'San Francisco, Calle 5, Limón, Limón, Costa Rica. Casa 81', '+506 84139537', 'benitivoarias.354@ejemplo.cr'),
    ('Ramon', 'Rios', 'Montes', '101330367', '2014-06-09', 'F', 'Los Ángeles, Calle 32, Naranjo, Alajuela, Costa Rica. Casa 191', '+506 48496965', 'ramonrios.367@ejemplo.cr'),
    ('Jose', 'Cisneros', 'Chacon', '101330473', '2012-06-17', 'M', 'San Martín, Calle 7, Bagaces, Guanacaste, Costa Rica. Casa 29', '+506 62691669', 'josecisneros.473@ejemplo.cr'),
    ('Nelly', 'Coto', 'Solano', '101330740', '2015-04-02', 'F', 'San Martín, Avenida 20, Liberia, Guanacaste, Costa Rica. Casa 193', '+506 75146270', 'nellycoto.740@ejemplo.cr'),
    ('Antonio Mario', 'Rodriguez', 'Araya', '101330898', '2018-02-05', 'F', 'San Miguel, Calle 14, Nicoya, Guanacaste, Costa Rica. Casa 161', '+506 78932528', 'antoniorodriguez.898@ejemplo.cr'),
    ('Adan', 'Cespedes', 'Arias', '101350119', '2018-09-25', 'M', 'La Trinidad, Calle 3, Santa Cruz, Guanacaste, Costa Rica. Casa 29', '+506 74303911', 'adancespedes.119@ejemplo.cr'),
    ('Julieta', 'Castro', 'Alvarado', '101350285', '2018-03-17', 'F', 'San Miguel, Calle 17, Limón, Limón, Costa Rica. Casa 33', '+506 88248963', 'julietacastro.285@ejemplo.cr'),
    ('Gabriela', 'Quesada', 'Talavera', '101350654', '2016-01-18', 'M', 'San Antonio, Calle 48, Buenos Aires, Puntarenas, Costa Rica. Casa 113', '+506 47133150', 'gabrielaquesada.654@ejemplo.cr'),
    ('Julieta', 'Zeledon', 'Matamoros', '101370377', '2016-08-06', 'M', 'Centro, Calle 10, Nicoya, Guanacaste, Costa Rica. Casa 182', '+506 23105183', 'julietazeledon.377@ejemplo.cr'),
    ('Emelina', 'Hidalgo', 'Flores', '101370531', '2013-02-14', 'F', 'Los Ángeles, Avenida 25, San Carlos, Alajuela, Costa Rica. Casa 148', '+506 83763116', 'emelinahidalgo.531@ejemplo.cr'),
    ('Guadalupe', 'Alpizar', 'Brenes', '101370879', '2013-12-22', 'F', 'Centro, Calle 13, Flores, Heredia, Costa Rica. Casa 16', '+506 85133387', 'guadalupealpizar.879@ejemplo.cr'),
    ('Luz', 'Jimenez', 'Moreno', '101380569', '2011-07-29', 'F', 'La Trinidad, Calle 32, Naranjo, Alajuela, Costa Rica. Casa 20', '+506 88108013', 'luzjimenez.569@ejemplo.cr'),
    ('Maria Josefa', 'Castro', 'Chacon', '101390562', '2011-11-13', 'F', 'San Francisco, Avenida 3, Flores, Heredia, Costa Rica. Casa 16', '+506 66064746', 'mariacastro.562@ejemplo.cr'),
    ('Cidely Maria', 'Rodriguez', 'Madrigal', '101390996', '2017-10-24', 'F', 'San Rafael, Calle 28, Atenas, Alajuela, Costa Rica. Casa 15', '+506 48050097', 'cidelyrodriguez.996@ejemplo.cr'),
    ('Esmeralda', 'Fallas', 'Alpizar', '101410818', '2015-08-22', 'M', 'San Martín, Calle 24, Santa Ana, San José, Costa Rica. Casa 18', '+506 41361939', 'esmeraldafallas.818@ejemplo.cr'),
    ('Maria', 'Quiros', 'Chaves', '101410977', '2016-09-01', 'M', 'San Antonio, Avenida 26, Liberia, Guanacaste, Costa Rica. Casa 145', '+506 45435346', 'mariaquiros.977@ejemplo.cr'),
    ('Oliva', 'Mata', 'Solis', '101410986', '2011-06-21', 'F', 'San Martín, Calle 2, San Isidro, Heredia, Costa Rica. Casa 118', '+506 49118384', 'olivamata.986@ejemplo.cr'),
    ('Dionicio', 'Monge', 'Salazar', '101430241', '2011-06-27', 'F', 'San Juan, Calle 37, Mora, San José, Costa Rica. Casa 41', '+506 88498084', 'dioniciomonge.241@ejemplo.cr'),
    ('Juan Jose', 'Sanchez', 'Rivera', '101430262', '2017-06-10', 'M', 'San Martín, Calle 14, Naranjo, Alajuela, Costa Rica. Casa 191', '+506 42449353', 'juansanchez.262@ejemplo.cr'),
    ('Maria De La Caridad', 'Rojas', 'Mora', '101440305', '2017-09-16', 'F', 'San Rafael, Calle 7, Bagaces, Guanacaste, Costa Rica. Casa 24', '+506 84005242', 'mariarojas.305@ejemplo.cr'),
    ('Carolina', 'Navarro', 'Ureña', '101440528', '2018-04-25', 'F', 'San Antonio, Avenida 23, Cañas, Guanacaste, Costa Rica. Casa 3', '+506 21280598', 'carolinanavarro.528@ejemplo.cr'),
    ('Zelmira', 'Lopez', 'Corrales', '101450088', '2011-08-30', 'F', 'San Rafael, Calle 47, Alajuela, Alajuela, Costa Rica. Casa 11', '+506 73315869', 'zelmiralopez.088@ejemplo.cr'),
    ('David', 'Chaves', 'Zamora', '101450137', '2018-05-28', 'M', 'Los Ángeles, Avenida 4, Grecia, Alajuela, Costa Rica. Casa 7', '+506 65634216', 'davidchaves.137@ejemplo.cr'),
    ('Alice', 'Paninski', 'Rojas', '101450809', '2010-06-08', 'F', 'La Trinidad, Calle 45, Atenas, Alajuela, Costa Rica. Casa 79', '+506 63036541', 'alicepaninski.809@ejemplo.cr'),
    ('Albertina', 'Rojas', 'Garro', '101450835', '2018-09-03', 'F', 'San Miguel, Avenida 3, Alvarado, Cartago, Costa Rica. Casa 174', '+506 45014294', 'albertinarojas.835@ejemplo.cr'),
    ('Blanca', 'Quesada', 'Monge', '101460311', '2010-06-06', 'M', 'San Juan, Calle 41, Bagaces, Guanacaste, Costa Rica. Casa 112', '+506 48169340', 'blancaquesada.311@ejemplo.cr'),
    ('Ana Maria', 'Jimenez', 'Zuñiga', '101460563', '2017-12-13', 'F', 'San Miguel, Calle 26, Santa Ana, San José, Costa Rica. Casa 94', '+506 81595148', 'anajimenez.563@ejemplo.cr'),
    ('Dinorah', 'Quesada', 'Rodriguez', '101460828', '2013-06-20', 'F', 'San Rafael, Avenida 22, Jiménez, Cartago, Costa Rica. Casa 33', '+506 66629946', 'dinorahquesada.828@ejemplo.cr'),
    ('Jaime', 'Rojas', 'Jimenez', '101460864', '2016-02-23', 'M', 'San Francisco, Avenida 7, La Unión, Cartago, Costa Rica. Casa 149', '+506 45777387', 'jaimerojas.864@ejemplo.cr'),
    ('Maria Eugenia', 'Vargas', 'Solera', '101470124', '2018-11-26', 'M', 'San Rafael, Avenida 17, Puntarenas, Puntarenas, Costa Rica. Casa 170', '+506 45134332', 'mariavargas.124@ejemplo.cr'),
    ('Lilian', 'Calderon', 'Chavez', '101470361', '2010-04-11', 'M', 'San Martín, Avenida 10, Orotina, Alajuela, Costa Rica. Casa 107', '+506 43676320', 'liliancalderon.361@ejemplo.cr'),
    ('Maria Rosa', 'Quiros', 'Amador', '101470614', '2018-06-03', 'M', 'San Francisco, Calle 23, Talamanca, Limón, Costa Rica. Casa 179', '+506 47083172', 'mariaquiros.614@ejemplo.cr'),
    ('Alfredo', 'Miranda', 'Miranda', '101470746', '2018-12-27', 'F', 'San Miguel, Avenida 28, Osa, Puntarenas, Costa Rica. Casa 82', '+506 89868727', 'alfredomiranda.746@ejemplo.cr'),
    ('Ramon Victor', 'Salas', 'Chavarria', '101470808', '2015-01-18', 'F', 'San Rafael, Avenida 18, Pococí, Limón, Costa Rica. Casa 125', '+506 64714345', 'ramonsalas.808@ejemplo.cr'),
    ('Eida', 'Fonseca', 'Zayas Bazan', '101480340', '2013-08-02', 'M', 'San Francisco, Avenida 1, Grecia, Alajuela, Costa Rica. Casa 178', '+506 63166587', 'eidafonseca.340@ejemplo.cr'),
    ('Amparo', 'Jarquin', 'Leon', '101480400', '2014-08-31', 'M', 'San Antonio, Avenida 26, Poás, Alajuela, Costa Rica. Casa 179', '+506 29670546', 'amparojarquin.400@ejemplo.cr'),
    ('Eida', 'Espeleta', 'Vargas', '101480405', '2014-09-13', 'M', 'San Rafael, Avenida 7, Santa Bárbara, Heredia, Costa Rica. Casa 125', '+506 26562729', 'eidaespeleta.405@ejemplo.cr'),
    ('Ines', 'Sanchez', 'Brenes', '101480644', '2015-12-28', 'M', 'San Martín, Avenida 6, Heredia, Heredia, Costa Rica. Casa 35', '+506 82046537', 'inessanchez.644@ejemplo.cr'),
    ('Maria Rosa', 'Ramirez', 'Araya', '101480753', '2013-08-31', 'F', 'San Rafael, Avenida 5, Talamanca, Limón, Costa Rica. Casa 65', '+506 27080531', 'mariaramirez.753@ejemplo.cr'),
    ('Elisa Emma', 'Quesada', 'Altamirano', '101490062', '2018-10-05', 'M', 'San Francisco, Calle 26, Limón, Limón, Costa Rica. Casa 6', '+506 42327193', 'elisaquesada.062@ejemplo.cr'),
    ('Jose Andres', 'Del Valle', 'Aguilar', '101490232', '2015-03-20', 'F', 'Los Ángeles, Avenida 29, Siquirres, Limón, Costa Rica. Casa 156', '+506 22419049', 'josedelvalle.232@ejemplo.cr'),
    ('Sara', 'Ordeñana', 'Alvarez', '101490300', '2017-08-06', 'F', 'San Martín, Avenida 27, Santa Bárbara, Heredia, Costa Rica. Casa 177', '+506 61491905', 'saraordeana.300@ejemplo.cr'),
    ('Noe', 'Picado', 'Alvarado', '101490368', '2015-12-23', 'F', 'San Martín, Avenida 16, Buenos Aires, Puntarenas, Costa Rica. Casa 166', '+506 70671657', 'noepicado.368@ejemplo.cr'),
    ('Zoraida', 'Arias', 'Alvarez', '101490505', '2017-12-07', 'M', 'San Miguel, Calle 35, Santo Domingo, Heredia, Costa Rica. Casa 158', '+506 47769453', 'zoraidaarias.505@ejemplo.cr'),
    ('Jenarin', 'Prado', 'Prado', '101490753', '2010-12-21', 'F', 'La Trinidad, Avenida 24, Santa Bárbara, Heredia, Costa Rica. Casa 157', '+506 85075273', 'jenarinprado.753@ejemplo.cr'),
    ('Brigida', 'Valverde', 'Cordero', '101490972', '2013-12-24', 'F', 'San Rafael, Avenida 23, La Unión, Cartago, Costa Rica. Casa 3', '+506 43136783', 'brigidavalverde.972@ejemplo.cr'),
    ('Mario', 'Esquivel', 'Benavides', '101500451', '2017-09-29', 'F', 'La Trinidad, Avenida 9, Golfito, Puntarenas, Costa Rica. Casa 5', '+506 24363495', 'marioesquivel.451@ejemplo.cr'),
    ('Felicitas', 'Solis', 'Cordero', '101500613', '2015-04-23', 'F', 'San Juan, Avenida 10, San Isidro, Heredia, Costa Rica. Casa 70', '+506 74313518', 'felicitassolis.613@ejemplo.cr'),
    ('Olga', 'Alan', 'Fonseca', '101500830', '2018-07-19', 'M', 'La Trinidad, Calle 36, Atenas, Alajuela, Costa Rica. Casa 186', '+506 48941343', 'olgaalan.830@ejemplo.cr'),
    ('Nelly', 'Valverde', 'Madrigal', '101500843', '2014-01-18', 'M', 'San Miguel, Calle 17, Cartago, Cartago, Costa Rica. Casa 71', '+506 20842710', 'nellyvalverde.843@ejemplo.cr'),
    ('Etelvina', 'Mora', 'Monge', '101500971', '2016-06-09', 'F', 'La Trinidad, Calle 44, Flores, Heredia, Costa Rica. Casa 48', '+506 24711671', 'etelvinamora.971@ejemplo.cr'),
    ('Mireya', 'Calvo', 'Eduarte', '101510014', '2016-06-21', 'M', 'San Rafael, Calle 11, Grecia, Alajuela, Costa Rica. Casa 64', '+506 28699938', 'mireyacalvo.014@ejemplo.cr'),
    ('Maria Carmen', 'Castro', 'Chavarria', '101510722', '2014-04-08', 'F', 'San Antonio, Calle 40, San Rafael, Heredia, Costa Rica. Casa 146', '+506 40913341', 'mariacastro.722@ejemplo.cr'),
    ('Julio', 'Cordero', 'Fonseca', '101510789', '2011-10-06', 'M', 'San Martín, Calle 21, San Carlos, Alajuela, Costa Rica. Casa 1', '+506 87974034', 'juliocordero.789@ejemplo.cr'),
    ('Elodia', 'Seas', 'Hidalgo', '101510898', '2017-12-05', 'F', 'La Trinidad, Calle 10, Coto Brus, Puntarenas, Costa Rica. Casa 176', '+506 64936183', 'elodiaseas.898@ejemplo.cr'),
    ('Nelly', 'Porras', 'Arguedas', '101510927', '2017-04-06', 'M', 'Los Ángeles, Calle 10, Oreamuno, Cartago, Costa Rica. Casa 16', '+506 64994717', 'nellyporras.927@ejemplo.cr'),
    ('Virginia', 'Cordero', 'Blanco', '101520059', '2017-09-21', 'F', 'San Rafael, Avenida 16, Montes de Oro, Puntarenas, Costa Rica. Casa 139', '+506 87190659', 'virginiacordero.059@ejemplo.cr'),
    ('Fausto', 'Salazar', 'Gomez', '101520093', '2012-10-22', 'M', 'Centro, Calle 35, Mora, San José, Costa Rica. Casa 148', '+506 22787429', 'faustosalazar.093@ejemplo.cr'),
    ('Elida', 'Arias', 'Mora', '101520100', '2014-11-21', 'F', 'San Juan, Avenida 4, Curridabat, San José, Costa Rica. Casa 86', '+506 71256746', 'elidaarias.100@ejemplo.cr'),
    ('Ramon', 'Sanchez', 'Hernandez', '101520134', '2018-07-13', 'M', 'San Juan, Calle 33, Barva, Heredia, Costa Rica. Casa 83', '+506 26808760', 'ramonsanchez.134@ejemplo.cr'),
    ('Gregorio', 'Arias', 'Aguero', '101520146', '2012-02-08', 'F', 'La Trinidad, Calle 7, Bagaces, Guanacaste, Costa Rica. Casa 53', '+506 78247710', 'gregorioarias.146@ejemplo.cr'),
    ('Flora', 'Retana', 'Monge', '101520461', '2017-01-24', 'M', 'San Rafael, Avenida 22, Esparza, Puntarenas, Costa Rica. Casa 4', '+506 46131712', 'floraretana.461@ejemplo.cr'),
    ('Rita', 'Hernandez', 'Lopez', '101520726', '2015-08-04', 'F', 'San Rafael, Avenida 5, Cañas, Guanacaste, Costa Rica. Casa 124', '+506 83782639', 'ritahernandez.726@ejemplo.cr'),
    ('Aurora', 'Elizondo', 'Corrales', '101530392', '2015-09-13', 'M', 'San Rafael, Avenida 5, Limón, Limón, Costa Rica. Casa 88', '+506 44044997', 'auroraelizondo.392@ejemplo.cr'),
    ('Miguel Guillermo', 'Montoya', 'Gutierrez', '101530611', '2011-09-01', 'F', 'San Juan, Calle 43, Bagaces, Guanacaste, Costa Rica. Casa 142', '+506 46753396', 'miguelmontoya.611@ejemplo.cr'),
    ('Carmen Lia', 'Porras', 'Quiros', '101530680', '2012-08-14', 'F', 'La Trinidad, Calle 49, Montes de Oca, San José, Costa Rica. Casa 99', '+506 67028951', 'carmenporras.680@ejemplo.cr'),
    ('Carlos Luis', 'Corrales', 'Villalobos', '101530736', '2014-12-09', 'M', 'Centro, Calle 19, Bagaces, Guanacaste, Costa Rica. Casa 105', '+506 61745961', 'carloscorrales.736@ejemplo.cr'),
    ('Alejandro', 'Delgado', 'Lopez', '101530785', '2013-09-07', 'F', 'La Trinidad, Avenida 21, Alvarado, Cartago, Costa Rica. Casa 10', '+506 41343161', 'alejandrodelgado.785@ejemplo.cr'),
    ('Noemi', 'Camacho', 'Fernandez', '101530943', '2018-07-12', 'M', 'San Rafael, Calle 4, Santo Domingo, Heredia, Costa Rica. Casa 12', '+506 70455623', 'noemicamacho.943@ejemplo.cr'),
    ('Refugio', 'Aguilar', 'Gamboa', '101540070', '2015-12-16', 'F', 'Los Ángeles, Calle 22, Cañas, Guanacaste, Costa Rica. Casa 45', '+506 29693792', 'refugioaguilar.070@ejemplo.cr'),
    ('Jose Rafael', 'Fallas', 'Quesada', '101540250', '2012-08-09', 'F', 'La Trinidad, Calle 33, Buenos Aires, Puntarenas, Costa Rica. Casa 171', '+506 27482175', 'josefallas.250@ejemplo.cr'),
    ('Miguel Angel', 'Delgado', 'Huertas', '101540912', '2016-08-03', 'F', 'San Rafael, Avenida 10, Montes de Oro, Puntarenas, Costa Rica. Casa 78', '+506 66713695', 'migueldelgado.912@ejemplo.cr'),
    ('Elvira', 'Bermudez', 'Arguedas', '101550388', '2016-06-12', 'F', 'Centro, Avenida 2, Buenos Aires, Puntarenas, Costa Rica. Casa 71', '+506 29097439', 'elvirabermudez.388@ejemplo.cr'),
    ('Margarita', 'Gomez', 'Gonzalez', '101550579', '2018-12-29', 'F', 'San Rafael, Calle 18, Atenas, Alajuela, Costa Rica. Casa 161', '+506 20470952', 'margaritagomez.579@ejemplo.cr'),
    ('Zelmira', 'Sandoval', 'Zeledon', '101550628', '2011-01-05', 'F', 'San Antonio, Calle 23, Alvarado, Cartago, Costa Rica. Casa 52', '+506 68588424', 'zelmirasandoval.628@ejemplo.cr'),
    ('Anibal', 'Fallas', 'Chavarria', '101550678', '2015-05-28', 'F', 'San Juan, Calle 15, Coto Brus, Puntarenas, Costa Rica. Casa 120', '+506 22368516', 'anibalfallas.678@ejemplo.cr'),
    ('Marta', 'Cordero', 'Pacheco', '101550812', '2010-02-27', 'F', 'La Trinidad, Calle 48, Liberia, Guanacaste, Costa Rica. Casa 173', '+506 79651370', 'martacordero.812@ejemplo.cr');

    INSERT INTO tb_Cargo (nombre_Cargo, descripcion) VALUES
    ('Director Médico', 'Lidera la parte clínica y protocolos.'),
    ('Médico Psiquiatra', 'Atención clínica especializada en salud mental.'),
    ('Médico General', 'Atención primaria de pacientes.'),
    ('Psicólogo Clínico', 'Terapia psicológica individual y grupal.'),
    ('Trabajador Social', 'Evaluación sociofamiliar y seguimiento.'),
    ('Enfermero/a', 'Cuidados de enfermería y administración de medicamentos.'),
    ('Farmacéutico/a', 'Gestión de medicamentos y dispensación.'),
    ('Nutricionista', 'Planes nutricionales y educación alimentaria.'),
    ('Terapista Ocupacional', 'Rehabilitación y habilidades para la vida diaria.'),
    ('Fisioterapeuta', 'Terapia física y ejercicio terapéutico.'),
    ('Consejero en Adicciones', 'Intervención breve y acompañamiento.'),
    ('Secretaria', 'Recepción y soporte administrativo.'),
    ('Cocinero/a', 'Preparación de alimentos.'),
    ('Limpieza y Mantenimiento', 'Aseo y mantenimiento general.'),
    ('Seguridad', 'Control de acceso y vigilancia.');

    INSERT INTO tb_Empleado (id_Persona, id_Cargo, fecha_Ingreso, salario_Mensual, estado) VALUES
    (5, 2, '2024-05-13', '3500000.00', 'ACTIVO'),
    (6, 3, '2023-05-21', '2000000.00', 'ACTIVO'),
    (9, 4, '2024-03-18', '1500000.00', 'ACTIVO'),
    (13, 5, '2024-11-03', '1500000.00', 'ACTIVO'),
    (15, 6, '2023-01-06', '1500000.00', 'ACTIVO'),
    (18, 7, '2023-09-24', '2000000.00', 'ACTIVO'),
    (24, 8, '2023-12-24', '1500000.00', 'ACTIVO'),
    (29, 9, '2023-09-27', '1500000.00', 'ACTIVO'),
    (30, 10, '2024-05-02', '1500000.00', 'ACTIVO'),
    (31, 11, '2023-02-02', '800000.00', 'ACTIVO'),
    (39, 12, '2023-04-18', '600000.00', 'INACTIVO'),
    (42, 13, '2023-08-21', '600000.00', 'ACTIVO'),
    (43, 14, '2025-09-02', '400000.00', 'ACTIVO'),
    (45, 15, '2023-08-12', '400000.00', 'ACTIVO'),
    (48, 1, '2023-03-30', '5000000.00', 'ACTIVO'),
    (50, 2, '2025-07-27', '3500000.00', 'ACTIVO'),
    (53, 3, '2023-05-05', '2000000.00', 'INACTIVO'),
    (60, 4, '2025-05-23', '1500000.00', 'ACTIVO'),
    (64, 5, '2025-10-01', '1500000.00', 'INACTIVO'),
    (72, 6, '2023-05-31', '1500000.00', 'ACTIVO'),
    (73, 7, '2023-10-31', '2000000.00', 'ACTIVO'),
    (74, 8, '2024-07-17', '1500000.00', 'ACTIVO'),
    (76, 9, '2025-02-19', '1500000.00', 'ACTIVO'),
    (79, 10, '2025-07-18', '1500000.00', 'INACTIVO'),
    (80, 11, '2023-07-23', '800000.00', 'ACTIVO'),
    (7, 3, '2023-07-20', '1850000.00', 'ACTIVO'),
    (8, 4, '2024-01-15', '1500000.00', 'ACTIVO'),
    (11, 5, '2023-09-05', '1650000.00', 'ACTIVO'),
    (12, 6, '2024-04-12', '1550000.00', 'INACTIVO'),
    (17, 7, '2024-09-02', '2000000.00', 'ACTIVO'),
    (19, 8, '2024-02-28', '1450000.00', 'ACTIVO'),
    (23, 9, '2025-02-15', '1550000.00', 'ACTIVO'),
    (26, 10, '2023-06-11', '1600000.00', 'ACTIVO'),
    (35, 11, '2024-05-10', '850000.00', 'ACTIVO'),
    (41, 12, '2023-08-03', '600000.00', 'INACTIVO'),
    (47, 13, '2023-11-24', '600000.00', 'ACTIVO'),
    (54, 14, '2024-02-18', '600000.00', 'ACTIVO'),
    (58, 15, '2025-03-09', '400000.00', 'ACTIVO'),
    (61, 1, '2023-04-04', '5000000.00', 'ACTIVO'),
    (68, 2, '2024-10-26', '3400000.00', 'ACTIVO');

    INSERT INTO tb_Fase_Tratamiento (nombre_Fase, descripcion) VALUES
    ('Captación', 'Identificación, prevención y motivación para el tratamiento.'),
    ('Desintoxicación', 'Manejo inicial de abstinencia y estabilización.'),
    ('Tratamiento', 'Intervenciones clínicas y psicosociales.'),
    ('Seguimiento', 'Monitoreo de evolución y adherencia.'),
    ('Reinserción Social', 'Vinculación educativa/laboral y redes de apoyo.');

    INSERT INTO tb_Paciente (id_Persona, fecha_Ingreso, estado, observaciones) VALUES
    (1, '2025-10-28', 'ALTA', 'Ingreso voluntario acompañado por familiar.'),
    (2, '2025-03-16', 'EN TRATAMIENTO', 'Ingreso voluntario acompañado por familiar.'),
    (3, '2025-02-27', 'ACTIVO', 'Seguimiento posterior a episodio agudo.'),
    (4, '2025-02-12', 'EN TRATAMIENTO', 'Ingreso referido por CAID.'),
    (10, '2024-11-16', 'EN TRATAMIENTO', 'Derivado desde IAFA para programa residencial.'),
    (14, '2024-09-18', 'ACTIVO', 'Ingreso voluntario acompañado por familiar.'),
    (16, '2025-04-30', 'ACTIVO', 'Ingreso referido por CAID.'),
    (20, '2024-03-28', 'ACTIVO', 'Seguimiento posterior a episodio agudo.'),
    (21, '2024-04-08', 'SUSPENDIDO', 'Derivado desde IAFA para programa residencial.'),
    (22, '2024-05-13', 'ALTA', 'Ingreso referido por CAID.'),
    (25, '2025-08-23', 'ALTA', 'Evaluación inicial en proceso.'),
    (27, '2024-12-03', 'SUSPENDIDO', 'Ingreso referido por CAID.'),
    (28, '2025-02-24', 'ACTIVO', 'Seguimiento posterior a episodio agudo.'),
    (32, '2024-02-22', 'ACTIVO', 'Evaluación inicial en proceso.'),
    (33, '2024-11-15', 'ACTIVO', 'Ingreso referido por CAID.'),
    (34, '2025-08-14', 'ALTA', 'Ingreso voluntario acompañado por familiar.'),
    (36, '2024-06-07', 'SUSPENDIDO', 'Seguimiento posterior a episodio agudo.'),
    (37, '2024-08-17', 'ACTIVO', 'Derivado desde IAFA para programa residencial.'),
    (38, '2025-07-23', 'ACTIVO', 'Ingreso referido por CAID.'),
    (40, '2024-10-12', 'ALTA', 'Ingreso voluntario acompañado por familiar.'),
    (44, '2025-03-15', 'ALTA', 'Evaluación inicial en proceso.'),
    (46, '2025-09-20', 'SUSPENDIDO', 'Evaluación inicial en proceso.'),
    (49, '2024-01-27', 'ALTA', 'Derivado desde IAFA para programa residencial.'),
    (51, '2024-01-30', 'ACTIVO', 'Derivado desde IAFA para programa residencial.'),
    (52, '2024-11-12', 'ACTIVO', 'Derivado desde IAFA para programa residencial.'),
    (55, '2024-01-07', 'ACTIVO', 'Ingreso voluntario acompañado por familiar.'),
    (56, '2025-08-02', 'SUSPENDIDO', 'Seguimiento posterior a episodio agudo.'),
    (57, '2024-03-12', 'ACTIVO', 'Ingreso referido por CAID.'),
    (59, '2024-04-03', 'SUSPENDIDO', 'Evaluación inicial en proceso.'),
    (62, '2024-08-08', 'EN TRATAMIENTO', 'Seguimiento posterior a episodio agudo.'),
    (63, '2025-04-09', 'ACTIVO', 'Ingreso voluntario acompañado por familiar.'),
    (65, '2025-01-13', 'ACTIVO', 'Derivado desde IAFA para programa residencial.'),
    (66, '2025-08-04', 'ALTA', 'Ingreso referido por CAID.'),
    (67, '2024-02-23', 'ACTIVO', 'Ingreso voluntario acompañado por familiar.'),
    (69, '2025-09-24', 'ACTIVO', 'Ingreso referido por CAID.'),
    (70, '2024-10-05', 'EN TRATAMIENTO', 'Seguimiento posterior a episodio agudo.'),
    (71, '2025-05-12', 'ALTA', 'Seguimiento posterior a episodio agudo.'),
    (77, '2025-02-28', 'ACTIVO', 'Ingreso voluntario acompañado por familiar.'),
    (81, '2025-06-08', 'ACTIVO', 'Derivado desde IAFA para programa residencial.'),
    (82, '2025-03-16', 'ACTIVO', 'Derivado desde IAFA para programa residencial.'),
    (83, '2025-08-30', 'EN TRATAMIENTO', 'Evaluación inicial en proceso.');

    INSERT INTO tb_Paciente_Fase (id_Paciente, id_Fase, fecha_Inicio, fecha_Fin, estado, observaciones) VALUES
    (1, 1, '2024-11-11', '2024-12-08', 'FINALIZADA', ''),
    (1, 3, '2024-12-12', '2025-02-08', 'FINALIZADA', 'Evolución favorable.'),
    (1, 4, '2025-02-11', '2025-04-04', 'FINALIZADA', 'Requiere apoyo familiar.'),
    (1, 5, '2025-04-10', NULL, 'EN CURSO', 'Alta motivación.'),
    (2, 1, '2024-06-28', '2024-08-16', 'FINALIZADA', 'Pendiente valoración médica.'),
    (2, 3, '2024-08-25', '2024-10-29', 'FINALIZADA', ''),
    (2, 4, '2024-11-05', '2024-11-30', 'FINALIZADA', ''),
    (3, 1, '2024-03-20', '2024-05-30', 'FINALIZADA', 'Alta motivación.'),
    (3, 3, '2024-06-04', '2024-07-08', 'FINALIZADA', ''),
    (4, 1, '2024-06-24', '2024-08-29', 'FINALIZADA', ''),
    (4, 3, '2024-09-05', NULL, 'EN CURSO', 'Alta motivación.'),
    (5, 1, '2025-02-14', '2025-04-14', 'FINALIZADA', 'Requiere apoyo familiar.'),
    (5, 3, '2025-04-18', '2025-06-19', 'FINALIZADA', 'Evolución favorable.'),
    (5, 4, '2025-06-21', '2025-09-14', 'FINALIZADA', ''),
    (5, 5, '2025-09-23', NULL, 'EN CURSO', 'Requiere apoyo familiar.'),
    (6, 1, '2024-05-31', '2024-07-15', 'FINALIZADA', 'Evolución favorable.'),
    (6, 3, '2024-07-25', '2024-09-02', 'FINALIZADA', ''),
    (6, 4, '2024-09-05', '2024-11-27', 'FINALIZADA', 'Alta motivación.'),
    (6, 5, '2024-12-07', '2025-02-22', 'FINALIZADA', 'Requiere apoyo familiar.'),
    (7, 1, '2025-03-26', '2025-05-23', 'FINALIZADA', 'Requiere apoyo familiar.'),
    (7, 3, '2025-06-02', '2025-06-29', 'FINALIZADA', 'Requiere apoyo familiar.'),
    (7, 4, '2025-07-08', '2025-08-06', 'FINALIZADA', 'Requiere apoyo familiar.'),
    (7, 5, '2025-08-14', NULL, 'EN CURSO', ''),
    (8, 1, '2024-10-20', '2024-11-20', 'FINALIZADA', 'Pendiente valoración médica.'),
    (8, 3, '2024-11-30', '2025-02-22', 'FINALIZADA', 'Alta motivación.'),
    (8, 4, '2025-03-02', NULL, 'EN CURSO', 'Alta motivación.'),
    (9, 1, '2024-07-11', '2024-08-19', 'FINALIZADA', ''),
    (9, 3, '2024-08-27', '2024-09-29', 'FINALIZADA', 'Requiere apoyo familiar.'),
    (9, 4, '2024-10-01', '2024-12-24', 'FINALIZADA', 'Evolución favorable.'),
    (9, 5, '2024-12-25', '2025-02-14', 'FINALIZADA', 'Alta motivación.'),
    (10, 1, '2025-06-19', '2025-08-14', 'FINALIZADA', 'Alta motivación.'),
    (10, 3, '2025-08-21', '2025-10-23', 'FINALIZADA', 'Pendiente valoración médica.'),
    (10, 4, '2025-10-24', '2025-12-25', 'FINALIZADA', ''),
    (10, 5, '2025-12-31', '2026-02-01', 'FINALIZADA', 'Requiere apoyo familiar.'),
    (11, 1, '2024-06-02', '2024-07-10', 'FINALIZADA', 'Requiere apoyo familiar.'),
    (11, 3, '2024-07-15', '2024-09-23', 'FINALIZADA', 'Evolución favorable.'),
    (11, 4, '2024-10-03', '2024-11-02', 'FINALIZADA', 'Pendiente valoración médica.'),
    (12, 1, '2024-12-02', '2025-02-27', 'FINALIZADA', ''),
    (12, 3, '2025-03-06', '2025-05-30', 'FINALIZADA', ''),
    (13, 1, '2024-11-12', '2025-02-02', 'FINALIZADA', 'Evolución favorable.'),
    (13, 3, '2025-02-06', '2025-03-15', 'FINALIZADA', 'Evolución favorable.'),
    (13, 4, '2025-03-17', '2025-05-13', 'FINALIZADA', ''),
    (13, 5, '2025-05-22', NULL, 'EN CURSO', 'Requiere apoyo familiar.'),
    (14, 1, '2024-05-14', '2024-06-26', 'FINALIZADA', 'Pendiente valoración médica.'),
    (14, 3, '2024-06-29', '2024-09-13', 'FINALIZADA', ''),
    (14, 4, '2024-09-20', '2024-11-25', 'FINALIZADA', 'Evolución favorable.'),
    (14, 5, '2024-12-03', '2025-01-28', 'FINALIZADA', 'Evolución favorable.'),
    (15, 1, '2024-09-01', '2024-11-20', 'FINALIZADA', 'Evolución favorable.'),
    (15, 3, '2024-11-26', '2025-02-10', 'FINALIZADA', 'Alta motivación.'),
    (15, 4, '2025-02-15', '2025-04-24', 'FINALIZADA', 'Evolución favorable.'),
    (16, 1, '2024-05-21', '2024-08-10', 'FINALIZADA', 'Requiere apoyo familiar.'),
    (16, 3, '2024-08-19', '2024-09-21', 'FINALIZADA', 'Pendiente valoración médica.'),
    (16, 5, '2024-09-23', NULL, 'EN CURSO', 'Evolución favorable.'),
    (17, 1, '2025-04-05', '2025-06-19', 'FINALIZADA', ''),
    (17, 3, '2025-06-23', '2025-09-08', 'FINALIZADA', 'Requiere apoyo familiar.'),
    (17, 5, '2025-09-09', NULL, 'EN CURSO', 'Alta motivación.'),
    (18, 1, '2025-01-17', '2025-03-25', 'FINALIZADA', 'Evolución favorable.'),
    (18, 3, '2025-03-26', '2025-05-25', 'FINALIZADA', ''),
    (18, 4, '2025-05-31', NULL, 'EN CURSO', ''),
    (19, 1, '2025-04-28', '2025-07-17', 'FINALIZADA', 'Alta motivación.'),
    (19, 3, '2025-07-27', '2025-08-16', 'FINALIZADA', ''),
    (19, 4, '2025-08-17', '2025-10-08', 'FINALIZADA', 'Evolución favorable.'),
    (19, 5, '2025-10-11', '2026-01-09', 'FINALIZADA', ''),
    (20, 1, '2024-08-31', '2024-11-12', 'FINALIZADA', 'Pendiente valoración médica.'),
    (20, 3, '2024-11-20', '2024-12-18', 'FINALIZADA', ''),
    (20, 4, '2024-12-26', '2025-03-24', 'FINALIZADA', ''),
    (20, 5, '2025-04-02', NULL, 'EN CURSO', 'Requiere apoyo familiar.'),
    (21, 1, '2024-01-02', '2024-03-15', 'FINALIZADA', 'Evolución favorable.'),
    (21, 3, '2024-03-17', '2024-06-12', 'FINALIZADA', 'Requiere apoyo familiar.'),
    (21, 4, '2024-06-14', '2024-09-09', 'FINALIZADA', 'Pendiente valoración médica.'),
    (21, 5, '2024-09-18', NULL, 'EN CURSO', 'Alta motivación.'),
    (22, 1, '2024-02-14', '2024-04-06', 'FINALIZADA', ''),
    (22, 3, '2024-04-12', '2024-05-10', 'FINALIZADA', 'Requiere apoyo familiar.'),
    (22, 4, '2024-05-14', '2024-06-16', 'FINALIZADA', 'Evolución favorable.'),
    (23, 1, '2024-12-26', '2025-02-06', 'FINALIZADA', 'Alta motivación.'),
    (23, 3, '2025-02-14', '2025-03-29', 'FINALIZADA', 'Evolución favorable.'),
    (23, 4, '2025-03-31', NULL, 'EN CURSO', 'Requiere apoyo familiar.'),
    (24, 1, '2024-02-14', '2024-04-14', 'FINALIZADA', 'Requiere apoyo familiar.'),
    (24, 3, '2024-04-23', '2024-07-02', 'FINALIZADA', 'Requiere apoyo familiar.'),
    (25, 1, '2024-07-14', '2024-08-09', 'FINALIZADA', 'Requiere apoyo familiar.'),
    (25, 3, '2024-08-14', '2024-09-18', 'FINALIZADA', 'Requiere apoyo familiar.'),
    (25, 4, '2024-09-25', '2024-12-05', 'FINALIZADA', 'Alta motivación.'),
    (26, 1, '2024-07-10', '2024-10-04', 'FINALIZADA', 'Requiere apoyo familiar.'),
    (26, 3, '2024-10-06', '2024-12-19', 'FINALIZADA', ''),
    (26, 4, '2024-12-26', '2025-02-07', 'FINALIZADA', 'Pendiente valoración médica.'),
    (26, 5, '2025-02-12', NULL, 'EN CURSO', ''),
    (27, 1, '2024-10-29', '2025-01-11', 'FINALIZADA', 'Evolución favorable.'),
    (27, 3, '2025-01-19', '2025-03-24', 'FINALIZADA', 'Alta motivación.'),
    (27, 4, '2025-03-25', '2025-05-29', 'FINALIZADA', 'Requiere apoyo familiar.'),
    (28, 1, '2024-03-17', '2024-06-10', 'FINALIZADA', 'Evolución favorable.'),
    (28, 3, '2024-06-11', '2024-07-19', 'FINALIZADA', 'Pendiente valoración médica.'),
    (28, 4, '2024-07-27', '2024-08-20', 'FINALIZADA', 'Evolución favorable.'),
    (28, 5, '2024-08-22', '2024-10-11', 'FINALIZADA', 'Requiere apoyo familiar.'),
    (29, 1, '2025-08-03', '2025-10-19', 'FINALIZADA', 'Requiere apoyo familiar.'),
    (29, 3, '2025-10-25', '2026-01-09', 'FINALIZADA', ''),
    (29, 4, '2026-01-19', '2026-02-25', 'FINALIZADA', 'Pendiente valoración médica.'),
    (29, 5, '2026-03-03', '2026-05-12', 'FINALIZADA', 'Requiere apoyo familiar.'),
    (30, 1, '2024-04-26', '2024-07-21', 'FINALIZADA', 'Alta motivación.'),
    (30, 3, '2024-07-30', '2024-09-03', 'FINALIZADA', 'Requiere apoyo familiar.'),
    (30, 4, '2024-09-08', '2024-11-24', 'FINALIZADA', 'Evolución favorable.'),
    (30, 5, '2024-12-04', '2025-01-29', 'FINALIZADA', 'Evolución favorable.'),
    (31, 1, '2024-05-18', '2024-08-02', 'FINALIZADA', ''),
    (31, 3, '2024-08-08', '2024-10-11', 'FINALIZADA', ''),
    (31, 5, '2024-10-20', '2025-01-17', 'FINALIZADA', 'Requiere apoyo familiar.'),
    (32, 1, '2024-06-27', '2024-08-01', 'FINALIZADA', 'Evolución favorable.'),
    (32, 3, '2024-08-04', '2024-09-23', 'FINALIZADA', ''),
    (33, 1, '2025-07-21', '2025-10-19', 'FINALIZADA', 'Evolución favorable.'),
    (33, 3, '2025-10-29', '2025-11-29', 'FINALIZADA', ''),
    (33, 4, '2025-12-04', '2026-02-12', 'FINALIZADA', 'Alta motivación.'),
    (33, 5, '2026-02-21', '2026-05-04', 'FINALIZADA', 'Pendiente valoración médica.'),
    (34, 1, '2024-05-08', '2024-07-24', 'FINALIZADA', 'Alta motivación.'),
    (34, 3, '2024-08-02', NULL, 'EN CURSO', 'Pendiente valoración médica.'),
    (35, 1, '2024-07-05', '2024-09-27', 'FINALIZADA', ''),
    (35, 3, '2024-09-29', '2024-12-24', 'FINALIZADA', 'Evolución favorable.'),
    (35, 5, '2024-12-29', NULL, 'EN CURSO', 'Requiere apoyo familiar.'),
    (36, 1, '2024-12-20', '2025-02-14', 'FINALIZADA', ''),
    (36, 3, '2025-02-19', '2025-04-05', 'FINALIZADA', 'Evolución favorable.'),
    (37, 1, '2025-06-30', '2025-08-08', 'FINALIZADA', 'Evolución favorable.'),
    (37, 3, '2025-08-18', '2025-10-20', 'FINALIZADA', 'Pendiente valoración médica.'),
    (37, 4, '2025-10-21', NULL, 'EN CURSO', ''),
    (38, 1, '2024-09-28', '2024-12-10', 'FINALIZADA', 'Pendiente valoración médica.'),
    (38, 3, '2024-12-11', '2025-03-04', 'FINALIZADA', 'Pendiente valoración médica.'),
    (38, 4, '2025-03-09', '2025-05-06', 'FINALIZADA', 'Evolución favorable.'),
    (39, 1, '2024-10-31', '2024-12-10', 'FINALIZADA', 'Alta motivación.'),
    (39, 3, '2024-12-17', '2025-03-08', 'FINALIZADA', 'Alta motivación.'),
    (39, 4, '2025-03-12', NULL, 'EN CURSO', 'Requiere apoyo familiar.'),
    (40, 1, '2024-12-19', '2025-02-24', 'FINALIZADA', 'Pendiente valoración médica.'),
    (40, 3, '2025-03-05', '2025-04-07', 'FINALIZADA', 'Requiere apoyo familiar.'),
    (40, 5, '2025-04-11', NULL, 'EN CURSO', 'Requiere apoyo familiar.'),
    (41, 1, '2024-09-10', '2024-11-18', 'FINALIZADA', 'Pendiente valoración médica.'),
    (41, 3, '2024-11-25', '2025-01-15', 'FINALIZADA', 'Evolución favorable.'),
    (41, 4, '2025-01-21', '2025-03-22', 'FINALIZADA', 'Evolución favorable.'),
    (41, 5, '2025-03-25', '2025-06-16', 'FINALIZADA', 'Alta motivación.');

    INSERT INTO tb_Diagnostico_CIE10 (codigo_CIE10, nombre_Diagnostico, descripcion) VALUES
    ('F10.20', 'Trastorno por consumo de alcohol, dependencia', 'Patrón problemático con dependencia.'),
    ('F11.20', 'Trastorno por consumo de opioides, dependencia', 'Consumo problemático con dependencia.'),
    ('F12.20', 'Trastorno por consumo de cannabis, dependencia', 'Uso problemático con dependencia.'),
    ('F13.20', 'Trastorno por sedantes o hipnóticos, dependencia', 'Dependencia a benzodiacepinas u otros.'),
    ('F14.20', 'Trastorno por consumo de cocaína, dependencia', 'Uso compulsivo con deterioro significativo.'),
    ('F15.20', 'Trastorno por consumo de estimulantes, dependencia', 'Anfetaminas y otros estimulantes.'),
    ('F16.20', 'Trastorno por consumo de alucinógenos, dependencia', 'Uso persistente de alucinógenos.'),
    ('F17.20', 'Trastorno por consumo de tabaco, dependencia', 'Dependencia a nicotina.'),
    ('F18.20', 'Trastorno por consumo de disolventes, dependencia', 'Inhalantes.'),
    ('F19.20', 'Trastorno por consumo múltiple de drogas, dependencia', 'Policonsumo con dependencia.'),
    ('F32.1', 'Episodio depresivo, moderado', 'Síntomas depresivos de intensidad moderada.'),
    ('F33.2', 'Trastorno depresivo recurrente, grave', 'Episodios repetidos, severos.'),
    ('F41.1', 'Trastorno de ansiedad generalizada', 'Ansiedad excesiva y persistente.'),
    ('F41.0', 'Ataque de pánico (ansiedad paroxística episódica)', 'Crisis de pánico.'),
    ('F20.0', 'Esquizofrenia paranoide', 'Ideas delirantes y alucinaciones auditivas.'),
    ('F23.1', 'Trastorno psicótico agudo polimorfo con síntomas de esquizofrenia', 'Inicio agudo con síntomas variables.'),
    ('F29', 'Psicosis no orgánica no especificada', 'Síntomas psicóticos inespecíficos.'),
    ('F10.10', 'Trastorno por consumo de alcohol, abuso', 'Uso problemático sin criterios completos de dependencia.'),
    ('F12.10', 'Trastorno por consumo de cannabis, abuso', 'Uso problemático.'),
    ('F14.10', 'Trastorno por consumo de cocaína, abuso', 'Uso problemático.'),
    ('F43.1', 'Trastorno de estrés postraumático', 'Síntomas posteriores a evento traumático.'),
    ('F43.2', 'Trastornos de adaptación', 'Respuesta al estrés con síntomas emocionales.');

    INSERT INTO tb_Paciente_Diagnostico (id_Paciente, id_Diagnostico, id_Empleado, fecha_Diagnostico, observaciones) VALUES
    (1, 1, 3, '2025-02-06', 'Co-morbilidad a valorar.'),
    (2, 8, 7, '2025-08-20', 'Se inicia tratamiento farmacológico.'),
    (3, 2, 10, '2025-05-21', 'Co-morbilidad a valorar.'),
    (4, 22, 16, '2024-10-19', 'Co-morbilidad a valorar.'),
    (4, 1, 4, '2025-03-17', 'Plan: terapia + apoyo familiar.'),
    (5, 12, 25, '2025-02-16', 'Se inicia tratamiento farmacológico.'),
    (6, 13, 2, '2025-08-06', 'Co-morbilidad a valorar.'),
    (7, 12, 18, '2024-10-22', ''),
    (8, 17, 15, '2025-07-17', 'Se inicia tratamiento farmacológico.'),
    (9, 22, 20, '2024-05-01', 'Plan: terapia + apoyo familiar.'),
    (9, 4, 13, '2025-01-17', 'Se inicia tratamiento farmacológico.'),
    (10, 12, 25, '2024-05-27', 'Plan: terapia + apoyo familiar.'),
    (10, 20, 17, '2025-02-15', 'Co-morbilidad a valorar.'),
    (11, 2, 2, '2024-05-20', 'Se inicia tratamiento farmacológico.'),
    (12, 17, 15, '2024-06-01', 'Co-morbilidad a valorar.'),
    (13, 5, 11, '2025-09-19', 'Se inicia tratamiento farmacológico.'),
    (13, 6, 13, '2025-09-23', 'Se inicia tratamiento farmacológico.'),
    (14, 11, 17, '2025-06-05', 'Co-morbilidad a valorar.'),
    (14, 16, 23, '2025-07-30', 'Se inicia tratamiento farmacológico.'),
    (15, 1, 12, '2024-12-05', ''),
    (16, 19, 10, '2025-10-06', ''),
    (17, 16, 9, '2025-08-15', 'Co-morbilidad a valorar.'),
    (17, 8, 24, '2024-02-22', 'Co-morbilidad a valorar.'),
    (18, 6, 17, '2025-10-06', 'Co-morbilidad a valorar.'),
    (19, 5, 22, '2024-09-05', ''),
    (20, 4, 7, '2024-01-20', 'Monitoreo semanal en CAID.'),
    (20, 11, 14, '2024-06-04', 'Monitoreo semanal en CAID.'),
    (21, 7, 14, '2025-05-28', 'Co-morbilidad a valorar.'),
    (21, 16, 24, '2024-03-04', 'Plan: terapia + apoyo familiar.'),
    (22, 7, 18, '2024-11-28', 'Monitoreo semanal en CAID.'),
    (22, 17, 13, '2024-11-17', 'Plan: terapia + apoyo familiar.'),
    (23, 18, 11, '2025-07-13', 'Se inicia tratamiento farmacológico.'),
    (24, 22, 21, '2024-09-27', 'Co-morbilidad a valorar.'),
    (24, 16, 7, '2024-09-09', 'Se inicia tratamiento farmacológico.'),
    (25, 10, 8, '2024-10-31', 'Se inicia tratamiento farmacológico.'),
    (25, 7, 23, '2025-05-15', 'Se inicia tratamiento farmacológico.'),
    (26, 12, 18, '2024-10-07', 'Se inicia tratamiento farmacológico.'),
    (27, 19, 22, '2025-07-10', 'Monitoreo semanal en CAID.'),
    (28, 12, 25, '2024-05-29', 'Se inicia tratamiento farmacológico.'),
    (29, 10, 23, '2024-03-21', 'Se inicia tratamiento farmacológico.'),
    (30, 21, 9, '2025-05-05', 'Plan: terapia + apoyo familiar.'),
    (31, 18, 9, '2025-07-29', 'Se inicia tratamiento farmacológico.'),
    (32, 4, 20, '2025-08-23', 'Plan: terapia + apoyo familiar.'),
    (33, 2, 22, '2025-06-27', 'Plan: terapia + apoyo familiar.'),
    (34, 8, 2, '2024-04-12', 'Monitoreo semanal en CAID.'),
    (34, 11, 23, '2025-04-28', ''),
    (35, 5, 1, '2025-07-17', 'Plan: terapia + apoyo familiar.'),
    (35, 14, 21, '2025-05-02', 'Monitoreo semanal en CAID.'),
    (36, 7, 25, '2024-10-21', 'Se inicia tratamiento farmacológico.'),
    (36, 10, 21, '2024-03-01', ''),
    (37, 19, 8, '2025-07-01', ''),
    (37, 6, 14, '2024-06-29', ''),
    (38, 16, 6, '2024-10-23', ''),
    (39, 10, 19, '2025-09-09', ''),
    (40, 10, 15, '2025-10-18', 'Co-morbilidad a valorar.'),
    (41, 16, 5, '2025-05-31', 'Monitoreo semanal en CAID.'),
    (41, 9, 7, '2024-04-25', 'Se inicia tratamiento farmacológico.');

    INSERT INTO tb_Medicamento (nombre_Comercial, nombre_Prospecto, presentacion, dosis, via_Administracion, efectos_Secundarios, Contraindicaciones) VALUES
    ('Clonazepam', 'Clonazepam', 'Tableta 0.5 mg', '0.5 mg', 'Oral', 'Somnolencia, mareo', 'Insuficiencia respiratoria'),
    ('Haloperidol', 'Haloperidol', 'Tableta 5 mg', '5 mg', 'Oral', 'Rigidez, acatisia', 'Parkinsonismo severo'),
    ('Risperidona', 'Risperidona', 'Tableta 2 mg', '2 mg', 'Oral', 'Aumento de peso', 'Hipersensibilidad'),
    ('Olanzapina', 'Olanzapina', 'Tableta 10 mg', '10 mg', 'Oral', 'Sedación, aumento de peso', 'Glaucoma de ángulo estrecho'),
    ('Quetiapina', 'Quetiapina', 'Tableta 100 mg', '100 mg', 'Oral', 'Somnolencia', 'Prolongación QT'),
    ('Sertralina', 'Sertralina', 'Tableta 50 mg', '50 mg', 'Oral', 'Náusea, insomnio', 'IMAO concomitante'),
    ('Fluoxetina', 'Fluoxetina', 'Cápsula 20 mg', '20 mg', 'Oral', 'Ansiedad, náusea', 'IMAO concomitante'),
    ('Diazepam', 'Diazepam', 'Tableta 5 mg', '5 mg', 'Oral', 'Somnolencia', 'Miastenia gravis'),
    ('Acetaminofén', 'Paracetamol', 'Tableta 500 mg', '500 mg', 'Oral', 'Hepatotoxicidad', 'Insuficiencia hepática'),
    ('Tramadol', 'Tramadol', 'Cápsula 50 mg', '50 mg', 'Oral', 'Mareo, náusea', 'Epilepsia no controlada'),
    ('Dexametasona', 'Dexametasona', 'Ampolla 4 mg/mL', '4 mg', 'IV/IM', 'Hiperglucemia', 'Infecciones sistémicas'),
    ('Solución Salina 0.9%', 'Cloruro de sodio', 'Bolsa 500 mL', 'A criterio', 'IV', 'Edema', 'ICC descompensada'),
    ('Loratadina', 'Loratadina', 'Tableta 10 mg', '10 mg', 'Oral', 'Somnolencia', 'Hipersensibilidad'),
    ('Metoclopramida', 'Metoclopramida', 'Ampolla 10 mg/2 mL', '10 mg', 'IM/IV', 'Distonía', 'Feocromocitoma'),
    ('Carbamazepina', 'Carbamazepina', 'Tableta 200 mg', '200 mg', 'Oral', 'Somnolencia', 'Bloqueo AV'),
    ('Valproato', 'Ácido valproico', 'Jarabe 250 mg/5 mL', 'A criterio', 'Oral', 'Hepatotoxicidad', 'Embarazo'),
    ('Lithium', 'Carbonato de litio', 'Tableta 300 mg', '300 mg', 'Oral', 'Temblor, poliuria', 'Insuficiencia renal'),
    ('Biperideno', 'Biperideno', 'Tableta 2 mg', '2 mg', 'Oral', 'Sequedad de boca', 'Glaucoma'),
    ('Ziprasidona', 'Ziprasidona', 'Cápsula 80 mg', '80 mg', 'Oral', 'QT prolongado', 'Cardiopatía QT'),
    ('Sin Tratamiento Farmacológico', 'No aplica', 'N/A', 'N/A', 'N/A', 'N/A', 'Indicada para intervenciones no farmacológicas');

    INSERT INTO tb_Actividad (tipo, subtipo, nombre, fecha, lugar, descripcion, id_Empleado) VALUES
    ('Trabajo Social', 'Visita', 'Entrevista sociofamiliar #1', '2025-08-23', 'Aula 1', 'Enfoque cognitivo-conductual.', 23),
    ('Trabajo Social', 'Visita', 'Entrevista sociofamiliar #2', '2025-01-08', 'Aula 1', 'Enfoque cognitivo-conductual.', 10),
    ('Médica', 'Consulta', 'Consulta médica general #3', '2025-03-31', 'Área Verde', 'Familia invitada.', 14),
    ('Charla', 'Educativa', 'Charla de prevención y recaídas #4', '2025-02-14', 'Consultorio 2', '', 6),
    ('Trabajo Social', 'Visita', 'Entrevista sociofamiliar #5', '2025-09-02', 'Consultorio 1', 'Programa CAID.', 1),
    ('Psiquiatría', 'Consulta', 'Consulta psiquiátrica #6', '2025-07-16', 'Sala Terapia 2', 'Familia invitada.', 25),
    ('Psiquiatría', 'Consulta', 'Consulta psiquiátrica #7', '2025-06-18', 'Consultorio 1', 'Seguimiento semanal.', 24),
    ('Terapia', 'Psicológica', 'Sesión de terapia individual #8', '2025-05-14', 'Aula 1', 'Enfoque cognitivo-conductual.', 23),
    ('Médica', 'Consulta', 'Consulta médica general #9', '2025-02-01', 'Aula 1', '', 15),
    ('Psiquiatría', 'Consulta', 'Consulta psiquiátrica #10', '2025-03-23', 'Consultorio 2', 'Seguimiento semanal.', 23),
    ('Psiquiatría', 'Consulta', 'Consulta psiquiátrica #11', '2025-03-02', 'Aula 1', 'Enfoque cognitivo-conductual.', 12),
    ('Médica', 'Consulta', 'Consulta médica general #12', '2025-04-23', 'Sala Terapia 2', 'Familia invitada.', 5),
    ('Terapia', 'Ocupacional', 'Habilidades para la vida diaria #13', '2025-07-11', 'Consultorio 2', 'Seguimiento semanal.', 16),
    ('Médica', 'Consulta', 'Consulta médica general #14', '2025-05-07', 'Aula 1', 'Seguimiento semanal.', 3),
    ('Terapia', 'Ocupacional', 'Habilidades para la vida diaria #15', '2025-09-28', 'Aula 1', 'Enfoque cognitivo-conductual.', 3),
    ('Terapia', 'Grupal', 'Sesión de terapia grupal #16', '2025-02-01', 'Área Verde', 'Seguimiento semanal.', 7),
    ('Trabajo Social', 'Visita', 'Entrevista sociofamiliar #17', '2025-03-26', 'Consultorio 1', 'Seguimiento semanal.', 15),
    ('Terapia', 'Grupal', 'Sesión de terapia grupal #18', '2025-04-16', 'Aula 1', 'Seguimiento semanal.', 16),
    ('Terapia', 'Grupal', 'Sesión de terapia grupal #19', '2025-09-19', 'Consultorio 2', '', 15),
    ('Trabajo Social', 'Visita', 'Entrevista sociofamiliar #20', '2025-09-20', 'Consultorio 2', 'Familia invitada.', 19),
    ('Terapia', 'Psicológica', 'Sesión de terapia individual #21', '2025-10-14', 'Consultorio 2', 'Enfoque cognitivo-conductual.', 24),
    ('Terapia', 'Psicológica', 'Sesión de terapia individual #22', '2025-07-22', 'Consultorio 1', '', 24),
    ('Médica', 'Consulta', 'Consulta médica general #23', '2025-10-24', 'Sala Terapia 1', '', 14),
    ('Charla', 'Educativa', 'Charla de prevención y recaídas #24', '2025-02-02', 'Área Verde', '', 3),
    ('Terapia', 'Ocupacional', 'Habilidades para la vida diaria #25', '2025-01-17', 'Consultorio 1', 'Familia invitada.', 6),
    ('Trabajo Social', 'Visita', 'Entrevista sociofamiliar #26', '2025-08-04', 'Consultorio 1', 'Familia invitada.', 15),
    ('Ejercicio', 'Físico', 'Actividad física supervisada #27', '2025-07-12', 'Sala Terapia 1', 'Seguimiento semanal.', 5),
    ('Charla', 'Educativa', 'Charla de prevención y recaídas #28', '2025-03-02', 'Sala Terapia 2', 'Seguimiento semanal.', 13),
    ('Trabajo Social', 'Visita', 'Entrevista sociofamiliar #29', '2025-04-25', 'Sala Terapia 1', '', 10),
    ('Terapia', 'Ocupacional', 'Habilidades para la vida diaria #30', '2025-10-06', 'Consultorio 2', 'Seguimiento semanal.', 13),
    ('Médica', 'Consulta', 'Consulta médica general #31', '2025-05-07', 'Consultorio 2', 'Enfoque cognitivo-conductual.', 5),
    ('Psiquiatría', 'Consulta', 'Consulta psiquiátrica #32', '2025-04-07', 'Aula 1', '', 2),
    ('Ejercicio', 'Físico', 'Actividad física supervisada #33', '2025-01-09', 'Sala Terapia 2', 'Programa CAID.', 3),
    ('Terapia', 'Grupal', 'Sesión de terapia grupal #34', '2025-01-18', 'Consultorio 2', 'Seguimiento semanal.', 22),
    ('Terapia', 'Psicológica', 'Sesión de terapia individual #35', '2025-05-06', 'Aula 1', '', 13),
    ('Terapia', 'Ocupacional', 'Habilidades para la vida diaria #36', '2025-04-30', 'Área Verde', 'Programa CAID.', 25),
    ('Terapia', 'Psicológica', 'Sesión de terapia individual #37', '2025-03-13', 'Área Verde', 'Enfoque cognitivo-conductual.', 8),
    ('Charla', 'Educativa', 'Charla de prevención y recaídas #38', '2025-10-23', 'Área Verde', 'Enfoque cognitivo-conductual.', 8),
    ('Psiquiatría', 'Consulta', 'Consulta psiquiátrica #39', '2025-03-15', 'Aula 1', 'Seguimiento semanal.', 8),
    ('Ejercicio', 'Físico', 'Actividad física supervisada #40', '2025-06-03', 'Consultorio 1', '', 18);

    INSERT INTO tb_Paciente_Actividad (id_Paciente, id_Actividad, id_Fase, fecha_Inicio, fecha_Fin, estado, observaciones) VALUES
    (38, 12, 4, '2025-10-12', '2025-10-15', 'COMPLETADA', 'Ausencia justificada.'),
    (25, 34, 3, '2025-08-02', '2025-08-05', 'COMPLETADA', 'Ausencia justificada.'),
    (25, 12, 5, '2025-08-31', '2025-09-01', 'COMPLETADA', 'Ausencia justificada.'),
    (10, 30, 1, '2025-10-15', '2025-10-18', 'EN CURSO', 'Se invita a familiar.'),
    (34, 9, 4, '2025-05-05', '2025-05-07', 'COMPLETADA', 'Ausencia justificada.'),
    (6, 29, 3, '2025-02-17', '2025-02-21', 'SUSPENDIDA', 'Buena participación.'),
    (4, 18, 4, '2025-01-21', '2025-01-21', 'COMPLETADA', 'Se invita a familiar.'),
    (36, 14, 4, '2025-04-17', '2025-04-19', 'EN CURSO', ''),
    (14, 13, 1, '2025-09-03', '2025-09-04', 'SUSPENDIDA', 'Se invita a familiar.'),
    (14, 26, 2, '2025-10-10', '2025-10-12', 'EN CURSO', 'Recomendado reforzar habilidades.'),
    (30, 35, 3, '2025-06-07', '2025-06-09', 'EN CURSO', 'Se invita a familiar.'),
    (32, 30, 1, '2025-08-29', '2025-08-31', 'COMPLETADA', 'Ausencia justificada.'),
    (21, 27, 1, '2025-10-16', '2025-10-17', 'SUSPENDIDA', 'Buena participación.'),
    (2, 17, 5, '2025-10-27', '2025-10-31', 'SUSPENDIDA', 'Recomendado reforzar habilidades.'),
    (19, 10, 2, '2025-06-18', '2025-06-19', 'EN CURSO', 'Se invita a familiar.'),
    (16, 32, 5, '2025-06-22', '2025-06-24', 'EN CURSO', 'Recomendado reforzar habilidades.'),
    (30, 11, 3, '2025-03-28', '2025-03-29', 'SUSPENDIDA', 'Se invita a familiar.'),
    (32, 12, 5, '2025-01-31', '2025-02-04', 'COMPLETADA', ''),
    (4, 1, 4, '2025-03-12', '2025-03-17', 'COMPLETADA', ''),
    (10, 1, 2, '2025-09-16', '2025-09-19', 'EN CURSO', ''),
    (40, 40, 4, '2025-09-07', '2025-09-07', 'COMPLETADA', 'Se invita a familiar.'),
    (36, 27, 1, '2025-01-09', '2025-01-13', 'SUSPENDIDA', 'Ausencia justificada.'),
    (35, 19, 1, '2025-09-15', '2025-09-20', 'SUSPENDIDA', 'Recomendado reforzar habilidades.'),
    (12, 7, 1, '2025-09-26', '2025-09-27', 'COMPLETADA', 'Buena participación.'),
    (40, 34, 3, '2025-07-01', '2025-07-03', 'EN CURSO', ''),
    (24, 26, 4, '2025-10-17', '2025-10-18', 'SUSPENDIDA', 'Buena participación.'),
    (20, 6, 1, '2025-02-17', '2025-02-20', 'EN CURSO', 'Recomendado reforzar habilidades.'),
    (36, 31, 1, '2025-01-05', '2025-01-10', 'COMPLETADA', ''),
    (32, 28, 3, '2025-10-17', '2025-10-17', 'SUSPENDIDA', ''),
    (15, 14, 5, '2025-09-01', '2025-09-03', 'COMPLETADA', ''),
    (18, 35, 5, '2025-01-17', '2025-01-18', 'EN CURSO', ''),
    (14, 38, 2, '2025-07-23', '2025-07-23', 'EN CURSO', 'Buena participación.'),
    (37, 16, 5, '2025-07-19', '2025-07-24', 'SUSPENDIDA', 'Ausencia justificada.'),
    (25, 9, 1, '2025-09-14', '2025-09-19', 'EN CURSO', ''),
    (7, 28, 2, '2025-02-08', '2025-02-10', 'SUSPENDIDA', 'Se invita a familiar.'),
    (39, 26, 3, '2025-01-16', '2025-01-21', 'EN CURSO', 'Recomendado reforzar habilidades.'),
    (32, 15, 3, '2025-10-11', '2025-10-14', 'EN CURSO', 'Buena participación.'),
    (38, 25, 1, '2025-06-01', '2025-06-02', 'SUSPENDIDA', ''),
    (6, 18, 2, '2025-07-14', '2025-07-19', 'SUSPENDIDA', 'Buena participación.'),
    (25, 21, 3, '2025-02-24', '2025-02-24', 'COMPLETADA', 'Ausencia justificada.'),
    (29, 24, 3, '2025-02-22', '2025-02-23', 'COMPLETADA', 'Buena participación.'),
    (28, 29, 5, '2025-10-12', '2025-10-16', 'EN CURSO', ''),
    (2, 6, 3, '2025-10-11', '2025-10-11', 'SUSPENDIDA', 'Se invita a familiar.'),
    (21, 25, 1, '2025-05-30', '2025-06-02', 'EN CURSO', ''),
    (36, 16, 5, '2025-09-24', '2025-09-25', 'SUSPENDIDA', 'Recomendado reforzar habilidades.'),
    (11, 9, 3, '2025-06-04', '2025-06-06', 'EN CURSO', 'Buena participación.'),
    (5, 11, 4, '2025-05-22', '2025-05-25', 'EN CURSO', 'Recomendado reforzar habilidades.'),
    (5, 24, 3, '2025-05-07', '2025-05-12', 'SUSPENDIDA', 'Recomendado reforzar habilidades.'),
    (39, 40, 2, '2025-08-23', '2025-08-23', 'COMPLETADA', 'Ausencia justificada.'),
    (1, 26, 3, '2025-07-14', '2025-07-16', 'EN CURSO', 'Ausencia justificada.'),
    (28, 39, 2, '2025-06-03', '2025-06-05', 'SUSPENDIDA', 'Buena participación.'),
    (31, 21, 2, '2025-07-23', '2025-07-25', 'EN CURSO', 'Recomendado reforzar habilidades.'),
    (18, 26, 3, '2025-02-28', '2025-03-04', 'COMPLETADA', 'Se invita a familiar.'),
    (35, 12, 5, '2025-01-14', '2025-01-19', 'EN CURSO', 'Buena participación.'),
    (29, 19, 1, '2025-07-29', '2025-08-03', 'EN CURSO', 'Buena participación.'),
    (41, 20, 2, '2025-05-10', '2025-05-15', 'COMPLETADA', 'Recomendado reforzar habilidades.'),
    (25, 5, 4, '2025-09-03', '2025-09-07', 'EN CURSO', 'Se invita a familiar.'),
    (33, 27, 5, '2025-01-19', '2025-01-21', 'SUSPENDIDA', 'Se invita a familiar.'),
    (39, 6, 1, '2025-05-08', '2025-05-13', 'SUSPENDIDA', 'Ausencia justificada.'),
    (11, 40, 1, '2025-10-16', '2025-10-21', 'SUSPENDIDA', 'Recomendado reforzar habilidades.'),
    (22, 28, 1, '2025-01-06', '2025-01-06', 'EN CURSO', 'Buena participación.'),
    (33, 34, 5, '2025-10-25', '2025-10-30', 'SUSPENDIDA', 'Buena participación.'),
    (26, 30, 5, '2025-09-14', '2025-09-15', 'EN CURSO', ''),
    (31, 7, 3, '2025-08-01', '2025-08-01', 'COMPLETADA', 'Buena participación.'),
    (23, 20, 3, '2025-08-22', '2025-08-23', 'SUSPENDIDA', 'Recomendado reforzar habilidades.'),
    (23, 31, 1, '2025-08-13', '2025-08-18', 'SUSPENDIDA', 'Recomendado reforzar habilidades.'),
    (21, 5, 3, '2025-01-23', '2025-01-28', 'COMPLETADA', ''),
    (22, 7, 2, '2025-05-05', '2025-05-09', 'COMPLETADA', 'Se invita a familiar.'),
    (11, 22, 5, '2025-08-07', '2025-08-10', 'COMPLETADA', 'Recomendado reforzar habilidades.'),
    (41, 12, 2, '2025-08-10', '2025-08-13', 'COMPLETADA', 'Se invita a familiar.'),
    (13, 29, 5, '2025-08-08', '2025-08-11', 'COMPLETADA', 'Buena participación.'),
    (14, 18, 1, '2025-10-23', '2025-10-23', 'SUSPENDIDA', 'Buena participación.'),
    (24, 21, 2, '2025-08-23', '2025-08-23', 'EN CURSO', 'Recomendado reforzar habilidades.'),
    (34, 21, 5, '2025-07-18', '2025-07-22', 'EN CURSO', 'Se invita a familiar.'),
    (8, 23, 3, '2025-08-23', '2025-08-27', 'COMPLETADA', 'Ausencia justificada.'),
    (40, 38, 1, '2025-03-10', '2025-03-12', 'COMPLETADA', 'Buena participación.'),
    (20, 8, 2, '2025-07-11', '2025-07-16', 'COMPLETADA', 'Se invita a familiar.'),
    (25, 27, 5, '2025-03-12', '2025-03-16', 'EN CURSO', 'Recomendado reforzar habilidades.'),
    (12, 32, 5, '2025-03-30', '2025-04-03', 'COMPLETADA', 'Recomendado reforzar habilidades.'),
    (19, 9, 2, '2025-06-11', '2025-06-14', 'SUSPENDIDA', '');

    INSERT INTO tb_Paciente_Actividad_Medicamento (id_Paciente, id_Actividad, id_Medicamento, dosis, frecuencia, duracion, observaciones) VALUES
    (23, 1, 7, '20 mg', 'noche', 'PRN', 'Vigilar efectos secundarios.'),
    (32, 27, 15, '200 mg', 'noche', '14 días', ''),
    (37, 2, 8, '5 mg', 'cada 24 h', '7 días', 'Vigilar efectos secundarios.'),
    (15, 35, 20, 'N/A', 'N/A', 'N/A', 'Intervención no farmacológica.'),
    (30, 37, 16, 'A criterio', 'cada 8 h', '7 días', 'Vigilar efectos secundarios.'),
    (35, 24, 2, '5 mg', 'noche', '14 días', 'Vigilar efectos secundarios.'),
    (7, 16, 20, 'N/A', 'N/A', 'N/A', 'Intervención no farmacológica.'),
    (3, 29, 20, 'N/A', 'N/A', 'N/A', 'Intervención no farmacológica.'),
    (6, 29, 4, '10 mg', 'cada 12 h', '14 días', 'Revisión en próxima consulta.'),
    (38, 23, 14, '10 mg', 'cada 12 h', '14 días', ''),
    (14, 4, 18, '2 mg', 'cada 24 h', '14 días', 'Vigilar efectos secundarios.'),
    (19, 19, 17, '300 mg', 'cada 8 h', '14 días', 'Vigilar efectos secundarios.'),
    (4, 18, 5, '100 mg', 'cada 12 h', '14 días', ''),
    (21, 16, 13, '10 mg', 'noche', '14 días', 'Revisión en próxima consulta.'),
    (41, 18, 13, '10 mg', 'noche', '7 días', 'Revisión en próxima consulta.'),
    (6, 26, 9, '500 mg', 'cada 24 h', 'PRN', 'Vigilar efectos secundarios.'),
    (21, 38, 20, 'N/A', 'N/A', 'N/A', 'Intervención no farmacológica.'),
    (6, 30, 12, 'A criterio', 'cada 8 h', 'PRN', ''),
    (28, 14, 11, '4 mg', 'cada 24 h', '1 mes', 'Revisión en próxima consulta.'),
    (37, 9, 16, 'A criterio', 'cada 24 h', '7 días', ''),
    (7, 30, 20, 'N/A', 'N/A', 'N/A', 'Intervención no farmacológica.'),
    (11, 29, 14, '10 mg', 'cada 12 h', '14 días', 'Revisión en próxima consulta.'),
    (20, 11, 9, '500 mg', 'cada 8 h', '1 mes', 'Vigilar efectos secundarios.'),
    (6, 24, 6, '50 mg', 'cada 8 h', 'PRN', 'Revisión en próxima consulta.'),
    (20, 15, 3, '2 mg', 'cada 8 h', '7 días', ''),
    (31, 5, 20, 'N/A', 'N/A', 'N/A', 'Intervención no farmacológica.'),
    (15, 34, 1, '0.5 mg', 'cada 8 h', '1 mes', ''),
    (28, 9, 8, '5 mg', 'noche', '7 días', 'Revisión en próxima consulta.'),
    (7, 7, 10, '50 mg', 'cada 12 h', 'PRN', ''),
    (10, 5, 1, '0.5 mg', 'cada 12 h', 'PRN', 'Vigilar efectos secundarios.'),
    (14, 10, 15, '200 mg', 'cada 12 h', '7 días', ''),
    (9, 8, 13, '10 mg', 'cada 24 h', 'PRN', 'Vigilar efectos secundarios.'),
    (9, 16, 20, 'N/A', 'N/A', 'N/A', 'Intervención no farmacológica.'),
    (6, 16, 10, '50 mg', 'cada 8 h', '1 mes', ''),
    (34, 39, 13, '10 mg', 'cada 24 h', '7 días', ''),
    (32, 25, 20, 'N/A', 'N/A', 'N/A', 'Intervención no farmacológica.'),
    (32, 39, 20, 'N/A', 'N/A', 'N/A', 'Intervención no farmacológica.'),
    (1, 24, 5, '100 mg', 'noche', 'PRN', 'Vigilar efectos secundarios.'),
    (35, 12, 3, '2 mg', 'cada 8 h', '7 días', ''),
    (17, 14, 20, 'N/A', 'N/A', 'N/A', 'Intervención no farmacológica.'),
    (4, 26, 17, '300 mg', 'noche', 'PRN', 'Revisión en próxima consulta.');

    INSERT INTO tb_Persona_Actividad (id_Persona, id_Actividad, rol, observaciones) VALUES
    (52, 6, 'FAMILIAR', 'Observador.'),
    (11, 20, 'PACIENTE', 'Participación activa.'),
    (20, 35, 'CUIDADOR', 'Primera vez.'),
    (76, 5, 'CUIDADOR', 'Primera vez.'),
    (31, 4, 'FAMILIAR', ''),
    (56, 8, 'STAFF', ''),
    (40, 12, 'PACIENTE', ''),
    (18, 1, 'FAMILIAR', 'Primera vez.'),
    (45, 34, 'CUIDADOR', 'Participación activa.'),
    (48, 9, 'CUIDADOR', ''),
    (4, 22, 'STAFF', 'Observador.'),
    (68, 5, 'CUIDADOR', ''),
    (64, 30, 'CUIDADOR', ''),
    (64, 37, 'FAMILIAR', 'Observador.'),
    (21, 17, 'PACIENTE', ''),
    (30, 33, 'PACIENTE', ''),
    (2, 16, 'PACIENTE', 'Primera vez.'),
    (47, 25, 'FAMILIAR', 'Participación activa.'),
    (5, 36, 'STAFF', 'Participación activa.'),
    (42, 16, 'STAFF', 'Observador.'),
    (35, 5, 'CUIDADOR', ''),
    (65, 4, 'FAMILIAR', 'Participación activa.'),
    (67, 3, 'STAFF', ''),
    (60, 19, 'CUIDADOR', 'Observador.'),
    (12, 36, 'STAFF', ''),
    (48, 13, 'CUIDADOR', 'Observador.'),
    (80, 16, 'STAFF', 'Observador.'),
    (76, 32, 'FAMILIAR', 'Participación activa.'),
    (20, 1, 'STAFF', ''),
    (30, 35, 'CUIDADOR', ''),
    (43, 1, 'STAFF', 'Observador.'),
    (14, 14, 'FAMILIAR', 'Primera vez.'),
    (63, 4, 'FAMILIAR', 'Observador.'),
    (12, 3, 'FAMILIAR', 'Primera vez.'),
    (48, 30, 'PACIENTE', ''),
    (65, 9, 'STAFF', ''),
    (76, 37, 'PACIENTE', 'Primera vez.'),
    (17, 16, 'CUIDADOR', 'Observador.'),
    (41, 26, 'CUIDADOR', 'Observador.'),
    (58, 18, 'FAMILIAR', ''),
    (26, 9, 'PACIENTE', 'Participación activa.'),
    (14, 11, 'STAFF', 'Primera vez.'),
    (41, 27, 'PACIENTE', 'Observador.'),
    (27, 29, 'CUIDADOR', 'Primera vez.'),
    (34, 8, 'PACIENTE', 'Participación activa.'),
    (39, 39, 'PACIENTE', 'Participación activa.'),
    (42, 10, 'PACIENTE', 'Participación activa.'),
    (46, 26, 'PACIENTE', 'Observador.'),
    (34, 12, 'PACIENTE', 'Primera vez.'),
    (58, 36, 'FAMILIAR', ''),
    (60, 7, 'FAMILIAR', ''),
    (2, 4, 'FAMILIAR', 'Participación activa.'),
    (26, 26, 'CUIDADOR', ''),
    (75, 38, 'CUIDADOR', ''),
    (3, 5, 'FAMILIAR', 'Primera vez.'),
    (17, 6, 'CUIDADOR', ''),
    (6, 30, 'PACIENTE', 'Participación activa.'),
    (74, 28, 'STAFF', 'Primera vez.'),
    (4, 25, 'STAFF', 'Participación activa.'),
    (46, 14, 'FAMILIAR', 'Observador.'),
    (36, 29, 'FAMILIAR', ''),
    (79, 40, 'FAMILIAR', 'Observador.'),
    (64, 27, 'STAFF', ''),
    (12, 18, 'STAFF', 'Participación activa.'),
    (54, 13, 'FAMILIAR', ''),
    (49, 23, 'STAFF', 'Primera vez.'),
    (45, 37, 'CUIDADOR', 'Primera vez.'),
    (35, 12, 'PACIENTE', 'Observador.'),
    (77, 15, 'PACIENTE', 'Observador.'),
    (8, 31, 'CUIDADOR', 'Participación activa.'),
    (21, 7, 'FAMILIAR', 'Participación activa.'),
    (35, 35, 'PACIENTE', 'Participación activa.'),
    (74, 25, 'CUIDADOR', 'Participación activa.'),
    (23, 16, 'CUIDADOR', 'Observador.'),
    (76, 2, 'CUIDADOR', 'Participación activa.'),
    (73, 13, 'STAFF', 'Observador.'),
    (23, 32, 'PACIENTE', ''),
    (8, 15, 'FAMILIAR', ''),
    (68, 31, 'PACIENTE', 'Observador.'),
    (79, 13, 'FAMILIAR', 'Observador.');

    PRINT 'Carga de datos del proyecto completada exitosamente.';
END;
GO

/* Ejecuta procedimientos almacenados */

EXEC dbo.sp_Cargar_DistElec_Base
EXEC dbo.sp_Cargar_Padron_Base 
EXEC dbo.sp_Normalizar_TSE
EXEC sp_Cargar_Telefonos_General
EXEC sp_Cargar_Telefonos_General_V2_Cursor
EXEC sp_Insertar_Datos_Proyecto
