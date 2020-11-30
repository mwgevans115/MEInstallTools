function Get-SharepointFolder {
    [OutputType("System.Collections.ArrayList")]
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
    $x = CredMan -GetCred -Target "$($URI.Scheme)://$($URI.DnsSafeHost)/"
    if (!($x)) {Write-Output "Credentials for Sharepoint Site $($URI.Scheme)://$($URI.DnsSafeHost)/"}

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
                if ($x) {
                    credman -DelCred -Target "$($URI.Scheme)://$($URI.DnsSafeHost)/"
                }
                Write-Error $PSItem.Exception.Message
                Write-Output "Please enter credentials for Sharepoint Site $($URI.Scheme)://$($URI.DnsSafeHost)/"
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
        IF (!($file.Name.EndsWith('.aspx'))) {
            Get-PnPFile -Url $file.ServerRelativeURL -AsFile -Force -Path ($DownloadFolder)
            $Result.Add((Get-ChildItem (Join-Path $DownloadFolder $file.Name ))) | Out-Null
        }
    }
    Disconnect-PnPOnline
    $Result
}