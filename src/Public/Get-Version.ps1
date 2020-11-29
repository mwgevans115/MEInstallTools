function Get-Version {
    param (
        [Parameter(Position = 0, Mandatory = $true, ParameterSetName = "FileItem")]
        [IO.FileInfo] $File,
        [Parameter(Position = 0, Mandatory = $true, ParameterSetName = "FileName")]
        [string] $FilleName
    )
    if ($PSCmdlet.ParameterSetName -eq "FileName") {
        $File = Get-ChildItem $FilleName
    }
    If ($File.Extension -eq '.msi') {
        Return Get-MSIVersion -MSI $File
    }
    else {
        Return @{Version = $File.VersionInfo.ProductVersion; ProductName = $File.VersionInfo.ProductName }
    }

}
