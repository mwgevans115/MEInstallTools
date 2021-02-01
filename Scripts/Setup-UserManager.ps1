#Requires -RunAsAdministrator
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
[CmdletBinding(DefaultParameterSetName = 'USER+PASSWORD')]
param (
    [Parameter(HelpMessage = "Server Instance")]
    [String]$ServerInstance = 'localhost',
    [Parameter(HelpMessage = "WebRoot Path")]
    $WebRootPath = "C:\wwwroot",
    [Parameter(HelpMessage = "UserManager Aplication Folder")]
    $UserManagerFolder = "user-manager",
    [Parameter(HelpMessage = "User Manager DNS Name")]
    $UserManagerDNSName = "localhost",
    [Parameter(HelpMessage = "Path to backup Software Folder")]
    $SoftwareBackupPath = "C:\MNP\Backup",
    [Parameter(HelpMessage = "Path to install logs")]
    $InstallLogsPath = "C:\MNP\InstallLogs",
    [Parameter(HelpMessage = "URL for sharepoint site")]
    $URL = 'https://mnpmedialtd.sharepoint.com/sites/Releases',
    [Parameter(HelpMessage = "Sharepoint location for UserManager")]
    $UserManagerDocumentFolder = 'Shared Documents\Latest\UserManager',
    [Parameter(ParameterSetName = 'PSCREDENTIAL', Mandatory = $true)]
    [PSCredential]
    $OrderActiveUserCredential,
    [Parameter(ParameterSetName = 'USER+PASSWORD')]
    [String]
    $OrderActiveUsername = 'OrderActive',
    [Parameter(ParameterSetName = 'USER+PASSWORD')]
    [SecureString]$OrderActiveSecurePassword
)
#region Load Install Support Module
Remove-Module MEInstallTools -Force -ErrorAction SilentlyContinue
If (Get-Module -ListAvailable -Name MEInstallTools) {
    Import-Module MEInstallTools
}
else {
    $Module = (Get-ChildItem -Path .\src\* -Recurse -Include 'MEInstallTools.psd1' | Select -First 1).FullName
    Import-Module $Module
}
#endregion Load Install Support Module
Install-Modules -Modules @('PackageManagement', 'Logging', '7Zip4Powershell', 'SharePointPnPPowerShellOnline')
#region Initialise
$MyInvocation.MyCommand.Parameters.Keys | where { -not $PSBoundParameters.ContainsKey($_) -and `
        $_ -notin ([System.Management.Automation.Cmdlet]::CommonParameters) } |
ForEach-Object {
    $Param = $MyInvocation.MyCommand.Parameters[$_]
    $value = $null
    $Message = $Param.Attributes[0].HelpMessage
    $ParamDataFile = Join-Path (Split-Path $PROFILE.CurrentUserAllHosts -Parent) "$_.xml"
    if (Test-Path $ParamDataFile) {
        $default = (Import-Clixml $ParamDataFile)
    }
    else {
        $default = (Get-Variable -Name $_).Value
    }
    If (!([string]::IsNullOrEmpty($Message))) {
        if (!($value = Read-Host "$Message [$default]")) { $value = $default }
        Set-Variable -Name $_ -Value $value
    }
    If ((Get-Variable -Name $_).Value -ne $default) {
        if ((Test-Path $ParamDataFile) -and (get-item $ParamDataFile -Force).Attributes.HasFlag([System.IO.FileAttributes]::Hidden)) {
            (get-item $ParamDataFile -force).Attributes -= 'Hidden'
        }
        Export-Clixml $ParamDataFile -InputObject (Get-Variable -Name $_).Value -Force
        (get-item $ParamDataFile -force).Attributes += 'Hidden'
    }
}
# Set Script Variables and configure logging
New-Item -Path $InstallLogsPath -ItemType Directory -Force | Out-Null
$scriptName = (Get-ChildItem $MyInvocation.MyCommand.Path).BaseName
$Date = Get-Date -Format "yyyyMMdd"
$LastFile = Get-ChildItem (Join-Path $InstallLogsPath "$($scriptName)_$($Date)_*.log") | Sort-Object Name | Select -Last 1
If ($LastFile) {
    $LastFile.Name -match '\d+(?=\.)'
    $Sequence = "{0:D2}" -f (([Int]$Matches[0]) + 1)
}
else {
    $Sequence = '00'
}
$logFileName = Join-Path $InstallLogsPath "$($scriptName)_$($Date)_$Sequence.log"
Set-LoggingDefaultLevel -Level 'DEBUG'
Set-LoggingDefaultFormat '[%{timestamp:+%T%Z}] [%{level:-7}] %{message}'
Add-LoggingTarget -Name Console -Configuration @{Format = '[%{timestamp:+%T} %{level:-7}] %{message}' }
Add-LoggingTarget -Name File -Configuration @{Path = $logFileName
    Format                                         = '[%{timestamp:+%T%Z}] [%{level:-7}] %{message}'
}
Write-Log -Level INFO -Message "Running Script $scriptName"

# Print all Parameters Values if Verbose
$Title = " Parameter Values "
Write-Log -Level INFO -Message '{0}' -Arguments $Title.PadLeft(40 + ($Title.Length / 2), '*').PadRight(80, '*')
$Length = ($MyInvocation.MyCommand.Parameters.Keys | where {
        $_ -notin ([System.Management.Automation.Cmdlet]::CommonParameters) } | Sort-Object { $_.name.length }  | select -last 1).length
$MyInvocation.MyCommand.Parameters.Keys | where {
    $_ -notin ([System.Management.Automation.Cmdlet]::CommonParameters) } |
ForEach-Object {
    $param = Get-Variable -Name $_
    Write-Log -Level INFO -Message "`t{0}:`t{1}" -Arguments @($param.Name.PadRight($Length, ' '), $param.Value)
    #Write-Verbose "$($param.Name) --> $($param.Value)"
}
$Title = ""
Write-Log -Level INFO -Message '{0}' -Arguments $Title.PadLeft(40 + ($Title.Length / 2), '*').PadRight(80, '*')

# Create all Path's set in parameters
$MyInvocation.MyCommand.Parameters.Keys | where {
    $_ -notin ([System.Management.Automation.Cmdlet]::CommonParameters) -and $_ -like '*Path*' } |
ForEach-Object {
    $param = Get-Variable -Name $_
    IF ($param.Value) {
        If (Test-Path -Path $param.Value -PathType Container) {
            Write-Log -Level INFO -Message '{0} folder {1} exists' -Arguments @($param.Name, $param.Value)
        }
        else {
            New-Item -Path $param.Value -Force -ItemType Directory | Out-Null
            Write-Log -Level WARNING -Message '{0} folder {1} created' -Arguments @($param.Name, $param.Value)
        }
    }
}
#endregion
#region orderactivecredentials
If ($PSCmdlet.ParameterSetName -eq 'USER+PASSWORD') {
    if (!($OrderActiveSecurePassword)) {
        $CredentialManagerCredential = Get-CredentialManagerCredential -Target 'MNP' -User $OrderActiveUserName
        if ($CredentialManagerCredential.User) {
            Write-Log -Level INFO -Message 'Using Stored Credential'
            Write-Log -Level DEBUG -Message "`tTarget : {0}" -Arguments $CredentialManagerCredential.Target
            Write-Log -Level DEBUG -Message "`tUser   : {0}" -Arguments $CredentialManagerCredential.User
            Write-Log -Level DEBUG -Message "`tComment: {0}" -Arguments $CredentialManagerCredential.Comment
            $OrderActiveSecurePassword = $CredentialManagerCredential.SecurePass
        }
        else {
            Write-Output "Enter Password for $OrderActiveUserName (Leave Blank to generate)"
            $OrderActiveSecurePassword = Read-Host -AsSecureString
            If ($OrderActiveSecurePassword.Length -eq 0) {
                Write-Log -Level WARNING -Message 'Generating Password for SQL Login "{0}"' -Arguments $OrderActiveUser
                $OrderActiveSecurePassword = Get-NewPassword
            }
            else {
                Write-Log -Level INFO -Message 'Using Input Password for SQL Login "{0}"' -Arguments $OrderActiveUser
            }
        }
    }
    $OrderActiveUserCredential = New-Object System.Management.Automation.PSCredential ($OrderActiveUsername, $OrderActiveSecurePassword)
}
Write-Log -Level WARNING -Message "Saving Credentials for {0} to Credential Manager" -Arguments $OrderActiveUserCredential.UserName
$CredentialManagerCredential = Set-CredentialManagerCredential -Target 'MNP' -UserCredential $OrderActiveUserCredential -Comment "Set by install script $(Get-Date)"
Write-Log -Level DEBUG -Message "`tTarget : {0}" -Arguments $CredentialManagerCredential.Target
Write-Log -Level DEBUG -Message "`tUser   : {0}" -Arguments $CredentialManagerCredential.User
Write-Log -Level DEBUG -Message "`tComment: {0}" -Arguments $CredentialManagerCredential.Comment

#endregion orderactivecredentials

$ApplicationPath = Join-Path $WebRootPath $UserManagerFolder

#region Backup existing application folder
$BackupArchive = Join-Path $SoftwareBackupPath "$(Split-Path $ApplicationPath -Leaf) $(get-date -Format "yyyy-MM-dd HHmm").7z"
$BackupChanges = Join-Path $SoftwareBackupPath "$scriptName $(get-date -Format "yyyy-MM-dd HHmm").7z"
if (Get-ChildItem -Path $ApplicationPath -File -Recurse) {
    Write-Log -Level WARNING 'Backing up {0} to {1}' -Arguments $ApplicationSoftwarePath, $BackupArchive
    Compress-7Zip -ArchiveFileName $BackupArchive -Path $ApplicationPath
}
#endregion

# If server opertating system configure enhanced security
if (Get-CimInstance -ClassName Win32_OperatingSystem | Where-Object { $_.Name -like '*server*' }) {
    $InternetESCSettings = Get-InternetExplorerESC
    Write-Log -Level INFO "{0} Internet Explorer Enhanced Security" -Arguments 'Disabling'
    Set-InternetExplorerESC -DisableAll
}

# Configure trusted sites and download software from sharepoint
Add-TrustedSite -PrimaryDomain 'sharepoint.com' -SubDomain 'mnpmedialtd'
Add-TrustedSite -PrimaryDomain 'sharepoint.com' -SubDomain 'mnpmedialtd-files'
Add-TrustedSite -PrimaryDomain 'sharepoint.com' -SubDomain 'mnpmedialtd-myfiles'
Write-Log -Level INFO -Message "Downloading {0} from {1}" -Arguments $UserManagerDocumentFolder, $URL
$Downloads = Get-SharepointFolder -SiteURI $URL -DocumentFolder $UserManagerDocumentFolder -UseWebAuth
$Downloads | ForEach-Object {
    Write-Log -Level INFO -Message "`t{0}`t{1}" -Arguments $_.Name, $_.LastModifiedTime
}
$TargetPath = Join-Path $env:TEMP $(get-date -Format "yyyy-MM-dd HHmm")
New-Item -Path $TargetPath -ItemType Directory -Force | Out-Null
$Downloads | ForEach-Object {
    if ($_.Name.EndsWith('.zip') -or $_.Name.Endswith('.7z') ) {
        Expand-7Zip -ArchiveFileName $_.FullName `
            -TargetPath $TargetPath
    }
    else {
        Copy-Item $_.FullName -Destination $TargetPath -Force
    }
}

# Prepare temp folder to backup changed files validate files to update
Write-Log -Level INFO -Message 'Backing up changed files'
$TempBackupFolder = New-TempFolder (Split-Path $ApplicationPath -Leaf)
[System.Collections.ArrayList]$fileList = @()
Get-ChildItem -Path (Join-Path $TargetPath '*') -Recurse -Include 'web' | ForEach-Object {
    $SourcePath = $_.FullName
    Get-ChildItem -Path $SourcePath -Recurse -File | ForEach-Object {
        $SourceFile = $_.FullName
        $TargetFile = $SourceFile.Replace($SourcePath, $ApplicationPath)
        $BackupFile = $SourcePath.Replace($SourcePath, $TempBackupFolder.FullName)
        if ((Get-FileHash $SourceFile).Hash -ne (Get-FileHash $TargetFile -ErrorAction SilentlyContinue).Hash) {
            $fileList.Add([pscustomobject]@{
                    Source   = $SourceFile
                    Target   = $TargetFile
                    IsLocked = if (Test-Path $TargetFile -PathType Leaf) { (Test-IsFileLocked $TargetFile).IsLocked } else { $false }
                    Backup   = $BackupFile
                }) | Out-Null
        }
        else {
            Write-Log -Level DEBUG -Message "`tFile not changed {0}" -Arguments $TargetFile
        }
    }
}
# Log if any files can't be updated immediately if access denied exit
If ($fileList | Where { $_.IsLocked -eq 'AccessDenied' }) {
    $fileList | Where { $_.IsLocked -eq 'AccessDenied' } | ForEach-Object {
        Write-Log -Level ERROR -Message "`tAcccess Denied to {0}" -Arguments $_.Target
    }
    Write-Log -Level ERROR -Message "Insufficient Permissions to Install Files Aborting"
    Remove-Item $TempBackupFolder -Recurse -Force
    Exit
}
If ($fileList | Where { $_.IsLocked }) {
    $fileList | Where { $_.IsLocked } | ForEach-Object {
        Write-Log -Level WARNING -Message "`tFile in use {0} reboot to update" -Arguments $_.Target
    }
}
Write-Log -Level INFO -Message 'Actioning File Changes'
# Update files, backing up changes and scheduling update of locked files
foreach ($file in $fileList) {
    if (Test-Path $file.Target) {
        Write-Log -Level INFO -Message "`tBacking up {0}" -Arguments $file.Target
        New-Item -Path (Split-Path $file.Backup -Parent) -ItemType Directory -Force | Out-Null
        Copy-Item $file.Target $file.Backup -Force
    }
    New-Item (Split-Path $file.Target -Parent) -ItemType Directory -Force | Out-Null
    if ($file.IsLocked) {
        Write-Log -Level WARNING -Message "`tScheduling Install of {0}" -Arguments $file.Target
        Move-FileOnReboot $file.Source $file.Target -ReplaceExisting
    }
    else {
        Write-Log -Level WARNING -Message "`tInstalling {0}" -Arguments $file.Target
        Move-Item $file.Source $file.Target -Force
    }
}
# Compress changed files to archive
If (Get-ChildItem $TempBackupFolder -Recurse -File) {
    Write-Log -Level WARNING 'Backing up {0} to {1}' -Arguments 'Changed Files', $BackupChanges
    Compress-7Zip -ArchiveFileName $BackupChanges -Path $TempBackupFolder -PreserveDirectoryRoot -SkipEmptyDirectories -Append:(Test-Path $BackupChanges)
}
else {
    Write-Log -Level WARNING -Message "`tNo Files Changed"
}
# Clean up temp folders
Remove-Item $TempBackupFolder -Recurse -Force
Remove-Item $TargetPath -Recurse -Force

#Rested enhanced internet settings
if ($InternetESCSettings) {
    Write-Log -Level INFO "{0} Internet Explorer Enhanced Security" -Arguments 'Resetting'
    Set-InternetExplorerESC -Admin $InternetESCSettings.Admin -User $InternetESCSettings.User
}

#Set-Service aspnet_state  -StartupType Automatic
#Start-Service aspnet_state

# If check webserver installed with necessary features
#region WebServer
Write-Log -Level INFO -Message "Checking Web Server Installed"
if (Get-CimInstance -ClassName Win32_OperatingSystem | Where-Object { $_.Name -like '*server*' }) {
    $ServerFeatures = @('Web-Server', 'Web-WebServer', 'Web-Mgmt-Console', 'Web-Asp-Net45', 'Web-Net-Ext45')
    foreach ($feature in $ServerFeatures) {
        $featurestate = Get-WindowsFeature $feature
        if ($featurestate) {
            if ($featurestate.Installed) {
                Write-Log -Level DEBUG -Message "`t{0} is installed" -Arguments $featurestate.DisplayName
            }
            else {
                Write-Log -Level WARNING -Message "`t{0} is not installed" -Arguments $featurestate.DisplayName
                $InstallResult = Install-WindowsFeature -Name $feature
                if ($InstallResult.Success -and $InstallResult.Restart -eq 'No') {
                    Write-Log -Level WARNING -Message "`t{0} installed successfully" -Arguments $featurestate.DisplayName
                }
                else {
                    $Success = $false
                    If ($InstallResult.Success) {
                        Write-Log -Level ERROR -Message "`t{0} installed REBOOT required" -Arguments $featurestate.DisplayName
                    }
                    else {
                        Write-Log -Level ERROR -Message "`t{0} installation failed" -Arguments $featurestate.DisplayName
                    }
                }
            }
        }
    }
}
else {
    $desktopfeatures = @('IIS-WebServer', 'IIS-WebServerRole', 'IIS-WebServerManagementTools', 'IIS-ASPNET45', 'IIS-NetFxExtensibility45')
    foreach ($feature in $desktopFeatures) {
        $featurestate = Get-WindowsOptionalFeature -Online -FeatureName $feature
        if ($featurestate.State -eq "Enabled") {
            Write-Log -Level DEBUG -Message "`t{0} is installed" -Arguments $featurestate.DisplayName
        }
        else {
            Write-Log -Level WARNING -Message "`t{0} is not installed" -Arguments $featurestate.DisplayName
            $Result = Enable-WindowsOptionalFeature -Online -FeatureName $feature -All
            if ($Result.RestartNeeded) {
                Write-Log -Level ERROR -Message "`t{0} installed REBOOT required" -Arguments $featurestate.DisplayName
            }
            else {
                Write-Log -Level WARNING -Message "`t{0} installed" -Arguments $featurestate.DisplayName
            }
        }
    }
}
#endregion

$SiteName = $UserManagerFolder
$SitePath = $ApplicationPath
$appPoolName = "$($SiteName)AppPool"
$Port = Compare-Object (5000..6000) (Get-ListeningTCPConnections | Select -ExpandProperty ListeningPort -Unique) | Where-object { $_.SideIndicator -eq '<=' } | Get-Random | Select -ExpandProperty InputObject -First 1
$LocalSiteURL = "http://localhost:$Port/"
if (($UserManagerDNSName) -and $UserManagerDNSName -ne 'localhost') {
    $RemoteSiteURL = "http://$UserManagerDNSName/"
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
        New-WebBinding -Name $SiteName -Port 80 -HostHeader $UserManagerDNSName
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

#endregion

Write-Log "Setting Connection Strings"
$ConfigPath = (Join-Path $SitePath 'web.config')
$ConnectionSecrets = (Get-Content $ConfigPath) -as [XML]
$ConnectionStrings = $ConnectionSecrets.SelectSingleNode("//connectionStrings")
@(@{Name = 'MNPUserMaster'; Database = 'MNPUserMaster'; ProviderName = "System.Data.SqlClient" }) | ForEach-Object {
    $Builder = New-Object -TypeName 'System.Data.SqlClient.SqlConnectionStringBuilder'
    $builder["Data Source"] = "$ServerInstance"
    $builder["integrated Security"] = $false
    $builder["Initial Catalog"] = "$($_.Database)"
    $Builder["User ID"] = "$($OrderActiveUserCredential.UserName)"
    $Builder["Password"] = "$(ConvertTo-PlainText $OrderActiveUserCredential.Password)"
    $Builder["Application Name"] = "UserManager"
    $Builder["MultipleActiveResultSets"] = $true
    $node = $ConnectionStrings.SelectSingleNode("//add[@name='$($_.Name)']")
    If (!($node)) {
        $node = $ConnectionStrings.AppendChild($ConnectionSecrets.CreateElement("add"))
    }
    $node.SetAttribute("name", "$($_.Name)")
    $node.SetAttribute("connectionString", $Builder.ConnectionString)
    $node.SetAttribute("providerName", $_.ProviderName)
}
$ConnectionSecrets.Save($ConfigPath)
Write-Log -Level WARNING -Message "Encrypting Connections Strings in webconfig"
& (Get-ChildItem C:\Windows\Microsoft.NET\Framework\* -Include ASPNET_REGIIS.* -Recurse | where {$_.FullName -like '*\v4.*'}).FullName -pef 'connectionStrings' $SitePath


<# Web Cofiguration with secrets
$webConfigPath = (Join-Path $SitePath 'Web.config')
$webConfig = (get-content $webConfigPath) -as [XML]
Write-Log -Level INFO -Message "Documenting web.config settings"
@('AuthMode', 'Environment.AllowDebugProfiler', 'Environment.IsTest',
    'ValidationExpression_Code', 'ValidationExpression_Sku',
    'ValidationExpression_SourceCode', 'Validation_ForceNewCodesUppercase',
    'AppSecrets.UseMachineEncryptionVector', 'AppSecrets.AllowPasswordsInMemory',
    'UI.Active', 'Pages.Active') | ForEach-Object {
    $node = $webConfig.SelectSingleNode("//appSettings/add[@key='$_']")
    Write-Log -Level DEBUG -Message "`t{0} : {1}" -Arguments $node.key, $node.value
}

Write-Log "Setting Connection Strings"
$ConfigPath = (Join-Path $SitePath 'ConnectionStrings.secret')
$ConnectionSecrets = (Get-Content $ConfigPath) -as [XML]
$ConnectionStrings = $ConnectionSecrets.SelectSingleNode("//connectionStrings")
@(@{Name = 'MNPUserMaster'; Database = 'MNPUserMaster'; ProviderName = "System.Data.SqlClient" },
    @{Name = 'Admin'; Database = 'OrderActive'; ProviderName = "System.Data.SqlClient" }) | ForEach-Object {
    $Builder = New-Object -TypeName 'System.Data.SqlClient.SqlConnectionStringBuilder'
    $builder["Data Source"] = "$ServerInstance"
    $builder["integrated Security"] = $false
    $builder["Initial Catalog"] = "$($_.Database)"
    $Builder["Persist Security Info"] = $true
    $Builder["User ID"] = "$($OrderActiveUserCredential.UserName)"
    $Builder["Application Name"] = "OMSAdmin"
    $node = $ConnectionStrings.SelectSingleNode("//add[@name='$($_.Name)']")
    If (!($node)) {
        $node = $ConnectionStrings.AppendChild($ConnectionSecrets.CreateElement("add"))
    }
    $node.SetAttribute("name", "$($_.Name)")
    $node.SetAttribute("connectionString", $Builder.ConnectionString)
    $node.SetAttribute("providerName", $_.ProviderName)
}
$ConnectionSecrets.Save($ConfigPath)

Write-Log "Setting appSettings Secrets"
$ConfigPath = (Join-Path $SitePath 'AppSettings.secret')
$AppSettingsSecrets = (Get-Content $ConfigPath) -as [XML]
$AppSettings = $AppSettingsSecrets.SelectSingleNode("//appSettings")
@(@{key = "Admin.Password"; value = "" },
    @{key = "MNPUserMaster.Password"; value = "" }) | ForEach-Object {
    $node = $AppSettings.SelectSingleNode("//add[@key='$($_.key)']")
    If (!($node)) {
        $node = $AppSettings.AppendChild($AppSettingsSecrets.CreateElement("add"))
    }
    $node.SetAttribute("key", $_.key)
    $node.SetAttribute("value", $_.value)
}
$AppSettingsSecrets.Save($ConfigPath)

Write-Log -Level DEBUG -Message "Connecting to {0} for encrypted passwords" -Arguments "$($LocalSiteUrl)Home/Encrypt"
$R = Invoke-WebRequest "$($LocalSiteUrl)Home/Encrypt" -SessionVariable Session
# This command stores the first form in the Forms property of the $R variable in the $Form variable.
$Form = $R.Forms[0]
# These commands populate the string to encrypt and the passwordmode of the respective Form fields.
$Form.Fields["StringToEncrypt"] = "$(ConvertTo-PlainText -EncryptedString $OrderActiveUserCredential.Password)"
$Form.Fields["PasswordMode"] = $true
# This command creates the Uri that will be used to log in to facebook.
# The value of the Uri parameter is the value of the Action property of the form.
#$Uri = "https://www.facebook.com" + $Form.Action
# Now the Invoke-WebRequest cmdlet is used to sign into the Facebook web service.
# The WebRequestSession object in the $FB variable is passed as the value of the WebSession parameter.
# The value of the Body parameter is the hash table in the Fields property of the form.
# The value of the *Method* parameter is POST. The command saves the output in the $R variable.
$R = Invoke-WebRequest -Uri "$($LocalSiteUrl)Home/Encrypt" -WebSession $Session -Method POST -Body $Form.Fields
if ($R.StatusDescription -eq 'OK') {
    if ($r.Content -match '(?<=<pre>).*?(?=</pre>)') {
        $EncryptedPassword = $Matches[0]
    }
}
Write-Log "Updating appSettings Secrets with encrypted password"
$ConfigPath = (Join-Path $SitePath 'AppSettings.secret')
$AppSettingsSecrets = (Get-Content $ConfigPath) -as [XML]
$AppSettings = $AppSettingsSecrets.SelectSingleNode("//appSettings")
@(@{key = "Admin.Password"; value = "$EncryptedPassword" },
    @{key = "MNPUserMaster.Password"; value = "$EncryptedPassword" }) | ForEach-Object {
    $node = $AppSettings.SelectSingleNode("//add[@key='$($_.key)']")
    If (!($node)) {
        $node = $AppSettings.AppendChild($AppSettingsSecrets.CreateElement("add"))
    }
    $node.SetAttribute("key", $_.key)
    $node.SetAttribute("value", $_.value)
}
$AppSettingsSecrets.Save("$ConfigPath")
#>


Write-Log -Level INFO -Message "Script Completed"
Wait-Logging
Write-Output ""


