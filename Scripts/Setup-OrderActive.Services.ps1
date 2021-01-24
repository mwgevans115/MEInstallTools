[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
[CmdletBinding(DefaultParameterSetName = 'USER+PASSWORD')]
param (
    [Parameter(HelpMessage = "Server Instance")]
    [String]
    $ServerInstance = 'localhost',
    [Parameter(HelpMessage = "Server Software Path")]
    $ServiceSoftwarePath = "C:\MNP\Server",
    [Parameter(HelpMessage = "MNP Logs Path")]
    $ServiceLogPath = "C:\MNP\Logs",
    [Parameter(HelpMessage = "Install Logs Path")]
    $InstallLogsPath = "C:\MNP\InstallLogs",
    [Parameter(HelpMessage = "Order Files Path")]
    $OrderFilesPath = "C:\MNP\OrderFiles",
    [Parameter(ParameterSetName = 'PSCREDENTIAL', Mandatory = $true)]
    [PSCredential]
    $OrderActiveUserCredential,
    [Parameter(ParameterSetName = 'USER+PASSWORD')]
    [String]
    $OrderActiveUsername = 'OrderActive',
    [Parameter(ParameterSetName = 'USER+PASSWORD')]
    [SecureString]$OrderActiveSecurePassword
)
Add-LoggingTarget -Name Console -Configuration @{Level = 'INFO'; Format = '[%{timestamp:+%T} %{level:-7}] %{message}' }

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
##Install-Modules -Modules @('PackageManagement', 'Logging', 'SqlServer')
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
$LastFile = Get-ChildItem (Join-Path $InstallLogsPath "$($scriptName)_$($Date)_*.log") | Sort-Object Name | Select -Last 1
If ($LastFile) {
    $LastFile.Name -match '\d+(?=\.)'
    $Sequence = "{0:D2}" -f (([Int]$Matches[0]) + 1)
}
else {
    $Sequence = '00'
}
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

$InitMNPServiceCfgScript = (Get-ChildItem (Join-Path $ServiceSoftwarePath '*') -Include 'MNPServiceCfg_InitialData_Insert.sql' -Recurse).FullName

$SQLParams = @{
    ServerInstance = $ServerInstance
}
$RequiredDatabases = @('OrderActive', 'MNPServiceCfg', 'MNPCalendar', 'MNPUserMaster', 'Fred')
$AvailableDatabases = @()
$OrderActiveUserrole = 'db_owner'
#region orderactivecredentials
If ($PSCmdlet.ParameterSetName -eq 'USER+PASSWORD') {
    if (!($OrderActiveSecurePassword)) {
        $CredentialManagerCredential = Get-CredentialManagerCredential -Target 'MNP' -User $OrderActiveUserName
        if ($CredentialManagerCredential.User) {
            Write-Log -Level INFO -Message 'Using Stored Credential'
            Write-Log -Level DEBUG -Message "`tTarget : {0}" -Arguments $CredentialManagerCredential.Target
            Write-Log -Level DEBUG -Message "`tUser   : {0}" -Arguments $CredentialManagerCredential.User
            Write-Log -Level DEBUG -Message "`tComment: {0}" -Arguments $CredentialManagerCredential.Comment
            $OrderActiveSecurePassword = $CredentialManagerCredential.SecurePass
        }
        else {
            Write-Output "Enter Password for $OrderActiveUserName (Leave Blank to generate)"
            $OrderActiveSecurePassword = Read-Host -AsSecureString
            If ($OrderActiveSecurePassword.Length -eq 0) {
                Write-Log -Level WARNING -Message 'Generating Password for SQL Login "{0}"' -Arguments $OrderActiveUser
                $OrderActiveSecurePassword = Get-NewPassword
            }
            else {
                Write-Log -Level INFO -Message 'Using Input Password for SQL Login "{0}"' -Arguments $OrderActiveUser
            }
        }
    }
    $OrderActiveUserCredential = New-Object System.Management.Automation.PSCredential ($OrderActiveUsername, $OrderActiveSecurePassword)
}
Write-Log -Level WARNING -Message "Saving Credentials for {0} to Credential Manager" -Arguments $OrderActiveUserCredential.UserName
$CredentialManagerCredential = Set-CredentialManagerCredential -Target 'MNP' -UserCredential $OrderActiveUserCredential -Comment "Set by install script $(Get-Date)"
Write-Log -Level DEBUG -Message "`tTarget : {0}" -Arguments $CredentialManagerCredential.Target
Write-Log -Level DEBUG -Message "`tUser   : {0}" -Arguments $CredentialManagerCredential.User
Write-Log -Level DEBUG -Message "`tComment: {0}" -Arguments $CredentialManagerCredential.Comment

#endregion orderactivecredentials

#region CheckSQLConnection
Write-Log -Level INFO 'Connecting to SQL Server {0}' -Arguments $ServerInstance
$ServerInfo = Get-SQLServerInfo @SQLParams
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

# Test Required Databases
#region Check Required Databases Exist
Write-Log -Level INFO -Message "Checking Databases Exist"
$RequiredDatabases | ForEach-Object {
    $db = Get-SqlDatabase @SQLParams -Name $_ -ErrorAction SilentlyContinue
    if ($db) {
        Write-Log -Level DEBUG -Message "`tDatabase {0} Exists Size: {1}" -Arguments $db.Name, $db.Size
        $AvailableDatabases += $db.Name
    }
    else {
        Write-Log -Level ERROR -Message "`tDatabase {0} does not exist" -Arguments $_
        $PreRequisites = $false
    }
}
#endregion

#region Checking/Creating OrderActive Login
Write-Log -Level INFO -Message "Checking/Creating Login on {0}" -Arguments $SQLParams.ServerInstance
$Login = Get-SqlLogin @SQLParams -LoginName $OrderActiveUserCredential.UserName -ErrorAction SilentlyContinue
If ($Login) {
    Write-Log -Level DEBUG -Message "`tLogin {0} Exists" -Arguments $OrderActiveUserCredential.UserName
    try {
        Invoke-Sqlcmd @SQLParams -Query 'Select ''String''' -Credential $OrderActiveUserCredential -Database 'Master' -ErrorAction SilentlyContinue | Out-Null
        Write-Log -Level DEBUG "`tLogin {0} Connected Successfully" -Arguments $OrderActiveUserCredential.UserName
    }
    catch {
        if (Invoke-Sqlcmd @SQLParams -Query "Exec sp_who" | Where-Object { $_.ItemArray[3] -eq $OrderActiveUserCredential.UserName }) {
            Write-Log -Level ERROR -Message "`tLogin {0} can't connect but is already logged in (incorrect password)" -Arguments $OrderActiveUserCredential.UserName
            $PreRequisites = $false
        }
        else {
            Remove-SqlLogin @SQLParams -LoginName $OrderActiveUserCredential.UserName -Force
            Write-Log -Level WARNING -Message "`tLogin {0} can't connect - Removing existing user" -Arguments $OrderActiveUserCredential.UserName
        }
    }
}
$Login = Get-SqlLogin @SQLParams -LoginName $OrderActiveUserCredential.UserName -ErrorAction SilentlyContinue
If (!($Login)) {
    Write-Log -Level WARNING -Message "`tLogin {0} Created" -Arguments $OrderActiveUserCredential.UserName
    Add-SqlLogin @SQLParams -LoginPSCredential $OrderActiveUserCredential `
        -Enable -LoginType SqlLogin -EnforcePasswordExpiration:$false `
        -DefaultDatabase 'OrderActive' -GrantConnectSql -MustChangePasswordAtNextLogin:$false | Out-Null
}
#endregion
#region Check Available Database Permissions
$QueryAddLogin = @"

    DROP USER IF EXISTS `$(LOGIN);
    CREATE USER `$(LOGIN) FOR LOGIN [`$(LOGIN)];
    ALTER ROLE [`$(ROLE)] ADD MEMBER [`$(LOGIN)]
"@
$QueryAddLoginToRole = @"
    DECLARE @DBUSER VARCHAR(50)
	SELECT @DBUSER = name FROM sys.database_principals
    WHERE SUSER_SID(`$(LOGIN))=sys.database_principals.sid
    ALTER ROLE [`$(ROLE)] ADD MEMBER [`$(LOGIN)]
"@
$Variable = @("ROLE=$OrderActiveUserRole","LOGIN=$($OrderActiveUserCredential.UserName)")
$AvailableDatabases | ForEach-Object {
    $DB = $_
    Write-Log -Level INFO -Message "Checking User Role on {0}" -Arguments $DB
    switch (Test-DBLoginIsInRole -Database $_ -DBLogin $OrderActiveUserCredential.UserName -DBRole $OrderActiveUserRole) {
        $null {
            Write-Log -Level WARNING "`tLogin {0} not mapped to database {1}" -Arguments $OrderActiveUserCredential.UserName, 'CREATING'
            Invoke-Sqlcmd @SQLParams -Query $QueryAddLogin -Variable $Variable -Database $DB -Verbose
        }
        $true {
            Write-Log -Level DEBUG "`tLogin {0} in role {1} on database" -Arguments $OrderActiveUserCredential.UserName, $OrderActiveUserRole
          }
        $false {
            Write-Log -Level WARNING "`tLogin {0} in role {1} on database {2}" -Arguments $OrderActiveUserCredential.UserName, $OrderActiveUserRole, 'ADDING'
            Invoke-Sqlcmd @SQLParams -Query $QueryAddLoginToRole -Variable $Variable -Database $DB
        }
        Default { Write-Output "Unexepcted Error" }
    }
}
#endregion
#region Check SQL Objects
# Check SQL Objects
$CheckObjects = Get-Content $PSScriptRoot\Services-DBObjects.JSON | ConvertFrom-Json
foreach ($item in $CheckObjects) {
    Write-Log -Level INFO -Message 'Checking {0} for {1} objects' -Arguments @($item.Database, $item.RequiredObjects.count)
    $length = $item.RequiredObjects | Sort-Object Length | Select -last 1 -ExpandProperty Length
    $objects = Get-ObjectsFromDatabase @SQLParams -Database $item.Database -OutputAs DataTables
    $objects.PrimaryKey = $objects.Columns['Schema name'], $objects.Columns['Name']
    $dvObject = New-Object System.Data.DataView($objects)
    foreach ($objectName in $item.RequiredObjects) {
        $dvObject.RowFilter = "name = '$objectName'"
        #$object = $objects.Rows.Find('Name',$objectName) | Select -first 1
        if ($dvObject.Count -gt 0) {
            Write-Log -Level DEBUG -Message "`tFound Object: {0}`t{1}" -Arguments $objectName.PadRight($length, ' '), $dvObject[0].'last modify date'
        }
        else {
            Write-Log -Level ERROR -Message "`tRequired Object {0}.{1} Not Found" -Arguments $item.Database, $objectName
            $PreRequisites = $false
        }
    }
}
#endregion

#region Software PreRequisites
# Software PreRequisites
# Check and Install PreRequisites
$PreReequisiteFolder = Join-Path $ServiceSoftwarePath 'PreRequisites'
$PreReequisites = Get-ChildItem $PreReequisiteFolder
Write-Log -Level INFO -Message 'Checking PreRequisteSoftware freom {0} Installed' -Arguments $PreReequisiteFolder
$ConsoleSettings = Get-LoggingTarget -Name Console
$Format = $ConsoleSettings.Format
$NewFormat = $ConsoleSettings.Format.Replace('%{message}', "`t%{message}")
$ConsoleSettings.Format = $NewFormat
Wait-Logging
Add-LoggingTarget -Name Console -Configuration $ConsoleSettings
foreach ($prereq in $PreReequisites) {
    If ($false -eq (Install-Software $prereq)){$PreRequisites=$false}
}
Wait-Logging
$ConsoleSettings.Format = $Format
Add-LoggingTarget -Name Console -Configuration $ConsoleSettings

#endregion
#region ODBC Drivers
# ODBC Drivers
$DriverName = (Get-OdbcDriver -Name "SQL Server Native Client 1*" | Select-Object -First 1).Name
$ODBCConnections = @(
    @{
        name             = 'OrderActive'
        DsnType          = 'System'
        DriverName       = $DriverName
        SetPropertyValue = @("Server=$ServerInstance", "Database=OrderActive")
    },
    @{
        name             = 'MNPServiceCfg'
        DsnType          = 'System'
        DriverName       = $DriverName
        SetPropertyValue = @("Server=$ServerInstance", "Database=MNPServiceCfg")
    }
)
Write-Log -Level INFO -Message 'Checking/Creating ODBC Connections'
$LogMessage = "`t{0} ODBC DSN {1} {2}"
foreach ($connection in $ODBCConnections) {
    foreach ($platform in '32-bit', '64-bit') {
        $existingODBCDSN = Get-OdbcDsn -Name $connection.name -Platform $platform -ErrorAction SilentlyContinue
        if ($existingODBCDSN) {
            $propertyHash = $null
            $connection.SetPropertyValue | ConvertFrom-StringData | ForEach-Object { $propertyHash += $_ }
            if (
                $existingODBCDSN.DriverName -eq $DriverName -and
                !(Compare-Hashtable -Left $existingODBCDSN.Attribute -Right $propertyHash)
            ) {
                Write-Log -Level DEBUG -Message $LogMessage -Arguments $platform, $connection.Name, 'OK'
            }
            else {
                Write-Log -Level WARNING -Message $LogMessage -Arguments $platform, $connection.Name, 'INCORRECT'
                If (Test-IsAdmin) {
                    $existingODBCDSN | Remove-OdbcDsn
                    Write-Log -Level WARNING -Message $LogMessage -Arguments $platform, $connection.Name, 'REMOVED'
                }
                else {
                    Write-Log -Level ERROR -Message $LogMessage -Arguments $platform, $connection.Name, 'CAN''T BE REMOVED (Not Admin)'
                    $PreRequisites = $false
                }
            }
        }
        If (!(Get-OdbcDsn -Name $connection.name -Platform $platform -ErrorAction SilentlyContinue)) {
            if (Test-IsAdmin) {
                Write-Log -Level WARNING -Message $LogMessage -Arguments $platform, $connection.Name, 'ADDED'
                Add-OdbcDsn @connection -Platform $platform
            }
            else {
                Write-Log -Level ERROR -Message $LogMessage -Arguments $platform, $connection.Name, 'CAN''T BE ADDED (Not Admin)'
                $PreRequisites = $false
            }
        }
    }
}

#endregion
#region Initialise MNPSERVICECFG DATA
# Select IP Address to use
Write-Log -Level INFO -Message 'Select Interface for Services'
$IPAddress = Get-NetIPAddress | Select-Object InterfaceAlias, IPAddress, AddressFamily, ifIndex, @{Name = 'Gateway'; Expression = { if (Get-NetRoute -AddressFamily $_.AddressFamily -InterfaceIndex $_.ifIndex -DestinationPrefix $(if ($_.AddressFamily -eq 'IPv4') { '0.0.0.0/0' }else { '::/0' }) -ErrorAction SilentlyContinue) { '*' } } }, @{Name = 'Status'; Expression = { if ($_.ifIndex -eq 1) { 'Up' }else { (Get-NetAdapter -InterfaceIndex $_.ifIndex).Status } } } | Sort-Object Gateway, Status, InterfaceAlias, AddressFamily  -Descending | Out-GridView -OutputMode Single -Title 'Please Select Interface'
Write-Log -Level INFO -Message "`tSelected Interface {0} with IPAddress {1}" -Arguments $IPAddress.InterfaceAlias, $IPAddress.IPAddress
# find available port
$Port = Compare-Object (2062..3062) (Get-ListeningTCPConnections | Select -ExpandProperty ListeningPort -Unique) | Where-object { $_.SideIndicator -eq '<=' } | Select -ExpandProperty InputObject -First 1
Write-Log -Level WARNING -Message "Initialising Data in MNPServiceCfg"
# Remove Existing Data
Write-Log -Level WARNING -Message "`tRemoving Existing Data from MNPServiceCfg"
@('DistributeInstance', 'DistributeHeader', 'WebRelayHeader', 'WebRelayInstance', 'ConsoleHeader', 'MessagingHeader') | ForEach-Object {
    Remove-DBTableData @SQLParams -Database 'MNPServiceCfg' -TableName $_
}


# Run SQL Script
$VersionString = (Select-String -Pattern '\$Version.*?$' -Path $InitMNPServiceCfgScript).Matches[0].Value.Replace('$', '').Replace('=', ' ')
Write-Log -Level WARNING -Message "`tExecuting SQL Script {0} - {1}" -Arguments (Split-Path $InitMNPServiceCfgScript -Leaf), $VersionString
Invoke-Sqlcmd @SQLParams -InputFile $InitMNPServiceCfgScript -Database 'MNPServiceCfg'
$QuerySetColumnValue = @"
DECLARE @SQL VARCHAR(MAX)
SELECT @SQL = COALESCE(@SQL + CHAR(10),'') +
        'UPDATE ' + object_name(object_id) +
        ' SET [`$(ColumnName)] = N''`$(ColumnValue)'''
FROM  SYS.columns WITH (NOLOCK) where name LIKE '`$(ColumnName)'
EXEC (@SQL)
"@
$QueryReplaceInColumnValue = @"
DECLARE @SQL VARCHAR(MAX)
SELECT @SQL = COALESCE(@SQL + CHAR(10),'') +
        'UPDATE ' + object_name(object_id) +
        ' SET [' + name + '] = REPLACE([' + name + '], ''`$(String)'', ''`$(Replacement)'')'
FROM  SYS.columns WITH (NOLOCK) where name LIKE '`$(ColumnName)'
	AND TYPE_NAME(system_type_id) IN ('nchar','nvarchar','char','varchar')
EXEC (@SQL)
"@
Write-Log -Level WARNING -Message "Updating MNPServiceCfg Data"
Write-Log -Level INFO -Message "`tUpdating Column {0} Setting value to {1}" -Arguments 'IPAddress', $IPAddress.IPAddress
try {
    SQLSERVER\Invoke-Sqlcmd @SQLParams  -Database 'MNPServiceCfg' `
        -Query $QuerySetColumnValue `
        -Variable @("ColumnName=IPAddress", "ColumnValue=$($IPAddress.IPAddress)")
    Write-Log -Level INFO -Message "`tUpdating Column {0} Setting value to {1}" -Arguments 'Port', $Port
    SQLSERVER\Invoke-Sqlcmd @SQLParams  -Database 'MNPServiceCfg' `
        -Query $QuerySetColumnValue `
        -Variable @("ColumnName=Port", "ColumnValue=$Port")
    Write-Log -Level INFO -Message "`tUpdating Column {0} Replacing {1} with {2}" -Arguments 'LogFile', 'C:\MNP\Logs', $ServiceLogPath
    SQLSERVER\Invoke-Sqlcmd @SQLParams  -Database 'MNPServiceCfg' `
        -Query $QueryReplaceInColumnValue `
        -Variable @("ColumnName=LogFile", "String=C:\MNP\Logs", "Replacement=$ServiceLogPath")
    Write-Log -Level INFO -Message "`tUpdating Column {0} Replacing {1} with {2}" -Arguments '%Directory%', 'C:\MNP\OrderFiles', $OrderFilesPath
    SQLSERVER\Invoke-Sqlcmd @SQLParams  -Database 'MNPServiceCfg' `
        -Query $QueryReplaceInColumnValue `
        -Variable @("ColumnName=%Directory%", "String=C:\MNP\OrderFiles", "Replacement=$OrderFilesPath")
}
catch {
    Write-Log -Level ERROR -Message 'Updating MNPServiceCfg Data FAILED'
    $PreRequisites = $false
}

#endregion
#region Create Paths for WebRelay if required
# Create Paths for WebRelay if required
Write-Log -Level INFO -Message 'Checking/Creating WebRelay Paths'
$WebRelayInstanceDataRows = Invoke-Sqlcmd @SQLParams -Database 'MNPServiceCfg' -Query 'Select * From WebRelayInstance'
$LogMessage = "`tFolder {0} {1}"
foreach ($row in $WebRelayInstanceDataRows) {
    $row.ItemArray | Where-Object { $_ -like "*$OrderFilesPath*" -and (Test-Path $_ -IsValid) } | ForEach-Object {
        If (Test-Path $_) {
            Write-Log -Level DEBUG -Message $LogMessage -Arguments $_, 'EXISTS'
        }
        else {
            New-Item -Path $_ -ItemType Directory -Force | Out-Null
            Write-Log -Level WARNING -Message $LogMessage -Arguments $_, 'CREATED'
        }

    }
}

#endregion
if ($false -ne $PreRequisites) {
    # Run Service Applicationss
} else {
    Write-Log -Level ERROR -Message "Not All PreRequisites fulfilled check log {0}" -Arguments $logFileName
    & notepad.exe "$logFileName"
}



Write-Log -Level INFO -Message "Script Completed"
Wait-Logging
Write-Output ""