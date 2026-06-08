/* =========================================================
   VERİTABANI GÜVENLİĞİ VE ERİŞİM KONTROLÜ PROJESİ
   Dataset: WideWorldImporters
   ========================================================= */

USE WideWorldImporters;
GO

/* =========================================================
   1) ÖNCEKİ NESNELERİ TEMİZLEME
   ========================================================= */

IF USER_ID('guvenlik_kullanici') IS NOT NULL
DROP USER guvenlik_kullanici;
GO

IF DATABASE_PRINCIPAL_ID('satis_okuma_rolu') IS NOT NULL
DROP ROLE satis_okuma_rolu;
GO

IF OBJECT_ID('dbo.MusteriGuvenlikTest', 'U') IS NOT NULL
DROP TABLE dbo.MusteriGuvenlikTest;
GO

IF OBJECT_ID('dbo.SecurityAuditLog', 'U') IS NOT NULL
DROP TABLE dbo.SecurityAuditLog;
GO

IF OBJECT_ID('dbo.vw_MusteriMaskeli', 'V') IS NOT NULL
DROP VIEW dbo.vw_MusteriMaskeli;
GO

USE master;
GO

IF EXISTS (
    SELECT * 
    FROM sys.server_principals 
    WHERE name = 'guvenlik_kullanici'
)
DROP LOGIN guvenlik_kullanici;
GO

/* =========================================================
   2) LOGIN OLUŞTURMA
   ========================================================= */

CREATE LOGIN guvenlik_kullanici
WITH PASSWORD = 'Guvenlik123!';
GO

/* =========================================================
   3) DATASETTEN TEST TABLOSU OLUŞTURMA
   ========================================================= */

USE WideWorldImporters;
GO

SELECT TOP 20
    CustomerID,
    CustomerName,
    PhoneNumber,
    WebsiteURL
INTO dbo.MusteriGuvenlikTest
FROM Sales.Customers;
GO

SELECT * FROM dbo.MusteriGuvenlikTest;
GO

/* =========================================================
   4) DATABASE USER VE ROLE OLUŞTURMA
   ========================================================= */

CREATE USER guvenlik_kullanici
FOR LOGIN guvenlik_kullanici;
GO

CREATE ROLE satis_okuma_rolu;
GO

GRANT SELECT ON dbo.MusteriGuvenlikTest TO satis_okuma_rolu;
GO

ALTER ROLE satis_okuma_rolu
ADD MEMBER guvenlik_kullanici;
GO

/* =========================================================
   5) KULLANICI VE ROL KONTROLÜ
   ========================================================= */

SELECT 
    dp.name AS UserOrRoleName,
    dp.type_desc AS TypeDescription,
    dp.create_date AS CreateDate
FROM sys.database_principals dp
WHERE dp.name IN ('guvenlik_kullanici', 'satis_okuma_rolu');
GO

/* =========================================================
   6) SELECT YETKİ TESTİ
   ========================================================= */

EXECUTE AS USER = 'guvenlik_kullanici';
GO

SELECT * FROM dbo.MusteriGuvenlikTest;
GO

REVERT;
GO

/* =========================================================
   7) YETKİSİZ UPDATE TESTİ
   Bu işlem hata vermelidir.
   ========================================================= */

EXECUTE AS USER = 'guvenlik_kullanici';
GO

UPDATE dbo.MusteriGuvenlikTest
SET PhoneNumber = '05550000000'
WHERE CustomerID = 1;
GO

REVERT;
GO

/* =========================================================
   8) UPDATE YETKİSİ VERME
   ========================================================= */

GRANT UPDATE ON dbo.MusteriGuvenlikTest TO satis_okuma_rolu;
GO

SELECT 
    USER_NAME(grantee_principal_id) AS YetkiVerilen,
    permission_name AS Yetki,
    state_desc AS Durum,
    OBJECT_NAME(major_id) AS Nesne
FROM sys.database_permissions
WHERE grantee_principal_id = USER_ID('satis_okuma_rolu');
GO

/* =========================================================
   9) UPDATE YETKİ TESTİ
   Bu işlem başarılı olmalıdır.
   ========================================================= */

EXECUTE AS USER = 'guvenlik_kullanici';
GO

UPDATE dbo.MusteriGuvenlikTest
SET PhoneNumber = '05551112233'
WHERE CustomerID = 1;
GO

SELECT * 
FROM dbo.MusteriGuvenlikTest
WHERE CustomerID = 1;
GO

REVERT;
GO

/* =========================================================
   10) UPDATE YETKİSİNİ GERİ ALMA
   ========================================================= */

REVOKE UPDATE ON dbo.MusteriGuvenlikTest 
FROM satis_okuma_rolu;
GO

/* =========================================================
   11) TEKRAR YETKİSİZ UPDATE TESTİ
   Bu işlem tekrar hata vermelidir.
   ========================================================= */

EXECUTE AS USER = 'guvenlik_kullanici';
GO

UPDATE dbo.MusteriGuvenlikTest
SET PhoneNumber = '05559998877'
WHERE CustomerID = 1;
GO

REVERT;
GO

/* =========================================================
   12) SQL INJECTION TESTİ - GÜVENSİZ DİNAMİK SQL
   ========================================================= */

DECLARE @KullaniciGirdisi NVARCHAR(100);
DECLARE @SQL NVARCHAR(MAX);

SET @KullaniciGirdisi = ''' OR 1=1 --';

SET @SQL = '
SELECT *
FROM dbo.MusteriGuvenlikTest
WHERE CustomerName = ''' + @KullaniciGirdisi + '''';

PRINT @SQL;
EXEC(@SQL);
GO

/* =========================================================
   13) SQL INJECTION'A KARŞI GÜVENLİ SORGU
   ========================================================= */

DECLARE @KullaniciGirdisi NVARCHAR(100);

SET @KullaniciGirdisi = ''' OR 1=1 --';

SELECT *
FROM dbo.MusteriGuvenlikTest
WHERE CustomerName = @KullaniciGirdisi;
GO

/* =========================================================
   14) AUDIT LOG TABLOSU OLUŞTURMA
   ========================================================= */

CREATE TABLE dbo.SecurityAuditLog (
    LogID INT IDENTITY(1,1) PRIMARY KEY,
    KullaniciAdi NVARCHAR(100),
    IslemTipi NVARCHAR(50),
    TabloAdi NVARCHAR(100),
    IslemTarihi DATETIME DEFAULT GETDATE(),
    Aciklama NVARCHAR(300)
);
GO

/* =========================================================
   15) UPDATE İŞLEMLERİNİ LOGLAYAN TRIGGER
   ========================================================= */

CREATE TRIGGER trg_MusteriGuvenlikTest_UpdateLog
ON dbo.MusteriGuvenlikTest
AFTER UPDATE
AS
BEGIN
    INSERT INTO dbo.SecurityAuditLog
    (
        KullaniciAdi,
        IslemTipi,
        TabloAdi,
        Aciklama
    )
    VALUES
    (
        SYSTEM_USER,
        'UPDATE',
        'MusteriGuvenlikTest',
        'Müşteri bilgileri üzerinde güncelleme işlemi yapıldı.'
    );
END;
GO

/* =========================================================
   16) AUDIT LOG TESTİ
   ========================================================= */

UPDATE dbo.MusteriGuvenlikTest
SET PhoneNumber = '05554443322'
WHERE CustomerID = 1;
GO

SELECT * FROM dbo.SecurityAuditLog;
GO

/* =========================================================
   17) VIEW İLE VERİ MASKELEME
   ========================================================= */

CREATE VIEW dbo.vw_MusteriMaskeli
AS
SELECT
    CustomerID,
    CustomerName,
    CONCAT('XXXXXXX', RIGHT(PhoneNumber, 4)) AS MaskeliTelefon,
    WebsiteURL
FROM dbo.MusteriGuvenlikTest;
GO

SELECT * FROM dbo.vw_MusteriMaskeli;
GO

/* =========================================================
   18) ROL ÜYELİĞİ RAPORU
   ========================================================= */

SELECT 
    r.name AS RoleName,
    m.name AS MemberName
FROM sys.database_role_members drm
JOIN sys.database_principals r
    ON drm.role_principal_id = r.principal_id
JOIN sys.database_principals m
    ON drm.member_principal_id = m.principal_id
WHERE r.name = 'satis_okuma_rolu';
GO

/* =========================================================
   19) YETKİ RAPORU
   ========================================================= */

SELECT 
    USER_NAME(grantee_principal_id) AS YetkiVerilen,
    permission_name AS Yetki,
    state_desc AS Durum,
    OBJECT_NAME(major_id) AS Nesne
FROM sys.database_permissions
WHERE grantee_principal_id = USER_ID('satis_okuma_rolu');
GO