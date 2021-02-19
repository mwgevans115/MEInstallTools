
<#PSScriptInfo

.VERSION 0.0.1

.GUID 5c505c27-c47c-4dfe-a89c-fac7c51313ab

.AUTHOR Mark Evans <mark.evans@mnpthesolution.com>

.COMPANYNAME MNP

.COPYRIGHT 2021 MNP. All rights reserved.

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


.PRIVATEDATA

#>

<#

.SYNOPSIS
  <Overview of script>

.DESCRIPTION
  <Brief description of script>

.PARAMETER <Parameter_Name>
    <Brief description of parameter input required. Repeat this attribute if required>

.INPUTS
  <Inputs if any, otherwise state None>

.OUTPUTS
  <Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>

.NOTES
  Version:        0.0.1
  Author:         Mark Evans <mark.evans@mnpthesolution.com>
  Creation Date:  02/02/2021
  Purpose/Change: Initial script development

.EXAMPLE
  <Example goes here. Repeat this attribute for more than one example>
#>
[CmdletBinding()]
param (
  # Parameter with help message can have default changed by user/data file
  [Parameter(HelpMessage = "Path to install payment gateway")]
  $OSTSoftwarePath = "C:\wwwroot\ost",
  [Parameter(HelpMessage = "DNS Name to bind to payment gateway")]
  $OSTDNSName = 'local-payments.mnpdec.co.uk',
  [Parameter(HelpMessage = "Path to install logs")]
  $LogPath = "C:\MNP\InstallLogs",
  [Parameter(ParameterSetName = 'PSCREDENTIAL', Mandatory = $true)]
  [PSCredential]
  $OrderActiveUserCredential,
  [Parameter(ParameterSetName = 'USER+PASSWORD')]
  [String]
  $OrderActiveUsername = 'OrderActive',
  [Parameter(ParameterSetName = 'USER+PASSWORD')]
  [SecureString]$OrderActiveSecurePassword
)
#region ---------------------------------------------------[Declarations]----------------------------------------------------------
# URL for sharepoint site
DATA URL { 'https://mnpmedialtd.sharepoint.com/sites/Releases' }
# location to download files from
DATA DocumentFolder { 'Shared Documents\Latest\OST' }
DATA WindowsFeatures {
  @{
    Server  = @('Web-Server', 'Web-WebServer', 'Web-Mgmt-Console', 'Web-Asp-Net45', 'Web-Net-Ext45')
    Desktop = @('IIS-WebServer', 'IIS-WebServerRole', 'IIS-WebServerManagementTools', 'IIS-ASPNET45', 'IIS-NetFxExtensibility45')
  }
}
$websitepath = $OSTSoftwarePath
$webDNSName = $OSTDNSName

# Script Framework Control Variables
DATA required_modules { @('Logging') }
DATA logging_defaultlevel { 'DEBUG' } #Set to override powershell log levels
DATA save_defaultparametervalues { $true } #Set to save parameters
#endregion
#region --------------------------------------------------[Initialisations]--------------------------------------------------------
#Set Error Action to Silently Continue
#$ErrorActionPreference = "SilentlyContinue"

Remove-Module MEInstallTools -Force -ErrorAction SilentlyContinue
If (Get-Module -ListAvailable -Name MEInstallTools) {
  Import-Module MEInstallTools
}
else {
  $Module = (Get-ChildItem -Path .\src\* -Recurse -Include 'MEInstallTools.psd1' | Select -First 1).FullName
  Import-Module $Module
}

#Load required Modules
Install-Modules -Modules $required_modules

#Script Version
$oScriptInfo = Test-ScriptFileInfo -LiteralPath ($MyInvocation.MyCommand.Path)

#Set Log File
$fLogFile = Get-LogFile

#Initialise Logging
Set-InitialLogging $fLogFile.FullName 'debug' '[%{timestamp:+%T} %{level:-7}] %{message}'
Write-LogHeader
Wait-Logging
#Validate Parameters
#$x = Get-ScriptParameter
Read-ScriptParameter -UseStored -IncludeBoundParameters
Write-LogScriptParameter
Wait-Logging
#endregion
#region ----------------------------------------------------[Functions]------------------------------------------------------------

<#

Function <FunctionName>{
  Param()

  Begin{
    Log-Write -LogPath $sLogFile -LineValue "<description of what is going on>..."
  }

  Process{
    Try{
      <code goes here>
    }

    Catch{
      Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
      Break
    }
  }

  End{
    If($?){
      Log-Write -LogPath $sLogFile -LineValue "Completed Successfully."
      Log-Write -LogPath $sLogFile -LineValue " "
    }
  }
}

#>
#endregion
#region ----------------------------------------------------[Execution]------------------------------------------------------------
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


#Log-Start -LogPath $sLogPath -LogName $sLogName -ScriptVersion $sScriptVersion
#Script Execution goes
Write-Log -Level INFO -Message "Downloading Software ".PadRight($Host.UI.RawUI.BufferSize.Width - 19, '+')
Write-Log -Level INFO -Message "`tDownloading from : {0}" -Arguments $DocumentFolder
$Downloads = Get-SharepointFolder -SiteURI $URL -DocumentFolder $DocumentFolder -UseWebAuth

$TargetPath = Join-Path $env:TEMP $(get-date -Format "yyyy-MM-dd HHmm")
New-Item $TargetPath -ItemType Directory -Force | Out-Null
<#
Packing / unpacking: 7z, XZ, BZIP2, GZIP, TAR, ZIP and WIM
Unpacking only: AR, ARJ, CAB, CHM, CPIO, CramFS, DMG, EXT, FAT, GPT, HFS, IHEX, ISO, LZH, LZMA, MBR, MSI, NSIS, NTFS, QCOW2, RAR, RPM, SquashFS, UDF, UEFI, VDI, VHD, VMDK, WIM, XAR and Z#>
$Downloads | ForEach-Object {
  if ([System.IO.Path]::GetExtension($_.Name).Replace('.', '') -in @('7z', 'XZ', 'BZIP2'.'GZIP', 'TAR', 'TGZ', 'ZIP', 'AR', 'ARJ', 'LZH', 'LZMA', 'RAR', 'XAR') ) {
    Write-Log -Level INFO -Message "`tExpanding {0}`t{1}" -Arguments $_.Name, $_.CreationTime
    Expand-7Zip -ArchiveFileName $_.FullName `
      -TargetPath $TargetPath
  }
  else {
    Write-Log -Level INFO -Message "`tCopying {0}`t{1}" -Arguments $_.Name, $_.CreationTime
    Copy-Item $_.FullName -Destination $TargetPath -Force
  }
}

# Prepare temp folder to backup changed files validate files to update
Write-Log -Level INFO -Message 'Backing up changed files'
$TempBackupFolder = New-TempFolder (Split-Path $websitepath -Leaf)
[System.Collections.ArrayList]$fileList = @()
Get-ChildItem -Path $TargetPath -Recurse -Include 'oms-payments' | ForEach-Object {
    $SourcePath = $_.FullName
    Get-ChildItem -Path $SourcePath -Recurse -File | ForEach-Object {
        $SourceFile = $_.FullName
        $TargetFile = $SourceFile.Replace($SourcePath, $websitepath)
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



Write-Log -Level INFO -Message "Checking Windows Features ".PadRight($Host.UI.RawUI.BufferSize.Width - 19, '+')
if (Get-Command Enable-WindowsOptionalFeature -ErrorAction SilentlyContinue) {
  $featurestoinstall = $WindowsFeatures.Desktop | % { Get-WindowsOptionalFeature -FeatureName $_ -Online } | where { $_.State -ne 'Enabled' } | Select -ExpandProperty FeatureName
  if ($featurestoinstall) {
    Write-Log -Level WARNING -Message "`tInstalling Desktop Features {0}" -Arguments ($featurestoinstall -join ',')
    $Result = Enable-WindowsOptionalFeature -FeatureName $featurestoinstall -Online -NoRestart
    if ($Result.RestartNeeded){
      Write-Log -Level ERROR -Message "`tRestart Required"
      $Restart =$true
    }
  } else {
    Write-Log -Level INFO -Message "`tDesktop Features already installed"
  }
}
if (Get-Command Install-WindowsFeature -ErrorAction SilentlyContinue) {
  $featurestoinstall = $WindowsFeatures.Desktop | % get-windowsfeature -Name $_ | Where { $_.'InstallState' -ne 'Installed' } | Select -ExpandProperty Name
  if ($featurestoinstall) {
    $Result = Install-WindowsFeature -Name $WindowsFeatures.Server
  }
}

Write-Log -Level INFO -Message "Creating WebSite ".PadRight($Host.UI.RawUI.BufferSize.Width - 19, '+')
$result = Add-IISNetWebSite -SitePath $websitepath -DnsName $webDNSName -UseHTTPS
$result | % {Write-Log INFO -Message "`tWeb Site {0} configured with {1}" -Arguments $_.Name, ($_.Uri -Join ',')}
$URL = $result.Uri | Where-Object {$_.Scheme -eq 'http' -and $_.host -eq $webDNSName}


Write-Log "Setting Connection Strings"
$ConfigPath = (Join-Path $websitepath 'Web.ConnectionStrings.config')
$ConnectionSecrets = (Get-Content $ConfigPath) -as [XML]
$ConnectionStrings = $ConnectionSecrets.SelectSingleNode("//connectionStrings")
@(@{Name = 'Payments'; Database = 'OrderActive'; ProviderName = "System.Data.SqlClient" }) | ForEach-Object {
    $Builder = New-Object -TypeName 'System.Data.SqlClient.SqlConnectionStringBuilder'
    $builder["Data Source"] = "$ServerInstance"
    $builder["integrated Security"] = $false
    $builder["Initial Catalog"] = "$($_.Database)"
    $Builder["User ID"] = "$($OrderActiveUserCredential.UserName)"
    $Builder["Password"] = "$(ConvertTo-PlainText $OrderActiveUserCredential.Password)"
    $Builder["Application Name"] = "OST"
    #$Builder["MultipleActiveResultSets"] = $true
    $node = $ConnectionStrings.SelectSingleNode("//add[@name='$($_.Name)']")
    If (!($node)) {
        $node = $ConnectionStrings.AppendChild($ConnectionSecrets.CreateElement("add"))
    }
    $node.SetAttribute("name", "$($_.Name)")
    $node.SetAttribute("connectionString", $Builder.ConnectionString)
    $node.SetAttribute("providerName", $_.ProviderName)
}
$ConnectionSecrets.Save($ConfigPath)
<#
<installers>
<install
type="OMS.Payments.Provider.Adyen.Installer, OMS.Payments.Provider.Adyen, Version=1.0.0.0, Culture=neutral"
fileMask="OMS.Payments.Provider.Adyen.dll" />

<!-- Adyen  -->
    <add key="Adyen.Environment" value="test" />
    <add key="Adyen.ApiKey" value="" />
    <!-- this key only works with http://local-payments.mnpdev.co.uk/Transaction/Start note the lack of https! -->
    <add key="Adyen.OriginKey" value="" />
    <add key="Adyen.Accounts" value="001" />
    <add key="Adyen.Account[001].Id" value="MNPMediaLtdMOTO" />
    <add key="Adyen.Account[001].CurrencyCode" value="GBP" />
#>

$ConfigPath = (Join-Path $websitepath 'Web.config')
$webConfig = (Get-Content $ConfigPath) -as [XML]
#Then you can change things within this directly
$Installers = $webConfig.SelectSingleNode("//installers")
$node = $webConfig.SelectSingleNode('//installers/install[contains(@type,''#####'')]')
If (!($node)) {
    $node = $Installers.AppendChild($webConfig.CreateElement("install"))
}
$node.SetAttribute("type", "OMS.Payments.Provider.Adyen.Installer, OMS.Payments.Provider.Adyen, Version=1.0.0.0, Culture=neutral")
$node.SetAttribute("filemask", "OMS.Payments.Provider.Adyen.dll")
$webConfig.Save($ConfigPath)


Write-Log -Level WARNING -Message "Encrypting Connections Strings in webconfig"
& (Get-ChildItem C:\Windows\Microsoft.NET\Framework\* -Include ASPNET_REGIIS.* -Recurse | where {$_.FullName -like '*\v4.*'}).FullName -pef 'connectionStrings' $websitepath
#& (Get-ChildItem C:\Windows\Microsoft.NET\Framework\* -Include ASPNET_REGIIS.* -Recurse | where {$_.FullName -like '*\v4.*'}).FullName -pef 'appSettings' $websitepath

$Query = @"
USE [OrderActive]
GO
UPDATE [dbo].[EFTProviders]
   SET [TransactionURL] = '$($URL)Transaction/Start/?hash='
 WHERE [ProviderName] = 'Adyen.Core.Transactor'
GO
"@

Invoke-Sqlcmd -Query $Query -Database 'OrderActive'



#Log-Finish -LogPath $sLogFile
#endregion


Wait-Logging

