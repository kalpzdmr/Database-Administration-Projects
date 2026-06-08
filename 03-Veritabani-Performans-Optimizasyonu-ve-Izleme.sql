/* =========================================================
   1) VERİTABANI SEÇİMİ
   ========================================================= */

USE WideWorldImporters;
GO


/* =========================================================
   2) EN BÜYÜK TABLOLARI LİSTELEME
   ========================================================= */

SELECT TOP 10
    s.name AS SchemaName,
    t.name AS TableName,
    p.rows AS TotalRows
FROM sys.tables t
INNER JOIN sys.schemas s 
    ON t.schema_id = s.schema_id
INNER JOIN sys.partitions p 
    ON t.object_id = p.object_id
WHERE p.index_id IN (0,1)
ORDER BY p.rows DESC;

/* =========================================================
   3) ANALİZ YAPILACAK TABLONUN KOLONLARINI İNCELEME
   ========================================================= */

USE WideWorldImporters;
GO

SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'Warehouse'
  AND TABLE_NAME = 'ColdRoomTemperatures_Archive';

  /* =========================================================
   4) INDEX ÖNCESİ YAVAŞ SORGU TESTİ
   ========================================================= */

USE WideWorldImporters;
GO

SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

SELECT *
FROM Warehouse.ColdRoomTemperatures_Archive
WHERE RecordedWhen BETWEEN '2014-01-01' AND '2015-12-31';
GO

/* =========================================================
   5) RECORDEDWHEN KOLONU ÜZERİNE INDEX OLUŞTURMA
   ========================================================= */

USE WideWorldImporters;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_ColdRoomTemperatures_RecordedWhen'
      AND object_id = OBJECT_ID('Warehouse.ColdRoomTemperatures_Archive')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_ColdRoomTemperatures_RecordedWhen
    ON Warehouse.ColdRoomTemperatures_Archive (RecordedWhen);
END;
GO

/* =========================================================
   6) INDEX SONRASI PERFORMANS TESTİ
   ========================================================= */

USE WideWorldImporters;
GO

SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

SELECT *
FROM Warehouse.ColdRoomTemperatures_Archive
WHERE RecordedWhen BETWEEN '2014-01-01' AND '2015-12-31';
GO

/* =========================================================
   7) SELECT * YERİNE GEREKLİ KOLONLARIN SEÇİLMESİ
   ========================================================= */

USE WideWorldImporters;
GO

SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

SELECT 
    ColdRoomTemperatureID,
    RecordedWhen,
    Temperature
FROM Warehouse.ColdRoomTemperatures_Archive
WHERE RecordedWhen BETWEEN '2014-01-01' AND '2015-12-31';
GO

/* =========================================================
   8) EXECUTION PLAN ANALİZİ İÇİN SORGU
   ========================================================= */

USE WideWorldImporters;
GO

SELECT 
    ColdRoomTemperatureID,
    RecordedWhen,
    Temperature
FROM Warehouse.ColdRoomTemperatures_Archive
WHERE RecordedWhen BETWEEN '2014-01-01' AND '2015-12-31';
GO

/* =========================================================
   9) DMV İLE PAHALI SORGULARIN İZLENMESİ
   ========================================================= */

USE WideWorldImporters;
GO

SELECT TOP 10
    qs.execution_count AS CalismaSayisi,
    qs.total_worker_time / qs.execution_count AS OrtalamaCPU,
    qs.total_elapsed_time / qs.execution_count AS OrtalamaSure,
    qs.total_logical_reads / qs.execution_count AS OrtalamaOkuma,
    SUBSTRING(qt.text,
        (qs.statement_start_offset / 2) + 1,
        ((CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(qt.text)
            ELSE qs.statement_end_offset
        END - qs.statement_start_offset) / 2) + 1
    ) AS SorguMetni
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
ORDER BY OrtalamaSure DESC;
GO

/* =========================================================
   10) MISSING INDEX ANALİZİ
   ========================================================= */

USE WideWorldImporters;
GO

SELECT TOP 10
    migs.avg_total_user_cost AS OrtalamaMaliyet,
    migs.avg_user_impact AS TahminiEtkiYuzdesi,
    mid.statement AS TabloAdi,
    mid.equality_columns AS EsitlikKolonlari,
    mid.inequality_columns AS AralikKolonlari,
    mid.included_columns AS DahilEdilecekKolonlar
FROM sys.dm_db_missing_index_group_stats migs
INNER JOIN sys.dm_db_missing_index_groups mig
    ON migs.group_handle = mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details mid
    ON mig.index_handle = mid.index_handle
WHERE mid.database_id = DB_ID()
ORDER BY migs.avg_user_impact DESC;
GO

/* =========================================================
   11) TABLO BOYUTU VE DISK KULLANIM ANALİZİ
   ========================================================= */

USE WideWorldImporters;
GO

EXEC sp_spaceused 'Warehouse.ColdRoomTemperatures_Archive';
GO

/* =========================================================
   12) TABLO ÜZERİNDEKİ INDEXLERİ LİSTELEME
   ========================================================= */

USE WideWorldImporters;
GO

SELECT 
    i.name AS IndexName,
    i.type_desc AS IndexType,
    c.name AS ColumnName
FROM sys.indexes i
INNER JOIN sys.index_columns ic
    ON i.object_id = ic.object_id
    AND i.index_id = ic.index_id
INNER JOIN sys.columns c
    ON ic.object_id = c.object_id
    AND ic.column_id = c.column_id
WHERE OBJECT_NAME(i.object_id) = 'ColdRoomTemperatures_Archive';
GO

/* =========================================================
   13) KULLANICI VE ROL YÖNETİMİ
   ========================================================= */

/* LOGIN OLUŞTURMA */
USE master;
GO

IF NOT EXISTS (
    SELECT * 
    FROM sys.server_principals
    WHERE name = 'PerfUser'
)
BEGIN
    CREATE LOGIN PerfUser
    WITH PASSWORD = 'Perf123!';
END;
GO


/* VERİTABANI KULLANICISI OLUŞTURMA */
USE WideWorldImporters;
GO

IF NOT EXISTS (
    SELECT * 
    FROM sys.database_principals
    WHERE name = 'PerfUser'
)
BEGIN
    CREATE USER PerfUser
    FOR LOGIN PerfUser;
END;
GO


/* OKUMA YETKİSİ VERME */
ALTER ROLE db_datareader
ADD MEMBER PerfUser;
GO


/* YETKİ TESTİ */
EXECUTE AS USER = 'PerfUser';

SELECT TOP 5 *
FROM Sales.Orders;

REVERT;
GO
