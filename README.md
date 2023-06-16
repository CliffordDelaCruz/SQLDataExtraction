# SQLDataExtraction
Stored Procedure created to extract data towards shared folder. Note that destination folder deliberately changed for security purposes

Here are the table list:
tblEBPDataFilter - For filtering out data to be extracted. This means there are only selected data to be extracted.
tblEBPDataConfig - This contains information where the extracted data will be saved, what file name

Invoice related data extraction:
sp_EBP_EInvoice_daily_V2
sp_EBP_EInvoice_Daily_V2_INCL_TEMP
sp_EBP_Output_DataFile_einvoice
