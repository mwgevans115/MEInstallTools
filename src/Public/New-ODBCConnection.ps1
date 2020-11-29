function Set-ODBCConnection {
        [CmdletBinding(SupportsShouldProcess)]
    param (
        $DBName,
        $ServerInstance,
        $DSNType
    )
    If (!($DSNType)) {
        $DSNType = If (Test-IsAdmin) {
            'System'
        }
        else {
            'User'
        }
    }
    $HashArguments = @{
        Name             = "$DBName"
        DriverName       = "SQL Server Native Client 11.0"
        SetPropertyValue = @("Server=$($ServerInstance)",
            "Trusted_Connection=No",
            "Database=$DBName")
        DsnType          = $DSNType
    }
    if ($PSCmdlet.ShouldProcess("ODBC Connection $DBName", "Create")) {
        if (!(Get-OdbcDsn -Name $DBName -ea SilentlyContinue -Platform '32-Bit')) {
            Add-OdbcDsn @HashArguments -Platform '32-bit'
        }
        if (!(Get-OdbcDsn -Name $DBName -ea SilentlyContinue -Platform '64-Bit')) {
            Add-OdbcDsn @HashArguments -Platform '64-bit'
        }
    }
}
