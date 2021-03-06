
/*******************************************************************
* 1.Programmed by	: H
* 2.Date			: 2014-04-09
* 3.Role			: 통계관리 > 매출통계
* 4.Parameters		:
* 5.Modification History
*====================================================================
*  WHO		WHEN		WHAT
*====================================================================
* H		2014-04-09		초기작성


*====================================================================

*********************************************************************/

ALTER PROCEDURE usp_Statistic_SaleStatisticList
/*********************************************************************
* Interface Part
*********************************************************************/
(
	@Search				nvarchar(max)	= ''
)
AS
set nocount on

/*********************************************************************
* transaction header
*********************************************************************/
declare	@origin_tranCount	int
declare	@error			int
declare	@rowCount		int
set	@origin_tranCount	= @@tranCount
set	@error			= 0
set	@rowCount		= 0

declare	@errorCode	int
declare	@errorText	varchar(1000)
set	@errorCode	= 0
set	@errorText	= 'Error Issue'


/*********************************************************************
* Pre-Condition Check Part
*********************************************************************/



/*********************************************************************
* Variable Part
*********************************************************************/

if (@Search is null or @Search = '')
Begin
	set @Search=  ''
End


/*********************************************************************
* Implementation Part
*********************************************************************/


----------------------------------------------------------------------
-- 매출통계
----------------------------------------------------------------------
	

			set @Search =  '
			퀴리문
	' +  @Search

exec sp_executesql @Search



/*********************************************************************
* transaction tail
*********************************************************************/
transSuccess:
	if @@tranCount > @origin_tranCount commit tran
	return 0


transFail:
	if @@tranCount > @origin_tranCount rollback tran
	set @errorText = convert(varchar(11), @errorCode) + ' : ' + @errorText
	raiserror (@errorText, 16, 1)
	return @errorCode


/*********************************************************************
* End of usp
*********************************************************************/
set nocount off