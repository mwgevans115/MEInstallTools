[CmdletBinding()]
param (
    [Parameter()]
    [String]
    $ServerInstance = 'localhost',
    $ServiceSoftwarePath = "C:\MNP\Server",
    $ServiceLogPath = "C:\MNP\Logs",
    $OrderFilesPath = "C:\MNP\OrderFiles",
    $OrderActiveUser = "OrderActive",
    [SecureString]$OrderActiveUserPassword
)

$InitMNPServiceCfgScript = Join-Path $ServiceSoftwarePath SQLScripts\MNPServiceCfg_InitialData_Insert.sql
$InitMNPServiceCfgScript = 'C:\Users\MarkEvans\Repos\GitHub\PowerShellScripts\Raider-Scripts\MNPServiceCfg_InitialData_Insert.sql'

$SQLParams = @{
    ServerInstance = $ServerInstance
}
Add-LoggingTarget -Name Console -Configuration @{Level = 'INFO'; Format = '[%{timestamp:+%T} %{level:-7}] %{message}' }
Write-Log -Level INFO 'Connecting to SQL Server {0}' -Arguments $ServerInstance
$Query = 'Select @@VERSION as [Version], @@SERVERNAME As [ServerName], SUSER_NAME() as [Login], DB_NAME() as [Database], USER_NAME() as [User]'
$SQLResult = SQLSERVER\Invoke-Sqlcmd @SQLParams -Query  $Query
if (!($SQLResult.HasErrors)) {
    $ServerInfo = @{
        Version = $SQLResult.Version.Split("`n")[0]
        Server  = $SQLResult.ServerName
        Login   = $SQLResult.Login
        DBName  = $SQLResult.Database
        User    = $SQLResult.User
    }
}
$Query = "SELECT SP1.[name] AS 'Login', SP2.[name] AS 'ServerRole' FROM sys.server_principals SP1 JOIN sys.server_role_members SRM ON SP1.principal_id = SRM.member_principal_id JOIN sys.server_principals SP2 ON SRM.role_principal_id = SP2.principal_id"# Where SP1.[name] = SUSER_NAME()"
$SQLResult = SQLSERVER\Invoke-Sqlcmd @SQLParams -Query  $Query
if (!($SQLResult.HasErrors)) {
    $ServerInfo.Roles = $SQLResult.ServerRole
    If ($ServerInfo.Roles -notcontains 'sysadmin') {
        Write-Log -Level ERROR -Message 'Not logged in with sysadmin rights'
    }
}
Write-Log -Level INFO -Message "`tSQL Version {0}" -Arguments $ServerInfo.Version
Write-Log -Level DEBUG -Message "`tSQLServer Name {0}" -Arguments $ServerInfo.Server
Write-Log -Level DEBUG -Message "`tConnected as Login {0}" -Arguments $ServerInfo.Login
Write-Log -Level DEBUG -Message "`tConnected to Database {0} as User {1}" -Arguments $ServerInfo.DBName, $ServerInfo.User

# Test Required Databases
Write-Log -Level INFO -Message "Checking Databases Exist"
@('OrderActive', 'MNPServiceCfg', 'MNPCalendar', 'MNPUserMaster', 'Fred') | ForEach-Object {
    $db = Get-SqlDatabase @SQLParams -Name $_ -ErrorAction SilentlyContinue
    if ($db) {
        Write-Log -Level DEBUG -Message "`tDatabase {0} Exists Size: {1}" -Arguments $db.Name, $db.Size
    }
    else {
        Write-Log -Level ERROR -Message "`tDatabase {0} does not exist" -Arguments $_
        $PreRequisites = $false
    }
}

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

# Software PreRequisites
# Check and Install PreRequisites
$PreReequisiteFolder = 'C:\MNP\Server\PreRequisites'    #Join-Path $SoftwarePath 'PreRequisites'
$PreReequisites = Get-ChildItem $PreReequisiteFolder
Write-Log -Level INFO -Message 'Checking PreRequisteSoftware freom {0} Installed' -Arguments $PreReequisiteFolder
$ConsoleSettings = Get-LoggingTarget -Name Console
$Format = $ConsoleSettings.Format
$NewFormat = $ConsoleSettings.Format.Replace('%{message}', "`t%{message}")
$ConsoleSettings.Format = $NewFormat
Wait-Logging
Add-LoggingTarget -Name Console -Configuration $ConsoleSettings
foreach ($prereq in $PreReequisites) {
    Install-Software $prereq -Verbose
}
Wait-Logging
$ConsoleSettings.Format = $Format
Add-LoggingTarget -Name Console -Configuration $ConsoleSettings

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

# Create MNP ServiceCfg Initial data
# Select IP Address to use
Write-Log -Level INFO -Message 'Select Interface for Services'
$IPAddress = Get-NetIPAddress | Select-Object InterfaceAlias, IPAddress, AddressFamily, ifIndex, @{Name = 'Gateway'; Expression = { if (Get-NetRoute -AddressFamily $_.AddressFamily -InterfaceIndex $_.ifIndex -DestinationPrefix $(if ($_.AddressFamily -eq 'IPv4') { '0.0.0.0/0' }else { '::/0' }) -ErrorAction SilentlyContinue) { '*' } } }, @{Name = 'Status'; Expression = { if ($_.ifIndex -eq 1) { 'Up' }else { (Get-NetAdapter -InterfaceIndex $_.ifIndex).Status } } } | Sort-Object Gateway, Status, InterfaceAlias, AddressFamily  -Descending | Out-GridView -OutputMode Single -Title 'Please Select Interface'
Write-Log -Level INFO -Message "`tSelected Interface {0} with IPAddress {1}" -Arguments $IPAddress.InterfaceAlias, $IPAddress.IPAddress
# find available port
$Port = Compare-Object (2062..3062) (Get-ListeningTCPConnections | Select -ExpandProperty ListeningPort -Unique) | Where-object { $_.SideIndicator -eq '<=' } | Select -ExpandProperty InputObject -First 1

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

# Check User Permissions
Write-Log -Level INFO -Message 'Checking/Creating Database User'
$LogMessage = "`tUser {0} {1}"
if (Get-DBLogin -Login $OrderActiveUser) {
    Write-Log -Level DEBUG -Message $LogMessage -Arguments $OrderActiveUser, 'EXISTS'
    @('OrderActive', 'MNPServiceCfg', 'MNPCalendar', 'MNPUserMaster') | ForEach-Object {

        $userRoles = Get-DBLogin -Login $OrderActiveUser -Database $_ -OutputAs DataTables
        $dvRoles = New-Object System.Data.DataView($userRoles)
        $dvRoles.RowFilter = "DBUserRole = 'db_owner'"
        if ($dvRoles.Count -gt 0) {
            Write-Log -Level DEBUG -Message "`tUser in db_owner role on Database {0}" -Arguments $_
        }
        else {
            Write-Log -Level ERROR -Message "`tUser not in db_owner role on Database {0}" -Arguments $_
            $PreRequisites = $false
        }
    }

}


# Run Service Applicationss


Wait-Logging