--Lucas Botelho a22201202
--Tiago Mota a22207337
--Marcos Gil a22102606
--Gon�alo Neves a22204044
USE tfc;

--start Q1
--Esta funcao devolve os os ids de grupo que deixaram de existir em Inscricao porque foram movidos e mapeados na tabela TFC
go
CREATE FUNCTION dbo.GetGroupIdForTFC ()
RETURNS INT
AS
BEGIN
    DECLARE @GroupId INT;

    SELECT TOP 1 @GroupId = TFC.idGrupo
    FROM TFC
    WHERE TFC.idGrupo IS NULL
        AND EXISTS (SELECT 1 FROM Inscricao WHERE Inscricao.idTFC = TFC.idtfc AND idNumeroGrupo IS NOT NULL);

    RETURN @GroupId;
END;
go

SELECT dbo.GetGroupIdForTFC() AS Result;
--end Q1

---- start Q2 -> Candidaturas ordenadas
GO
CREATE OR ALTER FUNCTION dbo.Q2FunctionCalculaMedia(@idNumeroAluno bigint)
RETURNS DECIMAL(10, 2) 
AS
BEGIN
    DECLARE @avgNota DECIMAL(10, 2);

    SELECT @avgNota = AVG(nota)
    FROM AvaliacaoDisciplinaAluno 
    WHERE idNumeroAluno = @idNumeroAluno;

    RETURN ISNULL(@avgNota, 0);
END;
GO
CREATE OR ALTER FUNCTION dbo.Q2Function(@tema varchar(255))
RETURNS TABLE
AS
RETURN
    SELECT 
        M.*,
        CalculatedMedia.AverageNota
    FROM (
        SELECT DISTINCT 
            @tema AS 'TFC', 
            IDAluno,
			NRAluno,
            FIRST_VALUE(OrdemEscolha) OVER(PARTITION BY IDAluno ORDER BY (SELECT NULL)) AS 'Ordem escolha',
            FIRST_VALUE(RegistoInscricao) OVER(PARTITION BY IDAluno ORDER BY (SELECT NULL)) AS 'Registo inscricao',
            FIRST_VALUE(Orientador) OVER(PARTITION BY IDAluno ORDER BY (SELECT NULL)) AS 'Orientador'
        FROM (
            SELECT 
                @tema AS LiteralColumnName, 
				aluno.id AS 'IDAluno',
                grupo.idNumeroAluno1 AS 'NRAluno', 
                inscricao.ordemEscolha AS 'OrdemEscolha',
                inscricao.registoDeInscricao AS 'RegistoInscricao',
                professorDEISI.nome AS 'Orientador'
            FROM TFC AS tfcTema
            INNER JOIN Grupo AS grupo ON tfcTema.idGrupo = grupo.id
			INNER JOIN Aluno AS aluno ON grupo.idNumeroAluno1 = aluno.numeroAluno
            INNER JOIN Inscricao AS inscricao ON grupo.id = inscricao.idNumeroGrupo
            INNER JOIN ProfessorDEISI AS professorDEISI ON tfcTema.orientador = professorDEISI.numeroProfessor
            WHERE tfcTema.Titulo LIKE '%' + @tema + '%'

            UNION ALL

            SELECT 
                @tema AS LiteralColumnName, 
                aluno.id AS 'IDAluno',
                grupo.idNumeroAluno1 AS 'NRAluno', 
                inscricao.ordemEscolha AS 'OrdemEscolha',
                inscricao.registoDeInscricao AS 'RegistoInscricao',
                professorDEISI.nome AS 'Orientador'
            FROM TFC AS tfcTema
            INNER JOIN Grupo AS grupo ON tfcTema.idGrupo = grupo.id
			INNER JOIN Aluno AS aluno ON grupo.idNumeroAluno2 = aluno.numeroAluno
            INNER JOIN Inscricao AS inscricao ON grupo.id = inscricao.idNumeroGrupo
            INNER JOIN ProfessorDEISI AS professorDEISI ON tfcTema.orientador = professorDEISI.numeroProfessor
            WHERE tfcTema.Titulo LIKE '%' + @tema + '%'
        ) AS MergeQuery
    ) AS M
    CROSS APPLY (
        SELECT dbo.Q2FunctionCalculaMedia(M.IDAluno) AS AverageNota
    ) AS CalculatedMedia;
GO

CREATE OR ALTER VIEW Q2 AS
    SELECT * FROM dbo.Q2Function('MyCinemaWorld');
GO

SELECT * FROM dbo.Q2;
GO
--end Q2

-----start Q3 -> Lista temas atribu�dos 
GO
CREATE OR ALTER VIEW Q3 AS
SELECT idTfc as id,
    ProfessorDEISI.nome AS NomeProfessor,
    Aluno1.nome AS NomeAluno,
    TFC.anoletivo,
    TFC.titulo
FROM TFC
INNER JOIN ProfessorDEISI ON TFC.orientador = ProfessorDEISI.numeroProfessor
LEFT JOIN Grupo ON TFC.idGrupo = Grupo.id
LEFT JOIN Aluno AS Aluno1 ON Grupo.idNumeroAluno1 = Aluno1.numeroAluno
WHERE TFC.idGrupo IS NOT NULL
    AND TFC.estado = 4

UNION

SELECT  idTfc as id,
    ProfessorDEISI.nome AS NomeProfessor,
    Aluno2.nome AS NomeAluno,
    TFC.anoletivo,
    TFC.titulo
FROM TFC
INNER JOIN ProfessorDEISI ON TFC.orientador = ProfessorDEISI.numeroProfessor
LEFT JOIN Grupo ON TFC.idGrupo = Grupo.id
LEFT JOIN Aluno AS Aluno2 ON Grupo.idNumeroAluno2 = Aluno2.numeroAluno 
WHERE TFC.idGrupo IS NOT NULL
    AND Grupo.idNumeroAluno2 IS NOT NULL
    AND TFC.estado = 4;
GO


SELECT * FROM Q3 WHERE anoletivo = 2018 --41
SELECT * FROM Q3 WHERE anoletivo != 2018 --0
--- end Q3

--start Q4
SELECT ProfessorDEISI.nome AS docente,
       TFC.Titulo AS TFC,
       TFC.titulo AS t�tulo,
       Aluno.nome AS aluno
FROM TFC
JOIN ProfessorDEISI ON TFC.preponente = ProfessorDEISI.numeroProfessor AND TFC.estado = 4
JOIN Grupo ON TFC.idGrupo = Grupo.id
JOIN Aluno ON Aluno.numeroAluno = Grupo.idNumeroAluno1 OR Aluno.numeroAluno = Grupo.idNumeroAluno2;

--end Q4

--start q6
select distinct * from EstadoTFC

GO
CREATE OR ALTER VIEW Q6 AS
SELECT
    TFC.idtfc AS idTFC,
    TFC.titulo,
    Aluno.nome AS candidato,
    Inscricao.ordemEscolha,
    Inscricao.registoDeInscricao,
    TFC.orientador
FROM
    TFC
LEFT JOIN
    Grupo ON TFC.idGrupo = Grupo.id
LEFT JOIN
    Aluno ON Grupo.idNumeroAluno1 = Aluno.numeroAluno OR Grupo.idNumeroAluno2 = Aluno.numeroAluno
LEFT JOIN
    Inscricao ON TFC.idTFC = Inscricao.idTFC
WHERE
    TFC.estado = 3 -- Garante que o tema n�o foi atribu�do
    AND Inscricao.estado = 3
GO

SELECT * FROM Q6
--end	  q6


--start Q8
SELECT
    'TFC' AS tabela,
    'alteracao' AS alteracao,
    TFC.estado AS estado,
    HistoricoTFC.dataMudancaEstado AS data,
    HistoricoTFC.utilizador AS utilizador
FROM
    HistoricoTFC
INNER JOIN TFC ON HistoricoTFC.idTFC = TFC.idtfc
WHERE
    TFC.idtfc = 'IDTFC%'  
ORDER BY
    HistoricoTFC.dataMudancaEstado DESC;

--end Q8

--start Q9
SELECT
    P.nome AS NomeDocente,
    P.email AS EmailDocente,
    P.numeroContato AS NumeroContatoDocente,
    COUNT(TFC.id) AS QuantidadeOrientacoes
FROM
    ProfessorDEISI P
LEFT JOIN TFC ON P.numeroProfessor = TFC.orientador OR P.numeroProfessor = TFC.coorientador
GROUP BY
    P.nome, P.email, P.numeroContato
ORDER BY
    QuantidadeOrientacoes DESC, NomeDocente;

--end Q9

--start Q13

    SELECT Aluno1.nome as Nome_Aluno1, Aluno1.nome as Nome_Aluno2
    FROM Grupo G
    LEFT JOIN Aluno Aluno1 ON G.idNumeroAluno1 = Aluno1.numeroAluno
    LEFT JOIN Aluno Aluno2 ON G.idNumeroAluno2 = Aluno2.numeroAluno
    WHERE G.id = 10;


--end Q13

--start Q14
SELECT 
    CASE 
        WHEN TFC.estado = 4 THEN Aluno1.nome
        ELSE NULL
    END AS nomeAluno1,
    CASE 
        WHEN TFC.estado = 4 THEN Aluno2.nome
        ELSE NULL
    END AS nomeAluno2
FROM 
    TFC
LEFT JOIN 
    Grupo G ON TFC.idGrupo = G.id
LEFT JOIN 
    Aluno Aluno1 ON G.idNumeroAluno1 = Aluno1.numeroAluno
LEFT JOIN 
    Aluno Aluno2 ON G.idNumeroAluno2 = Aluno2.numeroAluno
WHERE 
    TFC.idtfc = 'Aluno67';
--end Q14

