function Get-MSIVersion {
    ###############################################################
    # Name:         GetMsiVersion.ps1
    # Description:  Prints out MSI installer version
    # Usage:        GetMsiVersion.ps1 <path to MSI>
    # Credits:      http://stackoverflow.com/q/8743122/383673
    ###############################################################
    param (
        [Parameter(Position = 0, Mandatory = $true, ParameterSetName = "FileItem")]
        [IO.FileInfo] $MSI,
        [Parameter(Position = 0, Mandatory = $true, ParameterSetName = "FileName")]
        [string] $FilleName
    )
    if ($PSCmdlet.ParameterSetName -eq "FileName") {
        $MSI = Get-ChildItem $FilleName
    }

    if (!(Test-Path $MSI.FullName)) {
        throw "File '{0}' does not exist" -f $MSI.FullName
    }

    try {
        $windowsInstaller = New-Object -com WindowsInstaller.Installer
        $database = $windowsInstaller.GetType().InvokeMember(
            "OpenDatabase", "InvokeMethod", $Null,
            $windowsInstaller, @($MSI.FullName, 0)
        )

        $q = "SELECT Value FROM Property WHERE Property = 'ProductVersion'"
        $View = $database.GetType().InvokeMember(
            "OpenView", "InvokeMethod", $Null, $database, ($q)
        )

        $View.GetType().InvokeMember("Execute", "InvokeMethod", $Null, $View, $Null)
        $record = $View.GetType().InvokeMember( "Fetch", "InvokeMethod", $Null, $View, $Null )
        $version = $record.GetType().InvokeMember( "StringData", "GetProperty", $Null, $record, 1 )

        $q = "SELECT Value FROM Property WHERE Property = 'ProductName'"
        $View = $database.GetType().InvokeMember(
            "OpenView", "InvokeMethod", $Null, $database, ($q)
        )

        $View.GetType().InvokeMember("Execute", "InvokeMethod", $Null, $View, $Null)
        $record = $View.GetType().InvokeMember( "Fetch", "InvokeMethod", $Null, $View, $Null )
        $Name = $record.GetType().InvokeMember( "StringData", "GetProperty", $Null, $record, 1 )

        return @{Version = $version; ProductName = $Name }
    }
    catch {
        throw "Failed to get MSI file version: {0}." -f $_
    }
}
