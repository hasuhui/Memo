USE [Bizwin]
GO
/****** Object:  StoredProcedure [dbo].[usp_lock7]    Script Date: 2017-04-12 오전 10:29:27 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
락(Lock) 모니터링에 사용되는 프로시저로 옵션을 주는데 따라 락이 걸린 오브젝트 목록 또는 특정 프로세스나 오브젝트와 관련된 락의 종류, 모드(Mode), 상태, 인덱스 명, 오브젝트 타입 등의 상세한 정보를 출력해준다.

입력 파라미터는 다음과 같다.

@option
1 ? 락이 걸린 오브젝트 목록
2 ? 특정 프로세스가 걸고 있는 락의 상세한 정보
3 ? 특정 오브젝트에 걸린 락의 상세한 정보
@obj_name 오브젝트 이름
@spid 프로세스 ID

@option 값을 2로 지정한 경우에는 @spid 변수에 프로세스 ID를 넣어주어야 하며 @option을 3으로 하면 @obj_name에 오브젝트 이름을 지정해 주어야 한다.

*/
ALTER procedure [dbo].[usp_lock7] @option smallint = 0, @obj_name nvarchar(386) =
null, @spid int = 0 as
begin
set nocount on

if (@option <= 0 or @option > 3)
begin
    raiserror(N'Invalid option %d', 1, 1, @option)
    return(-1)
end

select Process_ID = req_spid, rsc_dbid, dbname = db_name(rsc_dbid),
obj_id = rsc_objid , object = convert(nvarchar(386), ''),
index_id = rsc_indid, Tbl = convert(sysname, ''), ObjOwner =
convert(sysname, ''),
Index_name = convert(sysname, ''),
locktype = case
when rsc_type = 1 then 'NULL Resource'
when rsc_type = 2 then 'Database'
when rsc_type = 3 then 'File'
when rsc_type = 4 then 'Index'
when rsc_type = 5 then 'Table'
when rsc_type = 6 then 'Page'
when rsc_type = 7 then 'Key'
when rsc_type = 8 then 'Extent'
when rsc_type = 9 then 'Row ID'
end,
lockmode = case
when req_mode = 0 then 'NULL'
when req_mode = 1 then 'Schema stability'
when req_mode = 2 then 'Schema modification'
when req_mode = 3 then 'Intent Shared'
when req_mode = 4 then 'Shared Intent Update'
when req_mode = 5 then 'Intent Shared-Shared'
when req_mode = 6 then 'Intent Exclusive'
when req_mode = 7 then 'Shared Intent Exclusive'
when req_mode = 8 then 'Shared'
when req_mode = 9 then 'Update'
when req_mode = 10 then 'Intent Insert-NULL'
when req_mode = 11 then 'Intent Shared-Exclusive'
when req_mode = 12 then 'Intent Update'
when req_mode = 13 then 'Intent Shared-Update'
when req_mode = 14 then 'Exclusive'
when req_mode = 15 then 'Used by bulk operations'
end,
status = case
when req_status = 1 then 'Granted'
when req_status = 2 then 'Converting'
when req_status = 3 then 'Waiting'
end,
ownertype = case
when req_ownertype = 1 then 'Transaction'
when req_ownertype = 2 then 'Session'
when req_ownertype = 3 then 'Cursor'
end
into #iw_lock
from master.dbo.syslockinfo


-- create indexes
create index #iw_lock_spid on #iw_lock(Process_ID)

create index #iw_lock_object on #iw_lock(object)


declare @stmt nvarchar(4000)
declare @lckdb sysname
declare @lckobjid integer
declare @lckobj sysname
declare @lckindid smallint
declare @lckind sysname

declare iwlock_cursor cursor for
select distinct dbname, obj_id, index_id from #iw_lock where rsc_dbid > 0
FOR READ ONLY


open  iwlock_cursor
fetch iwlock_cursor into @lckdb, @lckobjid, @lckindid

while @@fetch_status >= 0
begin
    if (@lckobjid > 0)
    begin
select @stmt ='update #iw_lock set tbl = name, ObjOwner = user_name(uid)
from ' + quotename(@lckdb, '[') + '.[dbo].[sysobjects] where id = ' +
convert(nvarchar(10), @lckobjid) + ' and dbname = ''' + @lckdb + ''' and
Obj_id = ' + convert(nvarchar(10), @lckobjid)
        exec (@stmt)
select @stmt ='update #iw_lock set Index_name = name from ' +
quotename(@lckdb, '[') + '.[dbo].[sysindexes] where id = ' +
convert(nvarchar(10), @lckobjid)  + ' and indid = ' + convert(nvarchar(10),
@lckindid) + ' and dbname = ''' + @lckdb + ''' and Obj_id = ' +
convert(nvarchar(10), @lckobjid) + ' and index_id = ' +
convert(nvarchar(10), @lckindid)

        exec (@stmt)
    end
    fetch iwlock_cursor into @lckdb, @lckobjid, @lckindid
end
deallocate iwlock_cursor


update #iw_lock set Object = dbname where obj_id = 0


update #iw_lock set Object = rtrim(dbname) + '.' + rtrim(ObjOwner) + '.' +
rtrim([Tbl]) where obj_id > 0


if (@option = 1)
-- distinct object list
select distinct Object from #iw_lock order by Object

else if (@option = 2)
-- locks per spid
begin
    if (@spid = 0)
    begin
        raiserror(N'Error @spid parameter not specified (option %d)', 1,
1, @option)
        return(-1)
    end
    select Object, LockType, LockMode, Status, Index_name, ownertype from
#iw_lock
where Process_ID = @spid order by Object
end
else if (@option = 3)
-- locks per object
begin
    if (@obj_name is null)
    begin
        raiserror(N'Error @obj_name parameter not specified (option %d)',
1, 1, @option)
        return(-1)
    end
    -- locked object is db
    if parsename(@obj_name,3) is null
    begin
        set @stmt = N'select Process_ID, LockType, LockMode, Status,
Index_name, ownertype from #iw_lock
where Object = ''' + @obj_name + ''' and [Obj_ID] = 0'
    end
    -- locked object is table
    else
    begin
        set @stmt = N'select Process_ID, LockType, LockMode, Status,
Index_name, ownertype from #iw_lock
where Object = ''' + parsename(@obj_name,3) + '.' +
parsename(@obj_name,2) + '.' + parsename(@obj_name,1) + ''''
    end
exec (@stmt)
end

end
