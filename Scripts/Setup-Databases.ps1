[CmdletBinding()]
param (
    [Parameter(HelpMessage = "Server Instance")]
    [String]
    $ServerInstance = '10.0.0.5',
    [Parameter(HelpMessage = "Path to backup files")]
    [String]
    $SQLBackupPath = 'C:\WorkingFiles\v5_Databases\',
    [Parameter(HelpMessage = "Path to SQLData (Leave Empty for Server Default)")]
    $SQLDataPath,
    [Parameter(HelpMessage = "Path to SQLLogs (Leave Empty for Server Default)")]
    $SQLLogPath,
    [Parameter(HelpMessage = "Path to install logs")]
    $InstallLogsPath = 'C:\MNP\InstallLogs'
)

#region Load Install Support Module
Remove-Module MEInstallTools -Force -ErrorAction SilentlyContinue
If (Get-Module -ListAvailable -Name MEInstallTools) {
    Import-Module MEInstallTools
}
else {
    $Module = (Get-ChildItem -Path .\src\* -Recurse -Include 'MEInstallTools.psd1' | Select -First 1).FullName
    Import-Module $Module
}
#endregion Load Install Support Module
Install-Modules -Modules @('PackageManagement', 'Logging', 'SqlServer')
#region SQLQueries
DATA Query {
    @"
DECLARE @xp_cmdshell INT
DECLARE @show_advanced_options INT
SELECT @show_advanced_options = CONVERT(INT, ISNULL(value, value_in_use)) --AS config_value
FROM  sys.configurations
WHERE  name = 'show advanced options' ;
IF @show_advanced_options = 0
BEGIN
	-- To allow advanced options to be changed.
	EXECUTE sp_configure 'show advanced options', 1;
	-- To update the currently configured value for advanced options.
	RECONFIGURE;
END
SELECT @xp_cmdshell = CONVERT(INT, ISNULL(value, value_in_use)) --AS config_value
FROM  sys.configurations
WHERE  name = 'xp_cmdshell' ;

IF @xp_cmdshell = 0
BEGIN
	-- To enable the feature.
	EXECUTE sp_configure 'xp_cmdshell', 1;
	-- To update the currently configured value for this feature.
	RECONFIGURE;
END


DECLARE @BACKUPFILENAME VARCHAR(MAX) = ''
DECLARE @MDFLOGICALNAME NVARCHAR(100)
DECLARE @LDFLOGICALNAME NVARCHAR(100)
DECLARE @DEST_PATH NVARCHAR(100)
DECLARE @DEST_LOGPATH NVARCHAR(100)
DECLARE @SQL NVARCHAR(MAX)
DECLARE @DATABASENAME SYSNAME
DECLARE @RESULTS TABLE (
	[Restore Time] DATETIME,
	[Database Name] NVARCHAR(100)
	);

DROP TABLE IF EXISTS #TFILELISTONLY,#TRAILUPGRADEBACKUPFILES

CREATE TABLE #TRAILUPGRADEBACKUPFILES (ID INT IDENTITY(1,1),FILENAME SYSNAME,RESTORE_DRIVE CHAR(1))

/*********************************************************************************************************************************/
--The below code fetches the file list(backup file names) to be restored from the pre-defined folder
DECLARE @CommandShell TABLE ( Line VARCHAR(512))
DECLARE  @CMD VARCHAR(512) ,@BackupFilePath NVARCHAR(256)
SET @BackupFilePath = '`$(BackupPath)'
SET @CMD = 'DIR /B ' + @BackupFilePath +  ' /TC'

INSERT INTO @CommandShell EXEC MASTER..xp_cmdshell   @CMD
-- Delete lines not containing filename
DELETE
FROM   @CommandShell
WHERE  Line is null

If((Select Top 1 Line From @CommandShell) = 'Access is denied.')
BEGIN
	PRINT 'Folder access is not provided for network path'
	GOTO FINISH
END
INSERT INTO #TRAILUPGRADEBACKUPFILES (FILENAME)
	Select * From @CommandShell A WHERE CHARINDEX('.BAK',LINE) > 0

--Cleanup of system databases
Delete From #TRAILUPGRADEBACKUPFILES where Filename in( 'master.bak','msdb.bak','model.bak','tempdb.bak','resource.bak'
--Add if you have any special list to be ignored (examples as below)
--,'DBAMaintenance.bak','DBATools.bak'
)

/*********************************************************************************************************************************/

CREATE TABLE #TFILELISTONLY
(
    TLOGINNAME SYSNAME,TPHYSICALNAME VARCHAR(MAX),
    TTYPE VARCHAR(1),TFILEGROUPNAME  VARCHAR(MAX),
    TSIZE BIGINT,TMAXSIZE BIGINT,TFIELD  VARCHAR(MAX),
    TCREATELSN VARCHAR(MAX),TDROPLSN VARCHAR(MAX),
    TUNIQUEID VARCHAR(MAX),READONLYLSN VARCHAR(MAX),
    READWRITELSN VARCHAR(MAX),BACKUPSIZEINBYTES VARCHAR(MAX),
    SOURCEBLOCKSIZE VARCHAR(MAX),FILEGROUPID VARCHAR(MAX),
    LOGGROUPGUID VARCHAR(MAX),DIFFERENTIALLSN VARCHAR(MAX),
    DIFFERENTIALBASEGUID VARCHAR(MAX),ISREADONLY VARCHAR(MAX),
    ISPRESENT VARCHAR(MAX),TDEHUMBPRINT VARCHAR(MAX),
    SNAPSHORTURL VARCHAR(MAX) -- Add this for higher version of SQL Server
)

WHILE EXISTS(SELECT 1 FROM #TRAILUPGRADEBACKUPFILES)
BEGIN

	SET @BACKUPFILENAME = (SELECT TOP 1 FILENAME FROM #TRAILUPGRADEBACKUPFILES ORDER BY FILENAME ASC)
	--Restore Path needs to be provided in the below
    SET @DEST_PATH = '`$(DataPath)'
    SET @DEST_LOGPATH = '`$(LogPath)'

	SET @DATABASENAME = (SUBSTRING(@BACKUPFILENAME,0,CHARINDEX('.',@BACKUPFILENAME)))

	--To check if the database is already present in the environment, If present, Drop the database
	IF Exists(SELECT 1 FROM master.sys.databases WHERE name = @DATABASENAME)
	BEGIN
		EXEC('DROP Database '+@DATABASENAME)
		Print @BACKUPFILENAME + ' has been successfully dropped.'
	END

	INSERT INTO #TFILELISTONLY
		EXEC ('RESTORE FILELISTONLY FROM DISK ='''+ @BackupFilePath +  @BACKUPFILENAME+'''')

	SET @MDFLOGICALNAME = (SELECT TLOGINNAME FROM #TFILELISTONLY WHERE TTYPE ='D')
	SELECT @LDFLOGICALNAME = (SELECT TLOGINNAME FROM #TFILELISTONLY WHERE TTYPE ='L')

	SELECT @SQL ='RESTORE DATABASE ' + @DATABASENAME + ' FROM DISK = ''' +  @BackupFilePath + @BACKUPFILENAME + '''
		WITH MOVE ''' + @MDFLOGICALNAME + ''' TO ''' + @DEST_PATH + @DATABASENAME + '.MDF'',
		MOVE '''  + +  @LDFLOGICALNAME + ''' TO ''' + @DEST_LOGPATH + @DATABASENAME + '.LDF'''

	EXEC (@SQL)
	Print @BACKUPFILENAME + ' has been successfully restored.'
	INSERT INTO @RESULTS (	[Restore Time],
	[Database Name]) (SELECT GETDATE(), @DATABASENAME)
	--EXEC ('ALTER DATABASE [' + @DATABASENAME + '] SET RECOVERY SIMPLE;')

	DELETE FROM #TFILELISTONLY


	DELETE FROM #TRAILUPGRADEBACKUPFILES WHERE FILENAME =@BACKUPFILENAME

END

FINISH:

IF @xp_cmdshell = 0
BEGIN
	-- To enable the feature.
	EXECUTE sp_configure 'xp_cmdshell', 0;
	-- To update the currently configured value for this feature.
	RECONFIGURE;
END


IF @show_advanced_options = 0
BEGIN
	-- To allow advanced options to be changed.
	EXECUTE sp_configure 'show advanced options', 0;
	-- To update the currently configured value for advanced options.
	RECONFIGURE;
END
SELECT * FROM @RESULTS
"@
}
DATA DropOrphanedUsersCommand {
    @"
 set nocount on
 -- get orphaned users
 declare @user varchar(max)
 declare c_orphaned_user cursor for
  select name
  from sys.database_principals
  where type in ('G','S','U')
  and authentication_type<>2 -- Use this filter only if you are running on SQL Server 2012 and major versions and you have "contained databases"
  and [sid] not in ( select [sid] from sys.server_principals where type in ('G','S','U') )
  and name not in ('dbo','guest','INFORMATION_SCHEMA','sys','MS_DataCollectorInternalUser')  open c_orphaned_user
 fetch next from c_orphaned_user into @user
 while(@@FETCH_STATUS=0)
 begin
  -- alter schemas for user
  declare @schema_name varchar(max)
  declare c_schema cursor for
   select name from  sys.schemas where USER_NAME(principal_id)=@user
  open c_schema
  fetch next from c_schema into @schema_name
  while (@@FETCH_STATUS=0)
  begin
   declare @sql_schema varchar(max)
   select @sql_schema='ALTER AUTHORIZATION ON SCHEMA::['+@schema_name+ '] TO [dbo]'
   print @sql_schema
   exec(@sql_schema)
   fetch next from c_schema into @schema_name
  end
  close c_schema
  deallocate c_schema

  -- alter roles for user
  declare @dp_name varchar(max)
  declare c_database_principal cursor for
   select name from sys.database_principals
   where type='R' and user_name(owning_principal_id)=@user
  open c_database_principal
  fetch next from c_database_principal into @dp_name
  while (@@FETCH_STATUS=0)
  begin
   declare @sql_database_principal  varchar(max)
   select @sql_database_principal ='ALTER AUTHORIZATION ON ROLE::['+@dp_name+ '] TO [dbo]'
   print @sql_database_principal
   exec(@sql_database_principal )
   fetch next from c_database_principal into @dp_name
  end
  close c_database_principal
  deallocate c_database_principal

  -- drop roles for user
  declare @role_name varchar(max)
  declare c_role cursor for
   select dp.name--,USER_NAME(member_principal_id)
   from sys.database_role_members drm
   inner join sys.database_principals dp
   on dp.principal_id= drm.role_principal_id
   where USER_NAME(member_principal_id)=@user
  open c_role
  fetch next from c_role into @role_name
  while (@@FETCH_STATUS=0)
  begin
   declare @sql_role varchar(max)
   select @sql_role='EXEC sp_droprolemember N'''+@role_name+''', N'''+@user+''''
   print @sql_role
   exec (@sql_role)
   fetch next from c_role into @role_name
  end
  close c_role
  deallocate c_role

  -- drop user
  declare @sql_user varchar(max)
  set @sql_user='DROP USER ['+@user +']'
  print @sql_user
  exec (@sql_user)
  fetch next from c_orphaned_user into @user
 end
 close c_orphaned_user
 deallocate c_orphaned_user
 set nocount off
"@
}
#endregion SQLQueries
# Get User Input for Parameters not explicitly set
#region Initialise
$MyInvocation.MyCommand.Parameters.Keys | where { -not $PSBoundParameters.ContainsKey($_) -and `
        $_ -notin ([System.Management.Automation.Cmdlet]::CommonParameters) } |
ForEach-Object {
    $Param = $MyInvocation.MyCommand.Parameters[$_]
    $value = $null
    $Message = $Param.Attributes[0].HelpMessage
    $default = (Get-Variable -Name $_).Value
    If (!([string]::IsNullOrEmpty($Message))) {
        if (!($value = Read-Host "$Message [$default]")) { $value = $default }
        Set-Variable -Name $_ -Value $value
    }
}

# Set Script Variables and configure logging
New-Item -Path $InstallLogsPath -ItemType Directory -Force | Out-Null
$scriptName = (Get-ChildItem $MyInvocation.MyCommand.Path).BaseName
$Date = Get-Date -Format "yyyyMMdd"
$LastFile = Get-ChildItem (Join-Path $InstallLogsPath "$($scriptName)_$($Date)_*.log") | Sort-Object Name
If ($LastFile){
    $LastFile.Name -match '\d+(?=\.)'
    $Sequence = "{0:D2}" -f (([Int]$Matches[0])+1)
} else {
    $Sequence = '00'
}
#$logFileName = Join-Path $InstallLogsPath "$($scriptName)_%{+%Y%m%d}.log"
$logFileName = Join-Path $InstallLogsPath "$($scriptName)_$($Date)_$Sequence.log"
Set-LoggingDefaultLevel -Level 'DEBUG'
Set-LoggingDefaultFormat '[%{timestamp:+%T%Z}] [%{level:-7}] %{message}'
Add-LoggingTarget -Name Console -Configuration @{Format = '[%{timestamp:+%T} %{level:-7}] %{message}' }
Add-LoggingTarget -Name File -Configuration @{Path = $logFileName
    Format                                         = '[%{timestamp:+%T%Z}] [%{level:-7}] %{message}'
}
Write-Log -Level INFO -Message "Running Script $scriptName"

# Print all Parameters Values if Verbose
$Title = " Parameter Values "
Write-Log -Level INFO -Message '{0}' -Arguments $Title.PadLeft(40 + ($Title.Length / 2), '*').PadRight(80, '*')
$Length = ($MyInvocation.MyCommand.Parameters.Keys | where {
        $_ -notin ([System.Management.Automation.Cmdlet]::CommonParameters) } | Sort-Object { $_.name.length }  | select -last 1).length
$MyInvocation.MyCommand.Parameters.Keys | where {
    $_ -notin ([System.Management.Automation.Cmdlet]::CommonParameters) } |
ForEach-Object {
    $param = Get-Variable -Name $_
    Write-Log -Level INFO -Message "`t{0}:`t{1}" -Arguments @($param.Name.PadRight($Length, ' '), $param.Value)
    #Write-Verbose "$($param.Name) --> $($param.Value)"
}
$Title = ""
Write-Log -Level INFO -Message '{0}' -Arguments $Title.PadLeft(40 + ($Title.Length / 2), '*').PadRight(80, '*')

# Create all Path's set in parameters
$MyInvocation.MyCommand.Parameters.Keys | where {
    $_ -notin ([System.Management.Automation.Cmdlet]::CommonParameters) -and $_ -like '*Path*' } |
ForEach-Object {
    $param = Get-Variable -Name $_
    IF ($param.Value) {
        If (Test-Path -Path $param.Value -PathType Container) {
            Write-Log -Level INFO -Message '{0} folder {1} exists' -Arguments @($param.Name, $param.Value)
        }
        else {
            New-Item -Path $param.Value -Force -ItemType Directory | Out-Null
            Write-Log -Level WARNING -Message '{0} folder {1} created' -Arguments @($param.Name, $param.Value)
        }
    }
}
#endregion
$ServerParams = @{
    ServerInstance = $ServerInstance
}
#region CheckSQLConnection
Write-Log -Level INFO 'Connecting to SQL Server {0}' -Arguments $ServerInstance
$ServerInfo = Get-SQLServerInfo @ServerParams
if (!($ServerInfo)) {
    Write-Log -Level ERROR "`tFailed to retrieve server data - EXITING"
    Exit
}
Write-Log -Level INFO -Message "`tSQL Version {0}" -Arguments $ServerInfo.Version
Write-Log -Level DEBUG -Message "`tSQLServer Name {0}" -Arguments $ServerInfo.ServerName
Write-Log -Level DEBUG -Message "`tConnected as Login {0}" -Arguments $ServerInfo.Login
Write-Log -Level DEBUG -Message "`tConnected to Database {0} as User {1}" -Arguments $ServerInfo.DBName, $ServerInfo.User
if (!($ServerInfo.IsAdmin)) {
    Write-Log -Level ERROR -Message "`tLogin {0} is not a member of 'sysadmin' role" -Arguments $ServerInfo.Login
    Exit
}
#endregion
if (!($SQLBackupPath)) {
    $SQLBackupPath = $ServerInfo.Default_Backup_path
}
if (!($SQLBackupPath.EndsWith('\'))) {
    $SQLBackupPath += '\'
}
if (!($SQLDataPath)) {
    $SQLDataPath = $ServerInfo.Default_Data_path
}
if (!($SQLDataPath.EndsWith('\'))) {
    $SQLDataPath += '\'
}
if (!($SQLLogPath)) {
    $SQLLogPath = $ServerInfo.Default_log_path
}
if (!($SQLLogPath.EndsWith('\'))) {
    $SQLLogPath += '\'
}

$Variable = @("BackupPath=$SQLBackupPath", "DataPath=$SQLDataPath", "LogPath=$SQLLogPath")
Write-Log -Level INFO -Message "Restoring Databases From {0}" -Arguments $SQLBackupPath
Write-Log -Level DEBUG -Message "`tData Path: {0}" -Arguments $SQLDataPath
Write-Log -Level DEBUG -Message "`tLog Path : {0}" -Arguments $SQLLogPath
$RestoreLogFile = Join-Path (Split-Path $logFileName -Parent) "SQLRestore_$(Split-Path $LogFileName -Leaf)"
$Restores = Invoke-Sqlcmd @ServerParams -Query $Query -Verbose -Variable $Variable 4> $RestoreLogFile
Write-Log -Level INFO -Message "Restored {0} databases from {1}" -Arguments @($Restores.Count, $SQLBackupPath)
foreach ($db in $Restores) {
    Invoke-Sqlcmd @ServerParams -Query $DropOrphanedUsersCommand -Database $DB[1] -Verbose
    Write-Log -Level INFO -Message "Removing Orphaned Users from Database {0}" -Arguments $DB[1]
}
Write-Log -Level INFO -Message "Script Completed"
Wait-Logging
Write-Output ""