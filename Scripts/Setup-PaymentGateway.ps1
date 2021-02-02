###Requires -RunAsAdministrator
param (
    [Parameter(HelpMessage = "Path to install payment gateway")]
    $PaymentGatewaySoftwarePath = "C:\MNP\PaymentGateway",
    [Parameter(HelpMessage = "MNP Logs Path")]
    $ServiceLogPath = "C:\MNP\Logs",
    [Parameter(HelpMessage = "Path to install logs")]
    $InstallLogsPath = "C:\MNP\InstallLogs"
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

Needs tidying up
Install-WindowsFeature -Name "NET-Framework-Core"

# Check Objects
$Regex = '(?<=\$Version:\s*)\b\d+\.\d+(?=\s*\$)' #extracts version number
$objects = Get-ObjectsFromDatabase -ServerInstance localhost -Database OrderActive | Where { $_.name -in @('usp_AddEditKeyData', 'usp_GetAllKeySets', 'usp_UpdatePrivateKey') } | Select name, @{n = 'ver'; e = { $_.routine_definition -match $Regex | Out-Null; $Matches[0] } } , routine_definition
foreach ($obj in $objects) {
    Write-Log -Level DEBUG -Message "Object {0} `t- Version:{1}" -Arguments $obj.name, $obj.ver
}
if (
    (Invoke-Sqlcmd -Query 'SELECT CHARACTER_SET_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = ''DistributeHeader''
      AND COLUMN_NAME = ''IPAddress'';' -Database MNPServiceCfg).CHARACTER_SET_NAME -eq 'UNICODE') {
    $MessageEncoding = 'UNICODE'
}
else {
    $MessageEncoding = 'ASCII'
}
# update Gateway.xml
$x = (Get-Content (Join-Path $PaymentGatewaySoftwarePath Gateway.xml)) -as [XML]
$Port = [int]$x.DocumentElement.SelectSingleNode('//Port').'#text'
if ($Port -in (Get-ListeningTCPConnections | Select -ExpandProperty ListeningPort -Unique)) {
    $NewPort = Compare-Object ($Port..($Port + 1000)) (Get-ListeningTCPConnections | Select -ExpandProperty ListeningPort -Unique) | Where-object { $_.SideIndicator -eq '<=' } | Select -ExpandProperty InputObject -First 1
    $x.DocumentElement.SelectSingleNode('//Port').'#text' = "$NewPort"
}
$x.DocumentElement.SelectSingleNode('//IPAddress').'#text' = '127.0.0.1'
$x.DocumentElement.SelectSingleNode('//LogDirectory').'#text' = "$ServiceLogPath"
$x.DocumentElement.SelectSingleNode('//MessageEncoding').'#text' = $MessageEncoding
$x.Save("$(Join-Path $PaymentGatewaySoftwarePath Gateway.xml)")

Start-Process -FilePath (Join-Path $PaymentGatewaySoftwarePath Install.bat) -WorkingDirectory "$PaymentGatewaySoftwarePath"
$Title = "Checking Success"
$Info = "Did Install Run Successfully"
$options = [System.Management.Automation.Host.ChoiceDescription[]] @("&Yes", "&No")
[int]$defaultchoice = 0
$opt = $host.UI.PromptForChoice($Title , $Info , $Options, $defaultchoice)
switch ($opt) {
    0 { Write-Log -Level INFO "`tPayment Gateway Reported as Installed OK" }
    1 { Write-Log -Level ERROR "`tPayment Gateway Install failed"; Exit }
}
Set-Clipboard (ConvertTo-PlainText (Get-CredentialManagerCredential -Target mnp -User OrderActive).SecurePass)
Start-Process (Join-Path $PaymentGatewaySoftwarePath 'GatewayAdmin.exe') -WorkingDirectory $PaymentGatewaySoftwarePath


