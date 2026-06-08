USE AdventureWorks2022;
GO

IF OBJECT_ID('dbo.BackupTest', 'U') IS NOT NULL
DROP TABLE dbo.BackupTest;
GO

-- 1. AdventureWorks2022 veritabanını kullan
USE AdventureWorks2022;
GO

-- 2. Dataset içindeki gerçek tablolardan örnek veri görüntüleme
SELECT TOP 10
    ProductID,
    Name,
    ProductNumber,
    ListPrice
FROM Production.Product
ORDER BY ListPrice DESC;
GO

SELECT TOP 10
    SalesOrderID,
    OrderDate,
    CustomerID,
    TotalDue
FROM Sales.SalesOrderHeader
ORDER BY TotalDue DESC;
GO

-- 3. Recovery Model kontrolü
USE master;
GO

ALTER DATABASE AdventureWorks2022 
SET RECOVERY FULL;
GO

SELECT 
    name AS DatabaseName,
    recovery_model_desc AS RecoveryModel
FROM sys.databases
WHERE name = 'AdventureWorks2022';
GO

-- 4. Full Backup
BACKUP DATABASE AdventureWorks2022
TO DISK = 'C:\Users\ASUS\Desktop\SQL\AdventureWorks2022_Full.bak'
WITH 
    INIT,
    NAME = 'AdventureWorks2022 Full Backup',
    DESCRIPTION = 'Tam veritabanı yedeği',
    STATS = 10;
GO

-- 5. Test tablosu oluşturma ve veri ekleme
USE AdventureWorks2022;
GO

CREATE TABLE dbo.BackupTest (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Aciklama NVARCHAR(100),
    Tarih DATETIME DEFAULT GETDATE()
);
GO

INSERT INTO dbo.BackupTest (Aciklama)
VALUES
('İlk kayıt'),
('Differential backup testi'),
('Yeni veri eklendi');
GO

SELECT * FROM dbo.BackupTest;
GO

-- 6. Differential Backup
BACKUP DATABASE AdventureWorks2022
TO DISK = 'C:\Users\ASUS\Desktop\SQL\AdventureWorks2022_Diff.bak'
WITH 
    DIFFERENTIAL,
    INIT,
    NAME = 'AdventureWorks2022 Differential Backup',
    DESCRIPTION = 'Fark yedeği',
    STATS = 10;
GO

-- 7. Log Backup öncesi yeni veri ekleme
USE AdventureWorks2022;
GO

INSERT INTO dbo.BackupTest (Aciklama)
VALUES ('Log backup öncesi eklenen kayıt');
GO

SELECT * FROM dbo.BackupTest;
GO

-- 8. Transaction Log Backup
BACKUP LOG AdventureWorks2022
TO DISK = 'C:\Users\ASUS\Desktop\SQL\AdventureWorks2022_Log.trn'
WITH 
    INIT,
    NAME = 'AdventureWorks2022 Transaction Log Backup',
    DESCRIPTION = 'Transaction log yedeği',
    STATS = 10;
GO

-- 9. Backup dosyalarını doğrulama
RESTORE VERIFYONLY 
FROM DISK = 'C:\Users\ASUS\Desktop\SQL\AdventureWorks2022_Full.bak';
GO

RESTORE VERIFYONLY 
FROM DISK = 'C:\Users\ASUS\Desktop\SQL\AdventureWorks2022_Diff.bak';
GO

RESTORE VERIFYONLY 
FROM DISK = 'C:\Users\ASUS\Desktop\SQL\AdventureWorks2022_Log.trn';
GO

-- 10. Felaket senaryosu: tablo yanlışlıkla siliniyor
USE AdventureWorks2022;
GO

DROP TABLE dbo.BackupTest;
GO

-- Bu sorgu hata verecek, bu beklenen durumdur
SELECT * FROM dbo.BackupTest;
GO

-- 11. Restore işlemi için veritabanını SINGLE_USER moduna alma
USE master;
GO

ALTER DATABASE AdventureWorks2022
SET SINGLE_USER
WITH ROLLBACK IMMEDIATE;
GO

-- 12. Full Backup geri yükleme
RESTORE DATABASE AdventureWorks2022
FROM DISK = 'C:\Users\ASUS\Desktop\SQL\AdventureWorks2022_Full.bak'
WITH 
    REPLACE,
    NORECOVERY,
    STATS = 10;
GO

-- 13. Differential Backup geri yükleme
RESTORE DATABASE AdventureWorks2022
FROM DISK = 'C:\Users\ASUS\Desktop\SQL\AdventureWorks2022_Diff.bak'
WITH 
    NORECOVERY,
    STATS = 10;
GO

-- 14. Transaction Log Backup geri yükleme
RESTORE LOG AdventureWorks2022
FROM DISK = 'C:\Users\ASUS\Desktop\SQL\AdventureWorks2022_Log.trn'
WITH 
    RECOVERY,
    STATS = 10;
GO

-- 15. Veritabanını tekrar çok kullanıcılı moda alma
ALTER DATABASE AdventureWorks2022
SET MULTI_USER;
GO

-- 16. Kurtarma sonrası kontrol
USE AdventureWorks2022;
GO

SELECT * FROM dbo.BackupTest;
GO