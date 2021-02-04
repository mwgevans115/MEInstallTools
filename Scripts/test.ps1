
Add-LoggingTarget -Name Console -Configuration @{Level = 'DEBUG' }
$SiteName = $AdminFolder
$SitePath = $ApplicationPath
$appPoolName = "$($SiteName)AppPool"
$Port = Compare-Object (5000..6000) (Get-ListeningTCPConnections | Select -ExpandProperty ListeningPort -Unique) | Where-object { $_.SideIndicator -eq '<=' } | Get-Random | Select -ExpandProperty InputObject -First 1
$LocalSiteURL = "http://localhost:$Port/"
if (($AdminDNSName) -and $AdminDNSName -ne 'localhost') {
    $RemoteSiteURL = "http://$AdminDNSName/"
}
else { $RemoteSiteURL = $null }
$WebServerUser = "IIS_IUSRS"


#region Checking/Creating Website

Write-Log -Level DEBUG -Message 'Checking/Creating Website'
Write-Log -Level WARNING -Message "`tGranting {0} permissions on {1}" -Arguments $WebServerUser, $SitePath
$Acl = Get-Acl $SitePath
$Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("$WebServerUser", "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")
$Acl.SetAccessRule($Ar)
Get-ChildItem $SitePath -Recurse | Set-Acl -AclObject $Acl
Set-Acl $SitePath $Acl

Import-Module WebAdministration
if (!(test-path -Path IIS:\AppPools\$appPoolName)) {
    Write-Log -Level WARNING -Message "`t{0} App Pool {1}" -Arguments 'CREATING', $appPoolName
    $newAppPool = New-WebAppPool -Name "$appPoolName"
    $newAppPool.autoStart = $true
    $newAppPool.managedRuntimeVersion = 'v4.0'
    $newAppPool | Set-Item
}
else {
    Write-Log -Level INFO -Message "`t{0} App Pool {1}" -Arguments 'USING EXISTING', $appPoolName
}
Write-Log -Level DEBUG -Message "`t{0}.{1}:{2}" -Arguments $appPoolName, 'autoStart', (Get-ItemProperty -Path "IIS:\AppPools\$appPoolName\" -PSProperty autoStart).Value
Write-Log -Level DEBUG -Message "`t{0}.{1}:{2}" -Arguments $appPoolName, 'managedRuntimeVersion', (Get-ItemProperty -Path "IIS:\AppPools\$appPoolName\" -PSProperty managedRuntimeVersion).Value
if (!(Test-Path -Path IIS:\Sites\$SiteName)) {
    Write-Log -Level WARNING -Message "`t{0} Web Site {1}" -Arguments 'CREATING', $SiteName
    # New-Item iis:\Sites\$SiteName -bindings @{protocol="http";bindingInformation=":$($Port):localhost"} -physicalPath $SitePath
    New-WebSite -Name $SiteName -Port $Port -HostHeader 'localhost' -PhysicalPath $SitePath | Out-Null
    Set-ItemProperty IIS:\Sites\$SiteName -name applicationPool -value $appPoolName
    If ($RemoteSiteURL) {
        New-WebBinding -Name $SiteName -Port 80 -HostHeader $AdminDNSName
    }
}
Write-Log -Level DEBUG -Message "`t{0}.{1}:{2}" -Arguments $SiteName, 'applicationPool', (Get-ItemProperty -Path "IIS:\Sites\$SiteName\" -PSProperty applicationPool)
$Bindings = Get-WebBinding $SiteName
$Prefbinding = $Bindings | Where-Object {$_.bindingInformation.Split(':')[2] -eq 'localhost'} | Select-Object -First 1
foreach ($binding in $Bindings) {
    $protocol = $binding.protocol
    $bindingInfo = $binding.bindingInformation.Split(':')
    if ($bindingInfo[2]) { $dns = $bindingInfo[2] }else { $dns = 'any' }
    if ($bindingInfo[1] -eq 80) { $port = '' } else { $port = ":$($bindingInfo[1])" }
    $url = "$protocol`://$dns$port/"
    Write-Log -Level DEBUG -Message "`tURL: {0}" -Arguments $URL
    if ($Prefbinding -and $Prefbinding.bindingInformation -eq $binding.bindingInformation) {$LocalSiteURL=$url}
}
