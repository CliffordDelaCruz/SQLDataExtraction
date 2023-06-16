
DROP PROCEDURE [dbo].[sp_EBP_EInvoice_Daily_V2]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE [dbo].[sp_EBP_EInvoice_Daily_V2]
	@FILEID			NVARCHAR(100)='INVOICE_V2',
	@DateParam_FROM datetime = NULL,
	@DateParam_TO   datetime = NULL

/*
update tblebpdataconfig
set ebpdc_printout_source_subfoler =NULL
where ebpdc_output_fileid='E_Invoice'
*/
AS
BEGIN
	DECLARE @DATE_FROM datetime = isnull(@DateParam_FROM, DATEADD(dd, 0, DATEDIFF(dd, 0,  [dbo].[GETLOCALDATE] ())))
	DECLARE @DATE_TO datetime = isnull(@DateParam_TO, DATEADD(dd, 0, DATEDIFF(dd, 0,  [dbo].[GETLOCALDATE] ())))
	SET		@DATE_TO = DATEADD(ms, -2, DATEADD(dd, 1, DATEDIFF(dd, 0, @DATE_TO)))
	--20211217 - Clifford - add a new date field to get AX Invoice that cannot be processed the other day because PDF copied only 8AM after Invoice data extraction
	DECLARE @DATE_FROM_AX datetime = DATEADD(dd, -2, DATEDIFF(dd, 0,  [dbo].[GETLOCALDATE] ()))
	
	DECLARE @DATE_FROM_V NVARCHAR(10)= CONVERT(NVARCHAR,@DATE_FROM,121)
	DECLARE @DATE_TO_V NVARCHAR(10)= CONVERT(NVARCHAR,@DATE_TO,121)


SELECT @DATE_FROM_V,@DATE_TO_V
	
	DECLARE @EBPDC_DELIMITER		NVARCHAR(10)
	DECLARE @EBPDC_OUTPUT_FILEID	NVARCHAR(100)
	DECLARE @EBPDC_FILTER_FTI_ORDER_TYPE		NVARCHAR(1000)
	DECLARE @EBPDC_FILTER_FTI_ORDER_TYPEx		xml

	DECLARE @EBPDC_FILTER_SO_ORDER_TYPE		NVARCHAR(1000)
	DECLARE @EBPDC_FILTER_SO_ORDER_TYPEx		xml

	DECLARE @EBPDF_FILTER_VALUE_LIST_SITE	NVARCHAR(1000)
	DECLARE @EBPDF_FILTER_VALUE_LIST_SITEX	XML

	DECLARE @CUSTOM_COMP			NVARCHAR(50)
	DECLARE @MODEL					NVARCHAR(50) = ''
	DECLARE @SERIAL					NVARCHAR(50) = ''

    DECLARE @EBPDF_CURRENCY		VARCHAR(100)
    DECLARE @EBPDF_SALESID		VARCHAR(100)
    DECLARE @EBPDF_SALESID_FT		VARCHAR(100)
    
    	DECLARE @EBPDC_HAS_HEADER		BIT
	DECLARE @EBPDC_OUTPUT_PATH		NVARCHAR(100)
	--DECLARE @EBPDC_OUTPUT_FILEID	NVARCHAR(100)=@OutputEBP
	DECLARE @EBPDC_OUTPUT_TYPE		NVARCHAR(10)
	DECLARE @EBPDC_PRINTOUT_REQUIRED	BIT
	DECLARE @EBPDC_PRINTOUT_SOURCE_PATH	NVARCHAR(255)
	DECLARE @EBPDC_PRINTOUT_SOURCE_SUBFOLER		NVARCHAR(50)
	DECLARE @EBPDC_PRINTOUT_FILEID				NVARCHAR(50)
	DECLARE @EBPDC_PRINTOUT_FILEID_DATE			DATETIME
	DECLARE @EBPDC_PRINTOUT_DESTINATION_PATH	NVARCHAR(255)
	
	DECLARE @CMD VARCHAR(4000),
	@DelCMD VARCHAR(4000),
    @HEADERCMD VARCHAR(4000),
    @Combine VARCHAR(4000) , @COLUMNS VARCHAR(4000)
    
    	SELECT 
		@EBPDC_HAS_HEADER=EBPDC_HAS_HEADER,
		@EBPDC_OUTPUT_PATH=EBPDC_OUTPUT_PATH,
		@EBPDC_OUTPUT_TYPE=EBPDC_OUTPUT_TYPE,
		@EBPDC_PRINTOUT_REQUIRED=EBPDC_PRINTOUT_REQUIRED,
		@EBPDC_PRINTOUT_SOURCE_PATH=EBPDC_PRINTOUT_SOURCE_PATH,
		--@EBPDC_PRINTOUT_SOURCE_SUBFOLER=EBPDC_PRINTOUT_SOURCE_SUBFOLER,
		@EBPDC_PRINTOUT_DESTINATION_PATH=EBPDC_PRINTOUT_DESTINATION_PATH,
		@EBPDC_PRINTOUT_FILEID=EBPDC_PRINTOUT_FILEID
	FROM tblEBPDataConfig WHERE EBPDC_FILEID=@FILEID
	
    
    SELECT @EBPDF_CURRENCY=EBPDF_FILTER_VALUE_LIST 
    FROM tblEBPDataFilter where EBPDF_FILEID = @FILEID AND EBPDF_FILTER_KEY ='CURRENCY'
    
       SELECT @EBPDF_SALESID=EBPDF_FILTER_VALUE_LIST 
    FROM tblEBPDataFilter where EBPDF_FILEID = @FILEID AND EBPDF_FILTER_KEY ='SALESID'
    
     SELECT @EBPDF_SALESID_FT=ISNULL(EBPDF_FILTER_VALUE_LIST ,'')
    FROM tblEBPDataFilter where EBPDF_FILEID = @FILEID AND EBPDF_FILTER_KEY ='SALESID_FT'
    
    
	SELECT 
		@EBPDC_DELIMITER=ISNULL(EBPDC_DELIMITER,''),
		@EBPDC_OUTPUT_FILEID=EBPDC_OUTPUT_FILEID
	FROM tblEBPDataConfig WHERE EBPDC_FILEID=@FILEID 

	IF OBJECT_ID('tempdb..#eBP_Filter') IS NOT NULL
		DROP TABLE #eBP_Filter

	CREATE TABLE #eBP_Filter (
		EBPDF_FILTER_COL		NVARCHAR(50),
		EBPDF_FILTER_COL_CONDITION	NVARCHAR(1000)
	)
	
	INSERT INTO #eBP_Filter (EBPDF_FILTER_COL,EBPDF_FILTER_COL_CONDITION)
	SELECT F1.EBPDF_FILTER_VALUE_LIST,F2.EBPDF_FILTER_VALUE_LIST
		FROM tblEBPDataFilter F1
			inner join tblEBPDataFilter F2 on f1.EBPDF_FILEID=f2.EBPDF_FILEID and f1.EBPDF_FILTER_VALUE_LIST=f2.EBPDF_FILTER_KEY
	WHERE f1.EBPDF_FILEID = @FILEID AND f1.EBPDF_FILTER_KEY LIKE 'CUSTOM_COLUMN%'

	SELECT @EBPDC_FILTER_FTI_ORDER_TYPE=EBPDF_FILTER_VALUE_LIST
		FROM tblEBPDataFilter
	WHERE EBPDF_FILEID = @FILEID AND EBPDF_FILTER_KEY = 'FTI_N_CANONORDERTYPE'
	SET @EBPDC_FILTER_FTI_ORDER_TYPEx = '<i>' + REPLACE( @EBPDC_FILTER_FTI_ORDER_TYPE, ',', '</i><i>') + '</i>'
	
	SELECT @EBPDC_FILTER_SO_ORDER_TYPE=EBPDF_FILTER_VALUE_LIST
		FROM tblEBPDataFilter
	WHERE EBPDF_FILEID = @FILEID AND EBPDF_FILTER_KEY = 'SO_N_CANONORDERTYPE'
	SET @EBPDC_FILTER_SO_ORDER_TYPEx = '<i>' + REPLACE( @EBPDC_FILTER_SO_ORDER_TYPE, ',', '</i><i>') + '</i>'

	SELECT @EBPDF_FILTER_VALUE_LIST_SITE=EBPDF_FILTER_VALUE_LIST
		FROM tblEBPDataFilter
	WHERE EBPDF_FILEID = @FILEID AND EBPDF_FILTER_KEY = 'INVOICE_V2_SITE'
	SET @EBPDF_FILTER_VALUE_LIST_SITEX = '<i>' + REPLACE( @EBPDF_FILTER_VALUE_LIST_SITE, ',', '</i><i>') + '</i>'

	SELECT @CUSTOM_COMP=VALUE FROM tblCustomConfigFields WHERE CODE ='COMPANY_CODE'

	declare @eBP_Filter nvarchar(max) = ''

	SELECT @eBP_Filter = COALESCE(@eBP_Filter + ' AND ', '') + EBPDF_FILTER_COL + ' ' + EBPDF_FILTER_COL_CONDITION  
		FROM #eBP_Filter
	SET @eBP_Filter = Stuff(@eBP_Filter,1,4,N'')

DECLARE @sql varchar(max)
SET @sql = 'IF object_id(' + '''.dbo.' + @EBPDC_OUTPUT_FILEID + ''') IS NOT NULL DROP TABLE ' + @EBPDC_OUTPUT_FILEID
EXEC(@sql)

IF OBJECT_ID('tempdb..#eBP_Work') IS NOT NULL
    DROP TABLE #eBP_Work

IF OBJECT_ID('tempdb..##colseinv') IS NOT NULL
   DROP TABLE ##colseinv
    
IF OBJECT_ID('tempdb..##ebp_einvoice') IS NOT NULL
    DROP TABLE ##ebp_einvoice
    

IF OBJECT_ID('tempdb..#eBP_WorkFT') IS NOT NULL
    DROP TABLE #eBP_WorkFT
    
    --print 'go to ax'
    IF OBJECT_ID('tempdb..#E_Invoice_V2') IS NOT NULL
    DROP TABLE #E_Invoice_V2 
		
--- AX Invoices		
/*SELECT * FROM CUSTINVOICEJOUR c (nolock) 
left join SALESTABLE s (nolock) on (s.dataareaid=c.dataareaid and s.Salesid=c.SALESID)
where c.dataareaid='acb' and c.DIMENSION5_ in ('11AAA','12AAA','21AAA','22AAA') 
and c.SALESID like 'RF%'*/

SELECT  [INV].[DIMENSION5_] COLLATE Latin1_General_CI_AS as [Site_Code]
,'N' COLLATE Latin1_General_CI_AS as [Is_Void]
,INV.INVOICEACCOUNT COLLATE Latin1_General_CI_AS as [Customer_Code]
,INV.INVOICEID COLLATE Latin1_General_CI_AS as [Invoice_Number]
,CONVERT(VARCHAR,CAST(DATEADD(MI, 8*60,INV.INVOICEDATE) as DATE),112) as [Invoice_Date]
,CONVERT(VARCHAR,CAST(DATEADD(MI, 8*60,INV.DUEDATE) as DATE),112) as [Due_Date] 
,INV.INVOICEAMOUNT  as [Total_Amount]
,INV.CURRENCYCODE COLLATE Latin1_General_CI_AS as [Currency]
,REPLACE('' COLLATE Latin1_General_CI_AS, NULL,'') COLLATE Latin1_General_CI_AS as [Model]
,REPLACE('' COLLATE Latin1_General_CI_AS, NULL,'') as [Serial_No]
into #ebp_work
FROM cem.CustInvoiceJour INV (nolock)
left JOIN cem.SALESTABLE SH (nolock) ON SH.dataareaid=INV.dataareaid AND SH.SALESID=inv.SALESID
WHERE INV.dataareaid=@CUSTOM_COMP AND SH.N_CANONORDERTYPE IN (SELECT x.i.value('.', 'NVARCHAR(MAX)') FROM @EBPDC_FILTER_SO_ORDER_TYPEx.nodes('//i') x(i))
AND inv.DIMENSION5_ in  (SELECT x.i.value('.', 'NVARCHAR(MAX)') FROM @EBPDF_FILTER_VALUE_LIST_SITEx.nodes('//i') x(i))
AND CAST(DATEADD(MI, 8*60,INV.INVOICEDATE) as DATE)  between cast(@DATE_FROM_AX as DATE) and cast(@DATE_TO as DATE)
and INV.SALESID like @EBPDF_SALESID and INV.CURRENCYCODE =@EBPDF_CURRENCY

--Free Text Invoice
/*SELECT * FROM CUSTINVOICEJOUR c (nolock) 
left join CUSTINVOICETABLE f (nolock) on (f.dataareaid=c.dataareaid and f.invoiceid=c.invoiceid)
where c.dataareaid='acb' and c.DIMENSION5_ in ('11AAA','12AAA','21AAA','22AAA') 
and c.SALESID=''*/

SELECT  [INV].[DIMENSION5_] COLLATE Latin1_General_CI_AS as [Site_Code]
,'N' COLLATE Latin1_General_CI_AS as [Is_Void]
,INV.INVOICEACCOUNT COLLATE Latin1_General_CI_AS as [Customer_Code]
,INV.INVOICEID COLLATE Latin1_General_CI_AS as [Invoice_Number]
,CONVERT(VARCHAR,CAST(DATEADD(MI, 8*60,INV.INVOICEDATE) as DATE),112) as [Invoice_Date]
,CONVERT(VARCHAR,CAST(DATEADD(MI, 8*60,INV.DUEDATE) as DATE),112) as [Due_Date] 
,INV.INVOICEAMOUNT  as [Total_Amount]
,INV.CURRENCYCODE COLLATE Latin1_General_CI_AS as [Currency]
,REPLACE('' COLLATE Latin1_General_CI_AS, NULL,'') COLLATE Latin1_General_CI_AS as [Model]
,REPLACE('' COLLATE Latin1_General_CI_AS, NULL,'') as [Serial_No]
into #ebp_workFT
FROM cem.CustInvoiceJour INV (nolock)
left JOIN cem.CUSTINVOICETABLE ft (nolock) ON ft.dataareaid=INV.dataareaid AND ft.invoiceid=inv.invoiceid
WHERE INV.dataareaid=@CUSTOM_COMP --AND SH.N_CANONORDERTYPE IN (SELECT x.i.value('.', 'NVARCHAR(MAX)') FROM @EBPDC_FILTER_SO_ORDER_TYPEx.nodes('//i') x(i))
AND inv.DIMENSION5_ in  (SELECT x.i.value('.', 'NVARCHAR(MAX)') FROM @EBPDF_FILTER_VALUE_LIST_SITEx.nodes('//i') x(i))
AND CAST(DATEADD(MI, 8*60,INV.INVOICEDATE) as DATE) between cast(@DATE_FROM_AX as DATE) and cast(@DATE_TO as DATE)
and INV.SALESID in (@EBPDF_SALESID_FT) and INV.CURRENCYCODE =@EBPDF_CURRENCY


----CDSS Invoices
SET @sql = 
'SELECT b.pkey,INV_CLICK_CHARGE_CREATED_XML,B.INV_DIVISION_PKEY AS Site_Code,
B.INV_IS_VOID AS Is_Void,
RTRIM(B.INV_XML_BILL_TO_CUST_PKEY)   AS Customer_Code,
B.INV_NUMBER    AS Invoice_Number,
CONVERT(VARCHAR,B.INV_BILLING_DATE_LT,112) AS Invoice_Date,
CONVERT(VARCHAR,B.INV_PAYMENT_DUE_DATE_LT,112) AS Due_Date,
B.INV_TRANSACTION_INVOICE_TOTAL_AMOUNT  AS Total_Amount,
B.INV_TRANSACTION_CURR_PKEY   AS Currency,
MIB.INB_MODEL_PKEY   AS Model,
MIB.INB_SERIAL_NUMBER   AS Serial_No
into ' + @EBPDC_OUTPUT_FILEID +
 ' FROM tblBilling B (NOLOCK)
	INNER JOIN tblBillingMachine BM (NOLOCK) ON B.PKEY = BM.BME_INV_PKEY
	INNER JOIN tblMachineInstallBase MIB (NOLOCK) ON BM.BME_INB_PKEY = MIB.PKEY
	INNER JOIN tblContractDetail CD(NOLOCK) ON MIB.PKEY=CD.CDETAIL_INB_PKEY AND BME_CONTRACT_PKEY=CD.CDETAIL_CONTRACT_PKEY
	INNER JOIN tblContractHeader CH(NOLOCK) ON CD.CDETAIL_CONTRACT_PKEY=CH.PKEY
	INNER JOIN tblcustomers cust on cust.pkey = CONTRACT_CUST_PKEY 
WHERE 1=1
AND	CONVERT(DATE,INV_CREATE_DATE_LT) BETWEEN ''' + @DATE_FROM_V + ''' AND ''' + @DATE_TO_V + 
''' AND NOT(ISNULL(INV_IS_VOID,''N'')=''Y'') /*AND ISNULL(INV_CLICK_CHARGE_CREATED_XML,0)=0)*/
AND B.INV_PRINT_MODE<>''G''
AND ISNULL(CUST_IS_AGD_CUSTOMER,0)=''0'' 
/*AND (B.INV_CLICK_CHARGE_CREATED_XML)=''1''*/
AND ' + @eBP_Filter +
' ORDER BY INV_NUMBER'

SELECT @sql AS 'E SQL'
EXEC(@sql)


select * into #E_Invoice_V2 from E_Invoice_V2

SET @sql = 'IF object_id(' + '''.dbo.' + @EBPDC_OUTPUT_FILEID + ''') IS NOT NULL DROP TABLE ' + @EBPDC_OUTPUT_FILEID
EXEC(@sql)



/* added to incl leasing invoice - 18/12/2018 by Dhanya */
SET @sql = 'select Site_Code,Is_Void,Customer_Code,Invoice_Number,Invoice_Date, Due_Date, Total_Amount,Currency,Model,Serial_No into '+ @EBPDC_OUTPUT_FILEID+ ' from #E_Invoice_V2 ev2 where INV_CLICK_CHARGE_CREATED_XML=''1'''
EXEC(@sql)

SET @sql = 'Insert into '+@EBPDC_OUTPUT_FILEID+' select distinct Site_Code,Is_Void,Customer_Code,Invoice_Number,Invoice_Date, Due_Date, Total_Amount,Currency,Model,Serial_No  from #E_Invoice_V2 ev2 inner join tblBillingContractOtherChargeDetail bocd
on ev2.PKEY=bocd.BOC_INV_PKEY where INV_CLICK_CHARGE_CREATED_XML is NULL and BOC_CREATED_XML=1'
EXEC(@sql)


SELECT 'INSERT TO EBP WORK'
SET @sql = 'INSERT INTO #eBP_Work SELECT * FROM ' + @EBPDC_OUTPUT_FILEID
EXEC(@sql)

SELECT 'INSERT TO EBP WORK-FT invocie'
SET @sql = 'INSERT INTO #eBP_Work SELECT * FROM #ebp_workFT' 
EXEC(@sql)


SET @sql = 'IF object_id(' + '''.dbo.' + @EBPDC_OUTPUT_FILEID + ''') IS NOT NULL DROP TABLE ' + @EBPDC_OUTPUT_FILEID
EXEC(@sql)

SET @sql = 'SELECT * INTO ' + @EBPDC_OUTPUT_FILEID + ' FROM #eBP_Work'
EXEC(@sql)

-- Added to cater 2 new folders
EXEC [sp_EBP_Output_DataFile_einvoice] @FILEID,@EBPDC_OUTPUT_FILEID

EXEC [sp_EBP_EInvoice_Daily_V2_INCL_TEMP] @FILEID


Set @sql= 'Update ' +@EBPDC_OUTPUT_FILEID+ ' set PRINTOUT_DESTINATION_PATH=''PDF found'' where PRINTOUT_DESTINATION_PATH=''2'''
EXEC(@sql)
--select @sql
		
Set @sql= 'Update ' +@EBPDC_OUTPUT_FILEID+ ' set PRINTOUT_DESTINATION_PATH=''File Not found'' where PRINTOUT_DESTINATION_PATH=''1'''
EXEC(@sql)

set @sql = 'select * into ##ebp_einvoice from '+@EBPDC_OUTPUT_FILEID
EXEC(@sql)

set @sql ='Alter table ##ebp_einvoice drop column PRINTOUT_DESTINATION_PATH'
EXEC(@sql)
    
     SET @COLUMNS = ''
     
  SELECT @COLUMNS = @COLUMNS + c.name + ','
  from tempdb..syscolumns C
  join tempdb..sysobjects t
     on c.id = t.id
     where t.name like '##ebp_einvoice'
     order by colid
     

  SELECT @COLUMNS as Cols INTO ##colseinv
  
 SET @CMD = 'bcp "select * from ##ebp_einvoice " queryout "' + @EBPDC_OUTPUT_PATH + 'Temp_RawData13.csv" -S ' + @@SERVERNAME + ' -T -t , -c'
		SET @HEADERCMD = 'bcp "SELECT * from ##colseinv" queryout "' + @EBPDC_OUTPUT_PATH + 'Temp_Headers13.csv" -S ' + @@SERVERNAME + ' -T -t , -c'
		SET @Combine = 'copy "' + @EBPDC_OUTPUT_PATH + 'Temp_Headers13.csv" + "' + @EBPDC_OUTPUT_PATH + 'Temp_RawData13.csv" "' + @EBPDC_OUTPUT_PATH +@EBPDC_OUTPUT_FILEID+'.csv'
		SET @DelCMD = 'del "' + @EBPDC_OUTPUT_PATH + 'Temp_*.csv"'
	
	exec xp_cmdshell @HEADERCMD
exec xp_cmdshell @CMD
 
exec xp_cmdshell @Combine

exec xp_cmdshell @DelCMD

-- 20211217 - This should email the result of e_invoice data extraction
IF EXISTS(SELECT TOP 1 * FROM e_invoice_v2(NOLOCK))
	begin
		DECLARE @QueryText as NVARCHAR(MAX);
		SET @QueryText='SELECT * FROM e_invoice_v2';

		/*Call Email function to send query result to email*/
		 EXEC [LocalACB].sp_SendEmail 1,'EBP Invoice Extract Result',NULL, NULL,@QueryText
 	end

		
END 


GO


