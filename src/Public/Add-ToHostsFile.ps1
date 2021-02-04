function Add-ToHostsFile {
    param([string]$DesiredIP = "127.0.0.1"
        , [string]$Hostname = "tomssl.local"
        , [bool]$CheckHostnameOnly = $false)
    # By Tom Chantler - https://tomssl.com/2019/04/30/a-better-way-to-add-and-remove-windows-hosts-file-entries/
    # Adds entry to the hosts file.
    #Requires -RunAsAdministrator

    $hostsFilePath = "$($Env:WinDir)\system32\Drivers\etc\hosts"
    $hostsFile = Get-Content $hostsFilePath

    Write-Information "About to add $desiredIP for $Hostname to hosts file"

    $escapedHostname = [Regex]::Escape($Hostname)
    $patternToMatch = If ($CheckHostnameOnly) { ".*\s+$escapedHostname.*" } Else { ".*$DesiredIP\s+$escapedHostname.*" }
    If (($hostsFile) -match $patternToMatch) {
        Write-Information $desiredIP.PadRight(20, " ") "$Hostname - not adding; already in hosts file"
    }
    Else {
        Write-Information $desiredIP.PadRight(20, " ") "$Hostname - adding to hosts file... "
        Add-Content -Encoding UTF8  $hostsFilePath ("$DesiredIP".PadRight(20, " ") + "$Hostname")
        Write-Information " done"
    }
}
