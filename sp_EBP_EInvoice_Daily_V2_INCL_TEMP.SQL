
DROP PROCEDURE [dbo].[sp_EBP_EInvoice_Daily_V2_INCL_TEMP]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_EBP_EInvoice_Daily_V2_INCL_TEMP]
	@FILEID			NVARCHAR(100)='INVOICE_V2'
	AS
BEGIN
	DECLARE @SQL varchar(max)
	DECLARE @SO_CMD VARCHAR(4000)
 	DECLARE @Xcopy_loop bit
 	DECLARE @PRINTOUT_FILEID	NVARCHAR(255)
 	DECLARE @rowcount varchar(10)
 	DECLARE @path varchar(2000)--='\\DC-PAXFS01\CSPL_AFusion_Archive$\AX\FAD\Temp'
	DECLARE @Dest_path varchar(2000)
 	DECLARE @EBPDC_OUTPUT_FILEID	NVARCHAR(100)
 	DECLARE @MECredit_debit_path varchar(2000)
 	DECLARE @Consumables_path varchar(2000)
 		
 	SELECT @EBPDC_OUTPUT_FILEID=EBPDC_OUTPUT_FILEID
	FROM tblEBPDataConfig WHERE EBPDC_FILEID=@FILEID 
 
 	Select @path =EBPDF_FILTER_VALUE_LIST
	FROM tblEBPDataFilter
	WHERE EBPDF_FILEID = @FILEID AND EBPDF_FILTER_KEY = 'EBPDC_PRINTOUT_SOURCE_PATH_TEMP'
	
	Select @MECredit_debit_path =EBPDF_FILTER_VALUE_LIST
	FROM tblEBPDataFilter
	WHERE EBPDF_FILEID = @FILEID AND EBPDF_FILTER_KEY = 'EBPDC_PRINTOUT_SOURCE_PATH_MECreditDebit'
	
	Select @Consumables_path =EBPDF_FILTER_VALUE_LIST
	FROM tblEBPDataFilter
	WHERE EBPDF_FILEID = @FILEID AND EBPDF_FILTER_KEY = 'EBPDC_PRINTOUT_SOURCE_PATH_consumables'
 	
 	SELECT @Dest_path=EBPDC_PRINTOUT_DESTINATION_PATH from tblEBPDataConfig
 	WHERE EBPDC_FILEID = @FILEID
 	
	DECLARE Path_cur Cursor LOCAL STATIC READ_ONLY FORWARD_ONLY For
				select invoice_number from e_invoice_v2 where PRINTOUT_DESTINATION_PATH like 'File%'
				Open Path_cur 
					Fetch Next From Path_cur Into @PRINTOUT_FILEID
					While @@Fetch_Status = 0 
					BEGIN
					    --SET @SO_CMD = 'for /r \\DC-PAXFS01\CSPL_AFusion_Archive$\AX\FAD\Temp %f in (*'+@PRINTOUT_FILEID+'*.pdf) do @copy "%f" \\DC-PAXFS01\eBPdocument$\UAT\CSPL'
						--SET @SO_CMD = 'for /r '+@path+' %f in (*'+@PRINTOUT_FILEID+'*.pdf) do @copy "%f" \\DC-PAXFS01\eBPdocument$\UAT\CSPL'
						
						SET @SO_CMD = 'for /r '+@path+' %f in (*'+@PRINTOUT_FILEID+'*.pdf) do @copy "%f" ' + @Dest_path
						
						exec xp_cmdshell @SO_CMD
						
						SET @sql = 'UPDATE  '+@EBPDC_OUTPUT_FILEID+ ' set PRINTOUT_DESTINATION_PATH= '''+CONVERT(varchar(10), @@rowcount) +'''where invoice_number=''' +@PRINTOUT_FILEID+''''
						print @sql
						exec (@sql)
						
						Fetch Next From Path_cur Into @PRINTOUT_FILEID
				END
					Close Path_cur
					DeAllocate Path_cur 
					
					
Set @sql= 'Update ' +@EBPDC_OUTPUT_FILEID+ ' set PRINTOUT_DESTINATION_PATH=''PDF found'' where PRINTOUT_DESTINATION_PATH=''2'''
EXEC(@sql)
--select @sql
		
Set @sql= 'Update ' +@EBPDC_OUTPUT_FILEID+ ' set PRINTOUT_DESTINATION_PATH=''File Not found'' where PRINTOUT_DESTINATION_PATH=''1'''
EXEC(@sql)
			
--- Added on 18/1/2019 to include new source folder for MEcreditDebitnote
	DECLARE Path_cur_Mecreditdebit Cursor LOCAL STATIC READ_ONLY FORWARD_ONLY For
		select invoice_number from e_invoice_v2 where PRINTOUT_DESTINATION_PATH like 'File%'
		Open Path_cur_Mecreditdebit 
			Fetch Next From Path_cur_Mecreditdebit Into @PRINTOUT_FILEID
				While @@Fetch_Status = 0 
				BEGIN
					--SET @SO_CMD = 'for /r \\DC-PAXFS01\CSPL_AFusion_Archive$\AX\FAD\Temp %f in (*'+@PRINTOUT_FILEID+'*.pdf) do @copy "%f" \\DC-PAXFS01\eBPdocument$\UAT\CSPL'
					--SET @SO_CMD = 'for /r '+@path+' %f in (*'+@PRINTOUT_FILEID+'*.pdf) do @copy "%f" \\DC-PAXFS01\eBPdocument$\UAT\CSPL'
						SET @SO_CMD = 'for /r '+@MECredit_debit_path+' %f in (*'+@PRINTOUT_FILEID+'*.pdf) do @copy "%f" ' + @Dest_path
						exec xp_cmdshell @SO_CMD
						
						SET @sql = 'UPDATE '+@EBPDC_OUTPUT_FILEID+' set PRINTOUT_DESTINATION_PATH= '''+CONVERT(varchar(10), @@rowcount) +'''where invoice_number=''' +@PRINTOUT_FILEID+''''
						print @sql
						exec (@sql)
						
						Fetch Next From Path_cur_Mecreditdebit Into @PRINTOUT_FILEID
				END
					Close Path_cur_Mecreditdebit
					DeAllocate Path_cur_Mecreditdebit 
					
Set @sql= 'Update ' +@EBPDC_OUTPUT_FILEID+ ' set PRINTOUT_DESTINATION_PATH=''PDF found'' where PRINTOUT_DESTINATION_PATH=''2'''
EXEC(@sql)
--select @sql
		
Set @sql= 'Update ' +@EBPDC_OUTPUT_FILEID+ ' set PRINTOUT_DESTINATION_PATH=''File Not found'' where PRINTOUT_DESTINATION_PATH=''1'''
EXEC(@sql)
			
	--- Added on 18/1/2019 to include new source folder for consumables
	DECLARE Path_cur_Consumables Cursor LOCAL STATIC READ_ONLY FORWARD_ONLY For
		select invoice_number from e_invoice_v2 where PRINTOUT_DESTINATION_PATH like 'File%'
		Open Path_cur_Consumables 
			Fetch Next From Path_cur_Consumables Into @PRINTOUT_FILEID
				While @@Fetch_Status = 0 
				BEGIN
					--SET @SO_CMD = 'for /r \\DC-PAXFS01\CSPL_AFusion_Archive$\AX\FAD\Temp %f in (*'+@PRINTOUT_FILEID+'*.pdf) do @copy "%f" \\DC-PAXFS01\eBPdocument$\UAT\CSPL'
					--SET @SO_CMD = 'for /r '+@path+' %f in (*'+@PRINTOUT_FILEID+'*.pdf) do @copy "%f" \\DC-PAXFS01\eBPdocument$\UAT\CSPL'
						SET @SO_CMD = 'for /r '+@Consumables_path+' %f in (*'+@PRINTOUT_FILEID+'*.pdf) do @copy "%f" ' + @Dest_path
						
						exec xp_cmdshell @SO_CMD
						
						SET @sql = 'UPDATE '+@EBPDC_OUTPUT_FILEID+' set PRINTOUT_DESTINATION_PATH= '''+CONVERT(varchar(10), @@rowcount) +'''where invoice_number=''' +@PRINTOUT_FILEID+''''
						print @sql
						exec (@sql)
						
						Fetch Next From Path_cur_Consumables Into @PRINTOUT_FILEID
				END
					Close Path_cur_Consumables
					DeAllocate Path_cur_Consumables 
					
Set @sql= 'Update ' +@EBPDC_OUTPUT_FILEID+ ' set PRINTOUT_DESTINATION_PATH=''PDF found'' where PRINTOUT_DESTINATION_PATH=''2'''
EXEC(@sql)
--select @sql
		
Set @sql= 'Update ' +@EBPDC_OUTPUT_FILEID+ ' set PRINTOUT_DESTINATION_PATH=''File Not found'' where PRINTOUT_DESTINATION_PATH=''1'''
EXEC(@sql)
					
			
		END
		
	
GO


