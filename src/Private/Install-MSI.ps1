function Install-MSI {
    param (
        [Parameter(Position = 0, Mandatory = $true, ParameterSetName = "FileItem")]
        [IO.FileInfo] $MSI,
        [Parameter(Position = 0, Mandatory = $true, ParameterSetName = "FileName")]
        [string] $FilleName
    )
    if ($PSCmdlet.ParameterSetName -eq "FileName") {
        $MSI = Get-ChildItem $FilleName
    }
    $DataStamp = get-date -Format yyyyMMddTHHmmss
    $logFile = '{0}-{1}.log' -f $MSI.FullName, $DataStamp
    $MSIArguments = @(
        "/i"
        ('"{0}"' -f $MSI.FullName)
        "/qb"
        "IACCEPTSQLNCLILICENSETERMS=YES"
        "IACCEPTMSOLEDBSQLLICENSETERMS=YES"
        #"/q"
        "/norestart"
        "/L*v"
        $logFile

    )
    $result = Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow -PassThru
    return $result
}