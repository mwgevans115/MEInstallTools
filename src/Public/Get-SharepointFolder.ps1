function Get-SharepointFolder {
    [OutputType("System.Collections.ArrayList")]
    [CmdletBinding()]
    param (
        [uri]
        $SiteURI,
        [String]
        $DocumentFolder = 'Shared Documents',
        [Switch]
        $UseWebAuth
    )
    $URI = [uri]$SiteURI
    $SharePointSite = "$($URI.Scheme)://$($URI.DnsSafeHost)/$($URI.PathAndQuery)"
    Write-Verbose $SharePointSite
    $Stoploop = $false
    [int]$Retrycount = "0"
    If (!($UseWebAuth)) {
        $x = CredMan -GetCred -Target "$($URI.Scheme)://$($URI.DnsSafeHost)/"
        if (!($x)) { Write-Output "Credentials for Sharepoint Site $($URI.Scheme)://$($URI.DnsSafeHost)/" }
    }
    else {
        $InternetESCSettings = Get-InternetExplorerESC
        if ($InternetESCSettings.Admin -eq 1) {
            Set-InternetExplorerESC -DisableAll
        }
        if (([uri]$URI).Host -match '^.*?(?=\.)') {
            $subdomain = $Matches[0]
        }
        if (([uri]$URI).Host -match '(?<=\.).*$') {
            $primarydomain = $Matches[0]
        }
        # Configure trusted sites and download software from sharepoint
        @('', '-files', '-myfiles') | ForEach-Object {
            Add-TrustedSite -PrimaryDomain $primarydomain -SubDomain "$($subdomain)$($_)"
        }
    }
    do {
        try {
            Connect-PnPOnline -Url $SharePointSite -UseWebLogin:$UseWebAuth
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
        $localfile = Get-ChildItem -Path (Join-Path $DownloadFolder $file.name)
        IF (!($file.Name.EndsWith('.aspx'))) {
            if ($localfile.LastWriteTime -lt $file.TimeLastModified) {
                Get-PnPFile -Url $file.ServerRelativeURL -AsFile -Force -Path ($DownloadFolder)
            }
            $Result.Add((Get-ChildItem (Join-Path $DownloadFolder $file.Name ))) | Out-Null
        }
    }
    Disconnect-PnPOnline
    if ($InternetESCSettings.Admin -eq 1) {
        Set-InternetExplorerESC -Admin $InternetESCSettings.Admin -User $InternetESCSettings.User
    }
    $Result
}