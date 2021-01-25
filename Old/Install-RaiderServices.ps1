#requires -version 3
#Requires -Modules @{ ModuleName="PackageManagement"; ModuleVersion="1.4.6" }
#Requires -Modules Logging
#Requires -Modules SharePointPnPPowerShellOnline
<#
.SYNOPSIS
  This script will assist installing Raider Services Application

.DESCRIPTION
  This script will check and log all the prerequisites, download and install the neccessary
  software before starting the service applications for basic configuration

.PARAMETER <Parameter_Name>
    <Brief description of parameter input required. Repeat this attribute if required>

.INPUTS
  <Inputs if any, otherwise state None>

.OUTPUTS
  <Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>

.NOTES
  Version:        1.0

  Author:         <Name>
  Creation Date:  <Date>
  Purpose/Change: Initial script development

.EXAMPLE
  <Example goes here. Repeat this attribute for more than one example>
#>

[CmdletBinding()]
param (
)

function Set-Logging {
    param (
        # Initialise Logging
        [Parameter()]
        [string]$LogPath = '.\Logs',
        # Default Logging
        [Parameter()]
        [ValidateSet('DEBUG', 'INFO', 'WARNING', 'ERROR')]
        [String]$DefaultLevel = 'WARNING',
        # File Logging Level
        [Parameter()]
        [ValidateSet('DEBUG', 'INFO', 'WARNING', 'ERROR')]
        [String]$FileLevel = 'DEBUG'

    )
    #Configure Logging
    $LogPath = '.\Logs'
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
    Set-LoggingDefaultLevel -Level $DefaultLevel
    Add-LoggingTarget -Name Console
    Add-LoggingTarget -Name File -Configuration @{
        Path      = $(Join-Path $LogPath "$($MyInvocation.MyCommand.Name)_%{+%Y%m%d}.log") # <Required> Sets the file destination (eg. 'C:\Temp\%{+%Y%m%d}.log')
        #            It supports templating like $Logging.Format
        PrintBody = $false            # <Not required> Prints body message too
        Append    = $true             # <Not required> Append to log file
        Encoding  = 'ascii'           # <Not required> Sets the log file encoding
        Level     = $FileLevel          # <Not required> Sets the logging level for this target
        #Format      = <NOTSET>          # <Not required> Sets the logging format for this target
    }


}

function New-Password {
    param (
        [Int]$Length = 15
    )
    try {
        [reflection.assembly]::loadwithpartialname("system.web") | Out-Null
    }
    catch {
        Write-Log -Level ERROR -Message 'Unable to load module to create new password'
    }
    do {
        $Password = [System.Web.Security.Membership]::GeneratePassword($Length, 3)
    } until (!($Password.Contains(';') -or ($Password.Contains("'"))))

    Return ConvertTo-SecureString -String "$Password" -AsPlainText -Force
}
function Get-SQLLoginCredentials {
    param (
        # Name Of SQL Server Instance
        [Parameter(Mandatory)]
        [String]$SQLInstance,
        # Name Of SQL Server User Login
        [Parameter(Mandatory)]
        [String]$LoginName,
        # Specifies a path to where the credentials are stored.
        [Parameter(Mandatory = $true)]
        [Alias("WorkingPath")]
        [ValidateNotNullOrEmpty()]
        [String]$WorkingFolder,
        # AutoCreate Credentials
        [Parameter()]
        [Switch]$CreatePassword
    )
    process {
        New-Item -Path $WorkingFolder -Force -ItemType Directory | Out-Null
        $CredentialFile = Join-Path -Path $WorkingFolder -ChildPath "$SQLInstance.$LoginName.xml"
        If (Test-Path -Path $CredentialFile -PathType Leaf) {
            Write-Log -Level DEBUG -Message 'Loading Secure Credential File {0}.{1}.xml'`
                -Arguments @($SQLInstance, $LoginName)
            try {
                [PSCredential]$Result = Import-Clixml $CredentialFile
            }
            catch {
                Write-Log -Level ERROR -Message 'Error opening credential file {0}' -Arguments $CredentialFile
                Wait-Logging
                if ($CreatePassword) {
                    Write-Log -Level WARNING -Message 'Generating Password for {0} on SQLServer {1}'`
                        -Arguments @($SQLInstance, $DBLogin)
                    $PW = New-Password
                    $Result = New-Object PSCredential $LoginName, $PW
                }
                else {
                    $Result = Get-Credential -Message "Enter SQL Login Password for $LoginName on $SQLInstance"`
                        -UserName "$LoginName"
                }
                Write-Log -Level DEBUG -Message 'Saving Secure Credential File {0}.{1}.xml'`
                    -Arguments @($SQLInstance, $LoginName)
                Export-Clixml -InputObject $Result -Path $CredentialFile -Force
            }
        }
        else {
            Wait-Logging
            if ($CreatePassword) {
                Write-Log -Level WARNING -Message 'Generating Password for {0} on SQLServer {1}'`
                    -Arguments @($SQLInstance, $DBLogin)
                $PW = New-Password
                $Result = New-Object PSCredential $LoginName, $PW
            }
            else {
                $Result = Get-Credential -Message "Enter SQL Login Password for $LoginName on $SQLInstance"`
                    -UserName "$LoginName"
            }
            Write-Log -Level DEBUG -Message 'Saving Secure Credential File {0}.{1}.xml'`
                -Arguments @($SQLInstance, $LoginName)
            Export-Clixml -InputObject $Result -Path $CredentialFile -Force
        }
    }
    end {
        Return $Result
    }
}
function Test-SQLConnection {
    param (
        $SQLConnection
    )

    $TestString = 'SELECT @@ServerName'
    try {
        $Result = (Invoke-Sqlcmd @SQLConnection -Query $TestString -Verbose -ErrorAction SilentlyContinue).GetType().Name -eq 'DataRow'
    }
    catch {
        $Result = $false
    }
    Return $Result
}
function Get-PlainCredential {
    param (
        $Connection
    )
    IF ($Connection.ContainsKey('Credential')) {
        $USER = $Connection.Credential.UserName
        $PASS = ConvertTo-PlainText $Connection.Credential.Password
    }
    else {
        $USER = $Connection.UserName
        $PASS = $Connection.Password
    }
    Return @{User = $USER
        Pass      = $PASS
    }
}

function Set-SQLLogin {
    param (
        $AdminConnection,
        $TestConnection
    )
    $USER = (Get-PlainCredential $TestConnection).User
    $PASS = (Get-PlainCredential $TestConnection).Pass
    $Query = @"
    IF SUSER_ID (N'$USER') IS NULL
    CREATE LOGIN [$USER] WITH PASSWORD=N'$PASS'
    ELSE
    ALTER LOGIN [$USER] WITH PASSWORD=N'$PASS'
"@
    $PASS = $null
    Invoke-Sqlcmd @AdminConnection -Query $Query -Verbose
    $Query = $null
}

function Test-Database {
    param (
        $DBName,
        $AdminConnection,
        $AppConnection,
        $DBRole = 'db_owner'
    )
    $DBUser = (Get-PlainCredential -Connection $AppConnection).User
    $Query = @"
    use master
    IF DB_ID(N'$DBName') IS NOT NULL
    BEGIN
        IF NOT EXISTS(
        Select *
            From $DBName.sys.server_principals SP
            JOIN $DBName.sys.database_principals DP ON DP.sid = SP.sid
            LEFT OUTER JOIN $DBName.sys.sysmembers Members ON dp.principal_id = Members.memberuid
            where sp.name='$DBUser' and USER_NAME([groupuid])='$DBRole')
        BEGIN
            declare @sql varchar(200)
            IF NOT EXISTS(
                Select *
                From $DBName.sys.server_principals SP
                JOIN $DBName.sys.database_principals DP ON DP.sid = SP.sid
                where sp.name='$DBUser')
            BEGIN
                select @sql = 'USE $DBName;	CREATE USER $DBUser FOR LOGIN $DBUser WITH DEFAULT_SCHEMA=[dbo]; EXEC sp_addrolemember N''$DBrole'', N''$DBUser'' '
                EXEC sp_sqlexec @Sql
                PRINT 'OrderActive Created and added to role'
            END
            ELSE
            BEGIN
                select @sql = 'USE $DBName;	EXEC sp_addrolemember N''$DBRole'', N''$DBUser'' '
                EXEC sp_sqlexec @Sql
                PRINT 'OrderActive Added to Role'
            END
        END
        SELECT CAST(1 AS BIT)
    END
    ELSE
    SELECT CAST(0 AS BIT)
"@
    Set-Clipboard $Query
    try {
        $Result = Invoke-Sqlcmd @AdminConnection -Query $Query
    }
    catch {
        Write-Log -Level ERROR -Message $_
        $Result = $false
    }
    Return $Result

}

Function Test-ODBCConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True,
            HelpMessage = "DSN name of ODBC connection")]
        [string]$DSN,
        $Connection
    )
    $conn = new-object system.data.odbc.odbcconnection
    If ($Connection) {
        $PlainCredential = Get-PlainCredential -Connection $Connection
        If (!([String]::IsNullOrEmpty($PlainCredential.User) -or [String]::IsNullOrEmpty($PlainCredential.Pass))) {
            $conn.connectionstring = "DSN=$DSN;Uid=$($PlainCredential.User);Pwd=$($PlainCredential.Pass)"
            Write-Log -Level DEBUG -Message "Set ODBC DSN for UserID" -Arguments $PlainCredential.User
        }
        else {
            Write-Log -Level ERROR -Message 'Failed to retrieve Credentials for User'
        }
    }
    else {
        Write-Log -Level DEBUG -Message "Testing ODBC without credentials"
        $conn.connectionstring = "DSN=$DSN"
    }

    try {
        $conn.Open()
        if (($conn.State) -eq 'Open') {
            $conn.Close()
            $true
        }
        else {
            $false
        }
    }
    catch {
        Write-Log -Level ERROR "Function Test-ODBCConnection Error"
        Write-Log -Level ERROR -Message $_.Exception.Message
        $false
    }
}
function ConvertTo-PlainText {
    param (
        [SecureString]$EncryptedString
    )
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($EncryptedString)
    Return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)


}
function Get-SharepointFolder {
    param (
        [String]
        $SiteURL,
        [String]
        $SiteFolder,
        [System.Management.Automation.PSCredential]
        $SiteCred,
        [String]
        $LocalFolder
    )
    New-Item -Path $LocalFolder -ItemType Directory -Force | Out-Null
    try {
        #Connecting to SharePoint site
        Connect-PnPOnline -Url $SiteURL -Credentials $SiteCred
        #Get List of Files in Folder
        $Files = Get-PnPFolderItem -FolderSiteRelativeUrl $SiteFolder -ItemType File
        Write-Log -Level DEBUG -Message "Downloading {0} Files" -Arguments ($Files).Count
        $ResultList = @()
        foreach ($File in $Files) {
            Get-PnPFile -Url $File.ServerRelativeUrl -Path $LocalFolder -FileName $File.Name -AsFile  -Force
            Write-Log -Level DEBUG -Message "Downloaded {0}" -Arguments $File.Name
            $ResultList = $ResultList += $(Join-Path -Path $LocalFolder -ChildPath $File.Name)
        }
    }
    catch {
        Write-Log -Level ERROR -Message "Error Downloading {0)" -Arguments $_.Message
        Return -1
    }
    Return $ResultList
}
function New-SQLConnectionParams {
    param (
        $ServerInstance = 'localhost',
        [PSCredential]$PSCredentials
    )
    $Result = @{ServerInstance = $ServerInstance }
    if ($PSCredentials) {
        if ((Get-Command Invoke-Sqlcmd).Parameters.ContainsKey('Credential')) {
            $Result['Credential'] = $PSCredentials
        }
        else {
            $Result['UserName'] = $PSCredentials.UserName
            $Result['Password'] = ConvertTo-PlainText $PSCredentials.Password
        }
    }
    Return $Result
}

function Invoke-RetryCommand {
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Position = 1, Mandatory = $false)]
        [int]$Maximum = 3,

        [Parameter(Position = 2, Mandatory = $false)]
        [int]$Delay = 100,
        # Parameter help description
        [Parameter(Position = 3, Mandatory = $false)]
        [Scriptblock]
        $RecoveryBlock = {}
    )

    Begin {
        $cnt = 0
    }

    Process {
        do {
            $cnt++
            try {
                $ScriptBlock.Invoke()
                return
            }
            catch {
                Write-Log -Level Error -Message $_.Exception.InnerException.Message
                # Write-Error $_.Exception.InnerException.Message -ErrorAction Continue
                Start-Sleep -Milliseconds $Delay
                $RecoveryBlock.Invoke()
                if ($cnt -ne $Maximum) {
                    Write-Log -Level WARNING -Message 'Retry {0} of {1}'`
                        -Arguments @(($cnt + 1), $Maximum )
                }

            }
        } while ($cnt -lt $Maximum)

        # Throw an error after $Maximum unsuccessful invocations. Doesn't need
        # a condition, since the function returns upon successful invocation.
        throw 'Execution failed.'
    }
}

#Set-ODBCConnection -DBName $DBName -Connection $AppConnection
function Set-ODBCConnection {
    param (
        $DBName,
        $Connection
    )
    If (Test-IsAdmin) {
        $DSNType = 'System'
    }
    else {
        $DSNType = 'User'
    }
    $HashArguments = @{
        Name             = "$DBName"
        DriverName       = "SQL Server Native Client 11.0"
        SetPropertyValue = @("Server=$($Connection.ServerInstance)",
            "Trusted_Connection=No",
            "Database=$DBName")
        #Platform         = '32-bit'
        DsnType          = $DSNType
    }
    if (!(Get-OdbcDsn -Name $DBName -ea SilentlyContinue -Platform '32-Bit')) {
        Add-OdbcDsn @HashArguments -Platform '32-bit'
    }
    if (!(Get-OdbcDsn -Name $DBName -ea SilentlyContinue -Platform '64-Bit')) {
        Add-OdbcDsn @HashArguments -Platform '64-bit'
    }
    IF (!(Test-ODBCConnection -DSN $DBName -Connection $Connection)) {
        if (Get-OdbcDsn -Name $DBName -ea SilentlyContinue) {
            Get-OdbcDsn -Name $DBName | ForEach-Object {
                Write-Log -Level WARNING -Message "Removing ODBCDsn Name {0}: Type:{1} Platform {2}" -Arguments @($_.Name, $_.DSNType, $_.Platform)
                Remove-OdbcDsn -InputObject $_
            }
        }
        Write-Log -Level DEBUG -Message "Adding ODBCDsn Name {0}: Type:{1} Platform {2}" -Arguments @($HashArguments['Name'], $HashArguments['DSNType'], $HashArguments['Platform'])
        Add-OdbcDsn @HashArguments -Platform '32-bit'
        if (!(Get-OdbcDsn -Name $DBName -ea SilentlyContinue -Platform '64-Bit')) {
            Add-OdbcDsn @HashArguments -Platform '64-bit'
        }
        $Result = Test-ODBCConnection -DSN $DBName -Connection $Connection
        If ($Result -eq $true) {
            Write-Log -Level INFO -Message "ODBCDsn {0} Tested Succesfully" -Arguments  @($HashArguments['Name'], $HashArguments['DSNType'], $HashArguments['Platform'])
        }
        else {
            Write-Log -Level ERROR -Message "ODBCDsn {0} Failed to Connect" -Arguments  @($HashArguments['Name'], $HashArguments['DSNType'], $HashArguments['Platform'])
        }
    }
    else {
        Write-Log -Level INFO -Message "ODBCDsn {0} Tested Succesfully" -Arguments  @($DBName)
    }
}
function Test-IsAdmin {

    ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

}

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
#$ErrorActionPreference = "SilentlyContinue"

#Dot Source required Function Libraries
#. "Add_Functions.ps1"

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
$sScriptVersion = "1.0"
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force
#Configure Logging
Set-Logging -DefaultLevel INFO
Write-Log -Level DEBUG -Message "Executing $($MyInvocation.MyCommand.Name) Version $sScriptVersion"
#-----------------------------------------------------------[Execution]------------------------------------------------------------
$Folders = [Ordered]@{
    Working         = @{ Prompt = 'Working Folder'; Parent = ''; Default = 'C:\WorkingFiles' }
    InstallLogs     = @{ Prompt = ''; Parent = 'Working'; Default = 'Logs' }
    Credentials     = @{ Prompt = ''; Parent = 'Working'; Default = 'Credentials' }
    ReleasePath     = @{ Prompt = ''; Parent = 'Working'; Default = "MNP\Services-$((Get-Date).ToString("yyyy-MM-dd HHmm"))" }
    Application     = @{ Prompt = 'Application Folder'; Parent = ''; Default = 'C:\MNP' }
    AppSoftware     = @{ Prompt = ''; Parent = 'Application'; Default = 'Server' }
    AppBackup       = @{ Prompt = ''; Parent = 'Application'; Default = 'Backup' }
    AppLogs         = @{Prompt = ''; Parent = 'Application'; Default = 'Logs' }
    WebRelayPoll    = @{ Prompt = ''; Parent = 'Application'; Default = 'OrderFiles' }
    WebRelayErr     = @{ Prompt = ''; Parent = 'WebRelayPoll'; Default = 'Errors' }
    WebRelayOrphans = @{ Prompt = ''; Parent = 'WebRelayPoll'; Default = 'Orphans' }
    WebRelayProcess = @{ Prompt = ''; Parent = 'WebRelayPoll'; Default = 'Process' }
}
foreach ($key in $Folders.Keys) {
    $Result = ''
    if (!([string]::IsNullOrWhiteSpace($Folders[$key]['Prompt']))) {
        $Result = Read-Host -Prompt "Enter $($Folders[$key]['Prompt'])  [$($Folders[$key]['Default'])]"
    }
    if (([string]::IsNullOrWhiteSpace($Result))) {
        $Result = $Folders[$key]['Default']
    }
    if ([string]::IsNullOrWhiteSpace($Folders[$key]['Parent'])) {
        $Folders[$key]['FullName'] = $Result
    }
    else {
        $Folders[$key]['FullName'] = Join-Path -Path $Folders[$Folders[$key]['Parent']]['FullName'] -ChildPath $Result
    }
    New-Item -Path $Folders[$key]['FullName'] -Force -ItemType Directory | Out-Null
}

function Get-Input ($Default, $Prompt) {
    $Result = Read-Host -Prompt "$Prompt [$Default]"
    if (([string]::IsNullOrWhiteSpace($Result))) {
        $Result = $Default
    }
    Return $Result
}
[String]$ServerInstance = Get-Input -Default 'LOCALHOST' -Prompt 'Please Enter Database Server Instance'

$Result = Read-Host -Prompt "Enter Admin Account (Blank for Windows Auth) []"
if (!([string]::IsNullOrWhiteSpace($Result))) {
    $AdminCred = Get-Credential -UserName $Result -Message "Please Enter Password for user $Result"
}

$AppSQLLogin = Get-Input -Default 'OrderActive' -Prompt 'Please Enter Application User'
$CredFileName = (Join-Path $Folders['Credentials']['FullName'] "$ServerInstance.$AppSQLLogin.xml")
try {
    [PSCredential]$AppSQLCred = Import-Clixml -Path $CredFileName
}
catch {
    $PW = New-Password
    [PSCredential]$AppSQLCred = New-Object PSCredential $AppSQLLogin, $PW
    $NewAppPassword = $true
    #Get-Credential -Message 'Enter Credentials for MNP Sharepoint'
    Export-Clixml -Path $CredFileName -InputObject $AppSQLCred
}
$AppSQLRole = Get-Input -Default 'db_owner' -Prompt 'Please enter the required user role for the application user'

$CredFileName = (Join-Path $Folders['Credentials']['FullName'] 'O365.XML')
try {
    [PSCredential]$O365Cred = Import-Clixml -Path $CredFileName
}
catch {
    [PSCredential]$O365Cred = Get-Credential -Message 'Enter Credentials for MNP Sharepoint'
    Export-Clixml -Path $CredFileName -InputObject $O365Cred
}

#MNP Software Release Site
$MNPReleasesURL = Get-Input -Default 'https://mnpmedialtd.sharepoint.com/sites/Releases' -Prompt "MNP Releases Site"
#MNP SOftware Folder
$SharePointFolderPath = Get-Input -Default "Shared Documents/Latest/OrderActive.Services/Unicode" -Prompt "Software Folder"




if (!($AdminCred)) {
    $AdminConnection = New-SQLConnectionParams -ServerInstance $ServerInstance
}
else {
    $AdminConnection = New-SQLConnectionParams -ServerInstance $ServerInstance`
    -PSCredential $AdminCred
}

IF (Test-SQLConnection -SQLConnection $AdminConnection) {
    Write-Log -Level INFO -Message 'Successfully tested admin connection to SQLServer {0}'`
        -Arguments $AdminConnection.ServerInstance
}
else {
    Write-Log -Level ERROR -Message 'Admin connection to SQLServer {0} failed '`
        -Arguments $AdminConnection.ServerInstance
    Wait-Logging
    Return
}
$AppConnection = New-SQLConnectionParams -ServerInstance $ServerInstance `
    -PSCredentials (Get-SQLLoginCredentials -SQLInstance $ServerInstance `
        -LoginName $AppSQLLogin `
        -WorkingFolder $Folders['Credentials']['FullName'])

If ($NewAppPassword) {
    Set-SQLLogin -TestConnection $AppConnection -AdminConnection $AdminConnection
}
IF (Test-SQLConnection -SQLConnection $AppConnection) {
    Write-Log -Level INFO -Message 'Successfully tested Application connection to SQLServer {0}'`
        -Arguments $Application.ServerInstance
}
else {
    Write-Log -Level ERROR -Message 'Application connection to SQLServer {0} failed '`
        -Arguments $Application.ServerInstance
    Wait-Logging
    Return
}
$RequiredDatabases = @('MNPUserMaster', 'MNPServiceCfg', 'OrderActive')
$Continue = $true
foreach ($Database in $RequiredDatabases) {
    IF (!((Test-Database -AdminConnection $AdminConnection -DBName $Database -AppConnection $AppConnection -DBRole $AppSQLRole )[0])) {
        Write-Log -Level ERROR -Message 'Database {0} does not exist'`
            -Arguments $Database
        $Continue = $false
    }
    Else {
        Write-Log -Level DEBUG -Message 'Database {0} exists with correct permissions'`
            -Arguments $Database
    }
}
If ($Continue -eq $false) {
    Return
}
else {
    Write-Log -Level INFO 'All Databases Confirmed'
}

#Check SQL Objects
$Continue = $true
$DBObjectQuery = @"
select
 [database name] = DB_NAME()
,[schema name] =  SCHEMA_NAME([schema_id])
,name
,type [Object type]
,type_desc [Object type]
,create_date [create date]
,modify_date [last modify date]
,ROUTINE_DEFINITION
from sys.objects
left outer join information_schema.routines on name = SPECIFIC_NAME
"@
$CheckObjects = Get-Content .\Services-DBObjects.JSON | ConvertFrom-Json
$Continue = $true
foreach ($item in $CheckObjects) {
    Write-Log -Level INFO -Message 'Checking {0} for {1} objects' -Arguments @($item.Database, $item.RequiredObjects.count)
    $objects = Invoke-Sqlcmd @AppConnection -Query $DBObjectQuery -Database $item.Database -OutputAs DataTables
    # DataView rapid filter
    $dvObject = New-Object System.Data.DataView($objects)
    foreach ($object in $item.RequiredObjects) {
        $dvObject.RowFilter = "name = '$Object'"
        # Result
        if ($dvObject.Count -gt 0) {
            Write-Log -Level DEBUG -Message 'Database Object Found {0}' -Arguments $object
        }
        else {
            Write-Log -Level ERROR -Message 'Database Object Not Found : {0}' -Arguments $object
            $Continue = $false
        }
    }
}
If ($Continue -eq $false) {
    Return
}
else {
    Write-Log -Level INFO 'All Database Objects Confirmed'
}

#Create Basic Configuration in MNPServiceCfg
#Check Base Data or Run MNPServiceCfg_InitialData_Insert
$Query_Truncate = @'
TRUNCATE TABLE [dbo].[DistributeInstance]
TRUNCATE TABLE [dbo].[DistributeHeader]
TRUNCATE TABLE [dbo].[WebRelayHeader]
TRUNCATE TABLE [dbo].[WebRelayInstance]
TRUNCATE TABLE [dbo].[ConsoleHeader]
TRUNCATE TABLE [dbo].[MessagingHeader]
'@
Invoke-Sqlcmd @AppConnection -Query $Query_Truncate -Database 'MNPServiceCfg'
Invoke-Sqlcmd @AppConnection -InputFile MNPServiceCfg_InitialData_Insert.sql -Database 'MNPServiceCfg'
$IPAddress = (Test-Connection -ComputerName (hostname) -Count 1).IPV4Address.IPAddressToString
$PortList = @(2062, 2063, 2064, 2065)
foreach ($port in $PortList) {
    $WarningPreference = "SilentlyContinue"
    $ProgressPreference = 'SilentlyContinue'
    IF (!(Test-NetConnection -ComputerName 127.0.0.1 -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue)) {
        Break
    }
}
foreach ($Table in @('MessagingHeader', 'DistributeHeader', 'WebRelayHeader')) {
    $LogFileName = Join-Path $Folders['AppLogs']['FullName'] $Table.Replace('Header', 'Log.txt')
    $Query_Update = "UPDATE [dbo].[$Table] SET [IPAddress] = N'$IPAddress', [IPPort] = $port, [LogFile] = N'$LogFileName'"
    Invoke-Sqlcmd @AppConnection -Query $Query_Update -Database 'MNPServiceCfg'
}
$Query_Update = @"
UPDATE [dbo].[WebRelayInstance]
   SET [XMLErrorDirectory] = N'$($Folders['WebRelayErr']['FullName'])'
      ,[XMLPollDirectory] = N'$($Folders['WebRelayPoll']['FullName'])'
      ,[XMLProcessedDirectory] = N'$($Folders['WebRelayProcess']['FullName'])'
      ,[OrphanedFilesDirectory] = N'$($Folders['WebRelayOrphans']['FullName'])'
      ,[DBCnnString] = N'Driver=SQL Server Native Client 11.0;Server=;Database=OrderActive;Uid=OrderActive;Pwd=;'
"@
Invoke-Sqlcmd @AppConnection -Query $Query_Update -Database 'MNPServiceCfg'
$LogFileName = Join-Path $Folders['AppLogs']['FullName'] 'ConsoleLog.txt'
$Query_Update = "UPDATE [dbo].[ConsoleHeader] SET [LogFile] = N'$LogFileName'"
Invoke-Sqlcmd @AppConnection -Query $Query_Update -Database 'MNPServiceCfg'

Write-Log -Level INFO -Message 'MNPServiceCfg configured with IPAddress {0} Port {1}'`
    -Arguments @($IPAddress, $port)

#Check/Test ODBC Drivers
$RequiredODBC = @(@{
        DBName     = 'OrderActive'
        Connection = $AppConnection
    },
    @{
        DBName     = 'MNPServiceCfg'
        Connection = $AppConnection
    })
foreach ($ODBC in $RequiredODBC) {
    Set-ODBCConnection -DBName $ODBC.DBName -Connection $ODBC.Connection
}
# Check Software PreRequisites
$client11 = $false
$checkClient = Get-ChildItem 'HKLM:\Software\Microsoft\*' -ea SilentlyContinue | Where-Object { $_.name -like '*Client*' }
if ($checkClient.name.Split('\') -eq 'Microsoft SQL Server Native Client 11.0') {
    Write-Log -Level INFO -Message 'SQL Native Client 11.0 has been already installed'
    $client11 = $True
}
else {
    Write--Log -Level WARNING -Message 'SQL Native Client 11.0 not installed'
    $client11 = $false
}
if ($client11 -eq $false) {
    try {
        Write-Log -Level INFO -Message 'Installing Native Client 11'
        Set-Location C:\WorkingFiles
        invoke-webrequest -UseBasicParsing -Uri $ClientURI -OutFile 'sqlncli.msi'
        $client11Install = msiexec.exe /qn /i sqlncli.msi IACCEPTSQLNCLILICENSETERMS=YES /L*V C:\temp\SQLNativeClient11\sqlNativeClientInstall.log
    }
    Catch {
        Write-Log -Level ERROR -Message 'SQL Native Client 11 was not installed. Manual action required'
    }
}
Invoke-WebRequest -UseBasicParsing https://aka.ms/vs/16/release/vc_redist.x64.exe -OutFile vc_redist.x64.exe
Start-Process -Wait -FilePath '.\vc_redist.x64.exe' -ArgumentList @("/install", "/passive", "/norestart", "/log vc.log")
$VCRedist = (Get-WmiObject -class win32_product | Where-Object { $_.Name -like '* Visual C++ 2019*' })
if ($VCRedist) {
    if ($VCRedist -is [Array]) { $VCRedist = $VCRedist[0] }
    Write-Log -Level INFO -Message "{0} - Version {1} Installed" -Arguments @($VCRedist.Name, $VCRedist.Version)
}
else {
    Throw 'Failed to install Visual C++ Runtime'
}

# Download Software from Sharepoint
Invoke-RetryCommand -ScriptBlock {
    Remove-Item -Path (Join-Path $Folders['ReleasePath']['FullName'] "*") -Recurse -Force
    $Files = Get-SharepointFolder -SiteURL $MNPReleasesURL -SiteFolder $SharePointFolderPath `
        -SiteCred $O365Cred -LocalFolder $Folders['ReleasePath']['FullName']
    $LatestFile = $Files | Sort-Object | Select-Object -Last 1
    Write-Log -Level INFO -Message 'Extracting Software from {0}' -Arguments $LatestFile
    Expand-Archive -Path $LatestFile -DestinationPath $LatestFile.Replace('.zip', '')
}
# Search for software folder
$SoftwareFolder = Get-ChildItem $Folders['ReleasePath']['FullName'] -Directory -Recurse | Where-Object { $_.Name -eq 'Software' }
$AppFolder = Join-Path $Folders['AppSoftware']['FullName'] $SoftwareFolder.Name
# Backup existing software if exists
if (Test-Path $AppFolder ) {
    $BackupPath = (Join-Path $Folders['AppBackup']['FullName'] "$((Get-Date).ToString("yyyy-MM-dd HHmm"))")
    Write-Log -Level INFO -Message 'Backing up {0} to {1}'`
        -Arguments @($AppFolder, $BackupPath)
    New-Item $BackupPath -ItemType Directory -Force | Out-Null
    Move-Item -Path $AppFolder -Destination $BackupPath
}
Write-Log -Level INFO -Message 'Moving {0} to {1}'`
    -Arguments @($SoftwareFolder.Name, $Folders['AppSoftware']['FullName'])
Move-Item -Path $SoftwareFolder.FullName -Destination $Folders['AppSoftware']['FullName']

# Run Service Applications to test install
$ServiceApplications = @('MNPSocketSvc', 'WebRelaySvc', 'DistributeSvc', 'MNPAppConsole')
$plaintext = (Get-PlainCredential -Connection $AppConnection).Pass
foreach ($app in $ServiceApplications) {
    Set-Clipboard $plaintext
    If (Test-Path "$app.html") { Start-Process "$app.html" }
    $AppPath = Join-Path $AppFolder $app
    If (!($AppPath.EndsWith('.exe'))) {
        $AppPath += ".exe"
    }
    If (Test-Path $AppPath) {
        Write-Log -Level INFO -Message 'Starting {0} for installation' -Arguments $app
        $AppProcess = Start-Process $AppPath -PassThru

        #Wait for App Process to complete
        while (!($AppProcess.HasExited)) {

        }
        $Service = Get-CimInstance -ClassName win32_service | Where-Object { $_.PathName -like """$AppPath*" } #| Select Name, DisplayName, State, PathName
        if ($Service) {
            Write-Log -Level INFO -Message 'Service Installed "{0}" and currently {1}' -Arguments @($Service.Name, $Service.State)
        }
        elseif (!($App -like "MNPAppConsole*")) {
            Write-Log -Level WARNING -Message 'Service {0} Not Installed' -Arguments $App
        }
    }
    else {
        Write-Log -Level ERROR -Message "Application {0} Not Found" -Arguments $AppPath
    }
}

#-----------------------------------------------------------[Cleanup  ]------------------------------------------------------------
Write-Log -Level DEBUG -Message "Finishing $($MyInvocation.MyCommand.Name) Version $sScriptVersion"
Wait-Logging
