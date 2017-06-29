-- MSSQL 관리자 권환 (SSMS 관리자 전용 연결하기)
sp_configure 'remote admin connections', 1

GO

RECONFIGURE WITH OVERRIDE

GO

-- 프로시저 암호화 

CREATE PROC porcName
WITH ENCRYPTION -- 프로시져를 암호화함.
--[주의] 미리 선언된 변수가 있다면 선언된 변수 아래에 암호화 선언을 해야함
AS

/*
프로시져 내용
*/

GO


-- 프로시저 복호화 실행

USE CAR_ERP2
DECLARE @ObjectOwnerOrSchema NVARCHAR(128)
DECLARE @ObjectName NVARCHAR(128)
 
SET @ObjectOwnerOrSchema = 'dbo'
SET @ObjectName = 'PR_List_CardBillInfo_Left'
 
DECLARE @i INT
DECLARE @ObjectDataLength INT
DECLARE @ContentOfEncryptedObject NVARCHAR(MAX)
DECLARE @ContentOfDecryptedObject NVARCHAR(MAX)
DECLARE @ContentOfFakeObject NVARCHAR(MAX)
DECLARE @ContentOfFakeEncryptedObject NVARCHAR(MAX)
DECLARE @ObjectType NVARCHAR(128)
DECLARE @ObjectID INT
 
SET NOCOUNT ON
 
SET @ObjectID = OBJECT_ID('[' + @ObjectOwnerOrSchema + '].[' + @ObjectName + ']')
 
-- Check that the provided object exists in the database.
IF @ObjectID IS NULL
BEGIN
    RAISERROR('The object name or schema provided does not exist in the database', 16, 1)
    RETURN
END
 
-- Check that the provided object is encrypted.
IF NOT EXISTS(SELECT TOP 1 * FROM syscomments WHERE id = @ObjectID AND encrypted = 1)
BEGIN
    RAISERROR('The object provided exists however it is not encrypted. Aborting.', 16, 1)
    RETURN
END
 
 
 
-- Determine the type of the object
IF OBJECT_ID('[' + @ObjectOwnerOrSchema + '].[' + @ObjectName + ']', 'PROCEDURE') IS NOT NULL
    SET @ObjectType = 'PROCEDURE'
ELSE
    IF OBJECT_ID('[' + @ObjectOwnerOrSchema + '].[' + @ObjectName + ']', 'TRIGGER') IS NOT NULL
        SET @ObjectType = 'TRIGGER'
    ELSE
        IF OBJECT_ID('[' + @ObjectOwnerOrSchema + '].[' + @ObjectName + ']', 'VIEW') IS NOT NULL
            SET @ObjectType = 'VIEW'
        ELSE
            SET @ObjectType = 'FUNCTION'
 
-- Get the binary representation of the object- syscomments no longer holds
-- the content of encrypted object.
SELECT TOP 1 @ContentOfEncryptedObject = imageval
FROM sys.sysobjvalues
WHERE objid = OBJECT_ID('[' + @ObjectOwnerOrSchema + '].[' + @ObjectName + ']')
        AND valclass = 1 and subobjid = 1
 
SET @ObjectDataLength = DATALENGTH(@ContentOfEncryptedObject)/2
 
 
-- We need to alter the existing object and make it into a dummy object
-- in order to decrypt its content. This is done in a transaction
-- (which is later rolled back) to ensure that all changes have a minimal
-- impact on the database.
SET @ContentOfFakeObject = N'ALTER ' + @ObjectType + N' [' + @ObjectOwnerOrSchema + N'].[' + @ObjectName + N'] WITH ENCRYPTION AS'
 
WHILE DATALENGTH(@ContentOfFakeObject)/2 < @ObjectDataLength
BEGIN
        IF DATALENGTH(@ContentOfFakeObject)/2 + 4000 < @ObjectDataLength
                SET @ContentOfFakeObject = @ContentOfFakeObject + REPLICATE(N'-', 4000)
        ELSE
                SET @ContentOfFakeObject = @ContentOfFakeObject + REPLICATE(N'-', @ObjectDataLength - (DATALENGTH(@ContentOfFakeObject)/2))
END
 
-- Since we need to alter the object in order to decrypt it, this is done
-- in a transaction
SET XACT_ABORT OFF
BEGIN TRAN
 
EXEC(@ContentOfFakeObject)
 
IF @@ERROR <> 0
        ROLLBACK TRAN
 
-- Get the encrypted content of the new "fake" object.
SELECT TOP 1 @ContentOfFakeEncryptedObject = imageval
FROM sys.sysobjvalues
WHERE objid = OBJECT_ID('[' + @ObjectOwnerOrSchema + '].[' + @ObjectName + ']')
        AND valclass = 1 and subobjid = 1
 
IF @@TRANCOUNT > 0
        ROLLBACK TRAN
 
-- Generate a CREATE script for the dummy object text.
SET @ContentOfFakeObject = N'CREATE ' + @ObjectType + N' [' + @ObjectOwnerOrSchema + N'].[' + @ObjectName + N'] WITH ENCRYPTION AS'
 
WHILE DATALENGTH(@ContentOfFakeObject)/2 < @ObjectDataLength
BEGIN
        IF DATALENGTH(@ContentOfFakeObject)/2 + 4000 < @ObjectDataLength
                SET @ContentOfFakeObject = @ContentOfFakeObject + REPLICATE(N'-', 4000)
        ELSE
                SET @ContentOfFakeObject = @ContentOfFakeObject + REPLICATE(N'-', @ObjectDataLength - (DATALENGTH(@ContentOfFakeObject)/2))
END
 
 
SET @i = 1
 
--Fill the variable that holds the decrypted data with a filler character
SET @ContentOfDecryptedObject = N''
 
WHILE DATALENGTH(@ContentOfDecryptedObject)/2 < @ObjectDataLength
BEGIN
        IF DATALENGTH(@ContentOfDecryptedObject)/2 + 4000 < @ObjectDataLength
                SET @ContentOfDecryptedObject = @ContentOfDecryptedObject + REPLICATE(N'A', 4000)
        ELSE
                SET @ContentOfDecryptedObject = @ContentOfDecryptedObject + REPLICATE(N'A', @ObjectDataLength - (DATALENGTH(@ContentOfDecryptedObject)/2))
END
 
 
WHILE @i <= @ObjectDataLength
BEGIN
        --xor real & fake & fake encrypted
        SET @ContentOfDecryptedObject = STUFF(@ContentOfDecryptedObject, @i, 1,
                NCHAR(
                        UNICODE(SUBSTRING(@ContentOfEncryptedObject, @i, 1)) ^
                        (
                                UNICODE(SUBSTRING(@ContentOfFakeObject, @i, 1)) ^
                                UNICODE(SUBSTRING(@ContentOfFakeEncryptedObject, @i, 1))
                        )))
 
        SET @i = @i + 1
END
 
-- PRINT the content of the decrypted object
PRINT(CAST(@ContentOfDecryptedObject AS NTEXT))