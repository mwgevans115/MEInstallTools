#Requires -RunAsAdministrator
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
[CmdletBinding(DefaultParameterSetName = 'USER+PASSWORD')]
param (
    [Parameter(HelpMessage = "Server Instance")]
    [String]$ServerInstance = 'localhost',
    [Parameter(HelpMessage = "Path to Client Software")]
    $ClientSoftwarePath = "C:\MNP\Software",
    [Parameter(HelpMessage = "Path to install logs")]
    $InstallLogsPath = "C:\MNP\InstallLogs",
    [Parameter(
        HelpMessage = "Application Name (Icon)")]
    $ShortcutName = "ICE",
    [Parameter(HelpMessage = "Name of Folder in Start Menu")]
    $StartMenuFolder = "MNP",
    [Parameter(HelpMessage = "Name of Pinned Tile Group")]
    $StartPinGroup = "MNP",
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
Install-Modules -Modules @('PackageManagement', 'Logging')
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

#region Software PreRequisites
# Software PreRequisites
# Check and Install PreRequisites
$PreReequisiteFolder = Join-Path $ClientSoftwarePath 'PreRequisites'
$PreReequisites = Get-ChildItem $PreReequisiteFolder
Write-Log -Level INFO -Message 'Checking PreRequisteSoftware freom {0} Installed' -Arguments $PreReequisiteFolder
$ConsoleSettings = Get-LoggingTarget -Name Console
$Format = $ConsoleSettings.Format
$NewFormat = $ConsoleSettings.Format.Replace('%{message}', "`t%{message}")
$ConsoleSettings.Format = $NewFormat
Wait-Logging
Add-LoggingTarget -Name Console -Configuration $ConsoleSettings
foreach ($prereq in $PreReequisites) {
    If ($false -eq (Install-Software $prereq)) { $PreRequisites = $false }
}
Wait-Logging
$ConsoleSettings.Format = $Format
Add-LoggingTarget -Name Console -Configuration $ConsoleSettings

#endregion

#region ODBC Drivers
# ODBC Drivers
$DriverName = (Get-OdbcDriver -Name "SQL Server Native Client 1*" | Select-Object -First 1).Name
$ODBCConnections = @(
    @{
        name             = 'OrderActive'
        DsnType          = 'System'
        DriverName       = $DriverName
        SetPropertyValue = @("Server=$ServerInstance", "Database=OrderActive")
    }
)
Write-Log -Level INFO -Message 'Checking/Creating ODBC Connections'
$LogMessage = "`t{0} ODBC DSN {1} {2}"
foreach ($connection in $ODBCConnections) {
    foreach ($platform in '32-bit', '64-bit') {
        $existingODBCDSN = Get-OdbcDsn -Name $connection.name -Platform $platform -ErrorAction SilentlyContinue
        if ($existingODBCDSN) {
            $propertyHash = $null
            $connection.SetPropertyValue | ConvertFrom-StringData | ForEach-Object { $propertyHash += $_ }
            if (
                $existingODBCDSN.DriverName -eq $DriverName -and
                !(Compare-Hashtable -Left $existingODBCDSN.Attribute -Right $propertyHash)
            ) {
                Write-Log -Level DEBUG -Message $LogMessage -Arguments $platform, $connection.Name, 'OK'
            }
            else {
                Write-Log -Level WARNING -Message $LogMessage -Arguments $platform, $connection.Name, 'INCORRECT'
                If (Test-IsAdmin) {
                    $existingODBCDSN | Remove-OdbcDsn
                    Write-Log -Level WARNING -Message $LogMessage -Arguments $platform, $connection.Name, 'REMOVED'
                }
                else {
                    Write-Log -Level ERROR -Message $LogMessage -Arguments $platform, $connection.Name, 'CAN''T BE REMOVED (Not Admin)'
                    $PreRequisites = $false
                }
            }
        }
        If (!(Get-OdbcDsn -Name $connection.name -Platform $platform -ErrorAction SilentlyContinue)) {
            if (Test-IsAdmin) {
                Write-Log -Level WARNING -Message $LogMessage -Arguments $platform, $connection.Name, 'ADDED'
                Add-OdbcDsn @connection -Platform $platform
            }
            else {
                Write-Log -Level ERROR -Message $LogMessage -Arguments $platform, $connection.Name, 'CAN''T BE ADDED (Not Admin)'
                $PreRequisites = $false
            }
        }
    }
}
#endregion

#region Create Shortcuts
$Application = Get-ChildItem (Join-Path $ClientSoftwarePath '*') -Include 'Ice.exe'
Write-Log -Level WARNING -Message "Creating Shortcuts for application {0}" -Arguments $Application.FullName
$AppShortcut = New-Shortcut -Target $Application -ShortcutFolder $StartMenuFolder -AllUsers -ShortcutName $ShortcutName
$DesktopShortcut = New-Shortcut -Target $AppShortcut -Desktop -ShortcutName $ShortcutName -AllUsers
New-StartTile -Shortcut $AppShortcut -Group $StartPinGroup
$DesktopShortcut | Out-Null

#endregion
# Check for Config
if (!(Test-Path (Join-Path $ClientSoftwarePath 'config\MNPConfig.XML') -PathType Leaf)) {
    $plaintext = ConvertTo-PlainText $OrderActiveUserCredential.Password
    Set-Clipboard $plaintext
    Start-Process $Application.FullName
}
# Check for License
if (!(Test-Path (Join-Path $ClientSoftwarePath 'config\license.mnp') -PathType Leaf)) {
    Write-Log -Level ERROR -Message 'Application Not Licensed'
}
