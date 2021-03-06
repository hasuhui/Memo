USE [X]
GO
/****** Object:  UserDefinedFunction [dbo].[CreateModel]    Script Date: 2016-05-02 오후 1:04:49 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
ALTER FUNCTION [dbo].[CreateModel]
(	
	@TableName varchar(100)
)
RETURNS TABLE 
AS
RETURN 
(
	select (
case DATA_TYPE when 'int' then 'public int '+COLUMN_NAME+' { get; set; }'
when 'varchar' then 'public string '+COLUMN_NAME+' { get; set; }'
when 'bit' then 'public bool '+COLUMN_NAME+' { get; set; }'
when 'ntext' then 'public string '+COLUMN_NAME+' { get; set; }'
when 'money' then 'public int '+COLUMN_NAME+' { get; set; }'
when 'smallint' then 'public int '+COLUMN_NAME+' { get; set; }'
when 'text' then 'public string '+COLUMN_NAME+' { get; set; }'
when 'dateTime' then 'public DateTime '+COLUMN_NAME+' { get; set; }'
when 'decimal' then 'public decimal '+COLUMN_NAME+' { get; set; }'
when 'tinyint' then 'public int '+COLUMN_NAME+' { get; set; }'
else DATA_TYPE end) as CV  ,
COLUMN_NAME,isnull((upper(DATA_TYPE)+'('+cast(CHARACTER_MAXIMUM_LENGTH as varchar)+')'),upper(DATA_TYPE)) as DATATYPE 
from INFORMATION_SCHEMA.COLUMNS where TABLE_NAME = @TableName
)





-- 사용 select * from dbo.CreateModel('테이블명') 