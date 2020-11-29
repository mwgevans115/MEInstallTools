function Get-Installer {

        [CmdletBinding()]
    param (
        [uri]
        $URI,
        [string]
        $DownloadPath = (Get-DownloadFolder)
    )
    $temp = [System.IO.Path]::GetTempFileName()
    $x = Invoke-WebRequest -Uri $URI -PassThru -OutFile $temp -UseBasicParsing
    $name = $x.BaseResponse.ResponseUri.Segments | Select-Object -Last 1
    $Result = (Join-Path $DownloadPath $name)
    move-item $temp $Result -Force
    $Result = Get-ChildItem $Result
    $Downloaded = Get-Version $Result
    Write-Verbose "Download:`t$Name`t$($Downloaded.ProductName)`t$($Downloaded.Version)"
    Return $Result
}