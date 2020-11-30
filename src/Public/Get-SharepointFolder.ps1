function Get-SharepointFolder {
    [CmdletBinding()]
    param (
        [uri]
        $SiteURI,
        [String]
        $DocumentFolder = 'Shared Documents'
    )
    $URI = [uri]$SiteURI
    #$Strings = $URI.PathAndQuery -split '/'
    #If ($Strings.Count -gt)
    #$Site = "$($Strings[1])/$($Strings[2])"
    $SharePointSite = "$($URI.Scheme)://$($URI.DnsSafeHost)/$($URI.PathAndQuery)"
    Write-Verbose $SharePointSite
    $Stoploop = $false
    [int]$Retrycount = "0"

    do {
        try {
            Connect-PnPOnline -Url $SharePointSite
            $Stoploop = $true
        }
        catch {
            $Retry = (
                $Retrycount -lt 3 -and
                $PSItem.CategoryInfo.Activity -eq 'Connect-PnPOnline' -and
                (
                    $PSItem.CategoryInfo.Reason -eq 'IdcrlException' -or
                    ($PSItem.CategoryInfo.Reason -eq 'WebException' -and $PSItem.Exception.Message -like '*(403)*')
                ))
            if ($Retry) {
                Write-Error $PSItem.Exception.Message
                Start-Sleep -Seconds 1
                $Retrycount++
            }
            else {
                throw
            }
        }
    }
    While ($Stoploop -eq $false)
    $Files = Get-PnPFolderItem $DocumentFolder -ItemType File -Recursive
    $Result = New-Object -TypeName "System.Collections.ArrayList"
    $DownloadFolder = Get-DownloadFolder
    foreach ($file in $files) {
        Get-PnPFile -Url $file.ServerRelativeURL -AsFile -Force -Path ($DownloadFolder)
        $Result.Add((Get-ChildItem (Join-Path $DownloadFolder $file.Name ))) | Out-Null
    }
    Disconnect-PnPOnline
    $Result
}