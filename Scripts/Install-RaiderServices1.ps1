###Requires -RunAsAdministrator
param (
    [Parameter(HelpMessage = "Path to install Services")]
    $SoftwarePath = "C:\MNP\Server",
    [Parameter(HelpMessage = "Path to backup Services")]
    $SoftwareBackup = "C:\MNP\Backup",
    [Parameter(HelpMessage = "URL for sharepoint site")]
    $URL = 'https://mnpmedialtd.sharepoint.com/sites/Releases',
    [Parameter(HelpMessage = "Sharepoint location for
    OrderActive Services")]
    $DocumentFolder = 'Shared Documents\Latest\OrderActive.Services\Unicode'
)
Install-PackageProvider Nuget –Force
Install-Module –Name PowerShellGet –Force

Remove-Module MEInstallTools -Force -ErrorAction SilentlyContinue
If (Get-Module -ListAvailable -Name MEInstallTools) {
    Import-Module MEInstallTools
} else {
    $Module = (Get-ChildItem -Path .\src\* -Recurse -Include 'MEInstallTools.psd1' | Select -First 1).FullName
    Import-Module $Module
}
$Modules = @("SharePointPnPPowerShellOnline", "7Zip4Powershell", "Logging")
foreach ($module in $modules) {
    if ((Get-Module -Name $module -ListAvailable).Version -lt [version](Find-Module -Name $module).Version) {
        Write-Verbose "Installing/Updating $Module"
        Install-Module -Name $Module -Force -AllowClobber -Scope CurrentUser
    }
}
# Get User Input for Parameters not explicitly set
$MyInvocation.MyCommand.Parameters.Keys | where { -not $PSBoundParameters.ContainsKey($_) -and `
        $_ -notin ([System.Management.Automation.Cmdlet]::CommonParameters) } |
ForEach-Object {
    $Param = $MyInvocation.MyCommand.Parameters[$_]
    $value = $null
    $Message = $Param.Attributes[0].HelpMessage
    $default = (Get-Variable -Name $_).Value
    if (!($value = Read-Host "$Message [$default]")) { $value = $default }
    Set-Variable -Name $_ -Value $value
}
#$path = Get-Location
$scriptName = $MyInvocation.MyCommand.Name
Set-LoggingDefaultLevel -Level 'INFO'
Add-LoggingTarget -Name Console
Add-LoggingTarget -Name File -Configuration @{Path = 'C:\Temp\scriptName_%{+%Y%m%d}.log'}
Write-Log -Level INFO -Message "Running Script $scriptName"
Wait-Logging
Exit


# Print all Parameters Values if Verbose
$MyInvocation.MyCommand.Parameters.Keys | where {
    $_ -notin ([System.Management.Automation.Cmdlet]::CommonParameters) } |
ForEach-Object {
    $param = Get-Variable -Name $_
    Write-Verbose "$($param.Name) --> $($param.Value)"
}
# Prepare software folder, backup existing or create new
if (Test-Path $SoftwarePath -PathType Container) {
    Write-Output "Backing up $SoftwarePath"
    $BackupArchive = Join-Path $SoftwareBackup "$(Split-Path $SoftwarePath -Leaf) $(get-date -Format "yyyy-MM-dd HHmm").7z"
    Compress-7Zip -ArchiveFileName $BackupArchive -Path $SoftwarePath
}
else {
    New-Item $SoftwarePath -ItemType Directory -Force | Out-Null
}
# Download Pre-Requisites
Write-Output "Downloading Pre-Requisites"
$PreReequisites = @('https://aka.ms/vs/16/release/vc_redist.x64.exe', 'https://aka.ms/vs/16/release/vc_redist.x86.exe', 'http://go.microsoft.com/fwlink/?LinkID=239648&clcid=0x409', 'https://go.microsoft.com/fwlink/?linkid=2129954') | % { Get-Installer -URI $_ }
$PreReequisiteFolder = Join-Path $SoftwarePath 'PreRequisites'
New-Item $PreReequisiteFolder -ItemType Directory -Force | Out-Null
#Start-Sleep -Milliseconds 500
$PreReequisites | ForEach-Object { Wait-FileUnlock $_.FullName }
$PreReequisites | Copy-Item -Destination $PreReequisiteFolder -Force
$PreReequisites | Remove-Item -Force -ErrorAction SilentlyContinue
#Download ICE Software
#$process = Start-Process reg -ArgumentList "import C:\Scripts\MyFile.reg" -PassThru -Wait
#$process.ExitCode
#$process = Start-Process reg -ArgumentList "import C:\Scripts\MyFile.reg" -PassThru -Wait
#$process.ExitCode
if (Get-CimInstance -ClassName Win32_OperatingSystem | Where-Object { $_.Name -like '*server*' }) {
    $InternetESCSettings = Get-InternetExplorerESC
    Set-InternetExplorerESC -DisableAll
    Add-TrustedSite -PrimaryDomain 'sharepoint.com' -SubDomain 'mnpmedialtd'
    Add-TrustedSite -PrimaryDomain 'sharepoint.com' -SubDomain 'mnpmedialtd-files'
    Add-TrustedSite -PrimaryDomain 'sharepoint.com' -SubDomain 'mnpmedialtd-myfiles'
}
Write-Output "Downloading ICE from sharepoint"
$Downloads = Get-SharepointFolder -SiteURI $URL -DocumentFolder $DocumentFolder -verbose -usewebauth
$Downloads | % {
    if ($_.Name.EndsWith('.zip') -or $_.Name.Endswith('.7z') ) {
        Expand-7Zip -ArchiveFileName $_.FullName `
            -TargetPath $SoftwarePath
        Remove-Item $_.FullName -Force
    }
    else {
        Move-Item $_.FullName -Destination $SoftwarePath -Force
    }
}
if (Get-CimInstance -ClassName Win32_OperatingSystem | Where-Object { $_.Name -like '*server*' }) {
    Set-InternetExplorerESC -Admin $InternetESCSettings.Admin -User $InternetESCSettings.User
}