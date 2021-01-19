$SQLParams = @{ServerInstance='localhost'}
$OrderFilesPath='C:\MNP\OrderFiles1'
$Query_Update = @"
DECLARE @SQL VARCHAR(MAX)
SELECT @SQL = COALESCE(@SQL + CHAR(10),'') + 'UPDATE ' + OBJECT_NAME(object_id) + ' SET ['+ Name + '] = REPLACE(['+ Name + '],''`$(String)'', ''`$(Replacement)'') '
	from  SYS.columns where name LIKE '%Directory%' And TYPE_NAME(system_type_id) IN ('nchar','nvarchar','char','varchar')
PRINT @SQL
EXEC (@SQL)
"@
SQLSERVER\Invoke-Sqlcmd @SQLParams -Database 'MNPServiceCfg' -Query $Query_Update -Variable @("ColumnName=%Directory%","String=C:\MNP\OrderFiles","Replacement=$OrderFilesPath")

$WebRelayInstanceDataRows = Invoke-Sqlcmd @SQLParams -Database 'MNPServiceCfg' -Query 'Select * From WebRelayInstance'
foreach ($row in $WebRelayInstanceDataRows) {
    $row.ItemArray | Where-Object {$_ -like "*$OrderFilesPath*" -and (Test-Path $_ -IsValid)}
}
