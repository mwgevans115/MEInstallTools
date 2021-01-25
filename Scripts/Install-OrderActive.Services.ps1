###Requires -RunAsAdministrator
param (
    [Parameter(HelpMessage = "Path to install Services")]
    $ServiceSoftwarePath = "C:\MNP\Server",
    [Parameter(HelpMessage = "Path to backup Services")]
    $SoftwareBackupPath = "C:\MNP\Backup",
    [Parameter(HelpMessage = "Path to install logs")]
    $InstallLogsPath = "C:\MNP\InstallLogs",
    [Parameter(HelpMessage = "URL for sharepoint site")]
    $URL = 'https://mnpmedialtd.sharepoint.com/sites/Releases',
    [Parameter(HelpMessage = "Sharepoint location for
    OrderActive Services")]
    $DocumentFolder = 'Shared Documents\Latest\OrderActive.Services\Unicode'
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
Install-Modules -Modules @('PackageManagement', 'Logging', 'SqlServer', '7Zip4Powershell', 'SharePointPnPPowerShellOnline')
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
If ((Get-Variable -Name $_).Value -ne $default){
    Export-Clixml $ParamDataFile -InputObject (Get-Variable -Name $_).Value
    Get-Item $ParamDataFile -Force | ForEach-Object { $_.Attributes = $_.Attributes -bor "Hidden" }
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


#region Backup existing software folder
$BackupArchive = Join-Path $SoftwareBackupPath "$(Split-Path $ServiceSoftwarePath -Leaf) $(get-date -Format "yyyy-MM-dd HHmm").7z"
$BackupChanges = Join-Path $SoftwareBackupPath "$scriptName $(get-date -Format "yyyy-MM-dd HHmm").7z"
if (Get-ChildItem -Path $ServiceSoftwarePath -File -Recurse) {
    Write-Log -Level WARNING 'Backing up {0} to {1}' -Arguments $ServiceSoftwarePath, $BackupArchive
    Compress-7Zip -ArchiveFileName $BackupArchive -Path $ServiceSoftwarePath
}
#endregion

#region Download Pre-Requisites

Write-Log -Level INFO "Downloading Pre-Requisites"
$PreRequisites = @('https://aka.ms/vs/16/release/vc_redist.x64.exe',
    'https://aka.ms/vs/16/release/vc_redist.x86.exe',
    'http://go.microsoft.com/fwlink/?LinkID=239648&clcid=0x409',
    'https://go.microsoft.com/fwlink/?linkid=2129954') | `
    ForEach-Object { Get-Installer -URI $_ }
$PreRequisites | ForEach-Object {
    Write-Log -Level INFO -Message "`t{0}`t{1}" -Arguments (Get-Version $_).ProductName, (Get-Version $_).Version
}
$PreRequisiteFolder = Join-Path $ServiceSoftwarePath 'PreRequisites'
New-Item $PreRequisiteFolder -ItemType Directory -Force | Out-Null
Start-Sleep -Milliseconds 500
Write-Log -Level INFO "Moving prerequisites to {0}" -Arguments $PreRequisiteFolder
$PreRequisites | ForEach-Object {
    Wait-FileUnlock $_.FullName
    If (Test-Path (Join-Path $PreRequisiteFolder $_.Name)) {
        If ([Version]((Get-Version $_).Version) -gt
            [Version]((Get-Version (Join-Path $PreRequisiteFolder $_.Name)).Version)) {
            Write-Log -Level WARNING -Message 'Installing PreRequisite {0} {1}' -Arguments (Get-Version $_).ProductName, (Get-Version $_).Version
            Compress-7Zip -ArchiveFileName $BackupChanges -Path (Join-Path $ServiceSoftwarePath $_.Name) -PreserveDirectoryRoot
            Copy-Item -Path $_.FullName -Destination $PreRequisiteFolder -Force
        }
        else {
            Write-Log -Level INFO -Message 'PreRequisite {0} {1} already present' -Arguments (Get-Version (Join-Path $PreRequisiteFolder $_.Name)).ProductName, (Get-Version (Join-Path $PreRequisiteFolder $_.Name)).Version
        }
    }
    else {
        Write-Log -Level WARNING -Message 'Installing PreRequisite {0} {1}' -Arguments (Get-Version $_).ProductName, (Get-Version $_).Version
        Copy-Item -Path $_.FullName -Destination $PreRequisiteFolder -Force
    }
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
Write-Log -Level INFO -Message "Downloading {0} from {1}" -Arguments $DocumentFolder, $URL
$Downloads = Get-SharepointFolder -SiteURI $URL -DocumentFolder $DocumentFolder -UseWebAuth
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
# Move Scripts Folder
$ScriptFolders = Get-ChildItem -Path (Join-Path $TargetPath '*') -Recurse -Include 'Scripts'
$ScriptFolders | ForEach-Object {
    $ScriptsFolder = $_.FullName
    $SoftwareFolder = (Get-ChildItem -Path (Join-Path $TargetPath '*') -Recurse -Include 'Software' | Select -First 1).FullName
    Move-Item $ScriptsFolder $SoftwareFolder -Force
}

# Check if any downloaded exes are running as services - query user if they are
Write-Log -Level INFO -Message "Checking for Running Services"
[System.Collections.ArrayList]$runningServiceList = @()
Get-ChildItem -Path (Join-Path $TargetPath '*') -Recurse -Include 'Software' | ForEach-Object {
    Get-ChildItem (Join-Path $_.FullName '*') -Include '*.exe' } | Select Name | ForEach-Object {
    $RegEx = ".*$($_.Name)[ ""].*"
    $RunningService = (Get-CimInstance -ClassName win32_service | `
            Where-Object { ($_.PathName -match $RegEx -and $_.State -ne 'Stopped') } | `
            Select Name, DisplayName, State, PathName -First 1)
    if ($RunningService) {
        $runningServiceList.Add($RunningService) | Out-Null
    }
}
If ($runningServiceList.Count -ne 0 ) {
    $runningServiceList | ForEach-Object { Write-Log -Level WARNING -Message "`tService {0} is {1}" -Arguments $_.DisplayName, $_.State }
    Wait-Logging
    $Title = "Services Running"
    $Info = "Select Option to continue"
    $options = [System.Management.Automation.Host.ChoiceDescription[]] @("&Stop", "&Ignore", "&Quit")
    [int]$defaultchoice = 2
    $opt = $host.UI.PromptForChoice($Title , $Info , $Options, $defaultchoice)
    switch ($opt) {
        0 { Write-Log -Level WARNING "`tStopping Services"; $runningServiceList | ForEach-Object { Get-Service $_.Name | Stop-Service -PassThru } }
        1 { Write-Log -Level WARNING "`tUser requested Continue"; Write-Log -Level ERROR "System will need to be restarted to complete installation" }
        2 { Write-Log -Level ERROR "`tUser Requested Exit"; Exit }
    }
}

# Prepare temp folder to backup changed files validate files to update
Write-Log -Level INFO -Message 'Backing up changed files'
$TempBackupFolder = New-TempFolder (Split-Path $ServiceSoftwarePath -Leaf)
[System.Collections.ArrayList]$fileList = @()
Get-ChildItem -Path (Join-Path $TargetPath '*') -Recurse -Include 'Software' | ForEach-Object {
    $SourcePath = $_.FullName
    Get-ChildItem -Path $SourcePath -Recurse -File | ForEach-Object {
        $SourceFile = $_.FullName
        $TargetFile = $SourceFile.Replace($SourcePath, $ServiceSoftwarePath)
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


Write-Log -Level INFO -Message "Script Completed"
Wait-Logging
Write-Output ""
