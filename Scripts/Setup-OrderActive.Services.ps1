[CmdletBinding()]
param (
    [Parameter()]
    [String]
    $ServerInstance = 'localhost'
)

$SQLParams = @{
    ServerInstance = $ServerInstance
}
Set-LoggingDefaultLevel -Level DEBUG
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
    $objects.PrimaryKey = $objects.Columns['Schema name'],$objects.Columns['Name']
    $dvObject = New-Object System.Data.DataView($objects)
    foreach ($objectName in $item.RequiredObjects) {
        $dvObject.RowFilter = "name = '$objectName'"
        #$object = $objects.Rows.Find('Name',$objectName) | Select -first 1
        if ($dvObject.Count -gt 0) {
            Write-Log -Level DEBUG -Message "`tFound Object: {0}`t{1}" -Arguments $objectName.PadRight($length,' '), $dvObject[0].'last modify date'
        }
        else {
            Write-Log -Level ERROR -Message "`tRequired Object {0}.{1} Not Found" -Arguments $item.Database, $objectName
            $PreRequisites = $false
        }
    }

}

# Software PreRequisites
$SoftwarePreRequisites = Get-ChildItem C:\MNP\Server\PreRequisites | Get-Version

# Create MNP ServiceCfg Initial data
# ODBC Drivers
# Run Service Applications

Wait-Logging