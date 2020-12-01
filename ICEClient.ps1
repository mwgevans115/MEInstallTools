#Requires -RunAsAdministrator
param (
    [Parameter( Position = 4,
    HelpMessage = "Application Name (Icon)")]
    $ShortcutName = "ICE",
    [Parameter(Position = 0, HelpMessage = "Path to install ICE")]
    $SoftwarePath = "C:\MNP\Software",
    [Parameter(Position = 2, HelpMessage = "Name of Folder in Start Menu")]
    $StartMenuFolder = "MNP",
    [Parameter(Position = 3, HelpMessage = "Name of Pinned Tile Group")]
    $StartPinGroup = "MNP",
    [Parameter(Position = 7, HelpMessage = "Database Server Instance")]
    $DBServerInstance = 'localhost'
)
Remove-Module MEInstallTools -Force -ErrorAction SilentlyContinue
$Module = (Get-ChildItem -Path .\* -Recurse -Include 'MEInstallTools.psd1' | Select -First 1).FullName
Import-Module $Module

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
# Print all Parameters Values if Verbose
$MyInvocation.MyCommand.Parameters.Keys | where {
    $_ -notin ([System.Management.Automation.Cmdlet]::CommonParameters) } |
ForEach-Object {
    $param = Get-Variable -Name $_
    Write-Verbose "$($param.Name) --> $($param.Value)"
}

# Check and Install PreRequisites
$PreReequisiteFolder = Join-Path $SoftwarePath 'PreRequisites'
$PreReequisites = Get-ChildItem $PreReequisiteFolder
foreach ($prereq in $PreReequisites) {
    Install-Software $prereq -Verbose
}

# Create ODBC Connection
Set-ODBCConnection -DBName 'OrderActive' -ServerInstance $DBServerInstance

$Application = Get-ChildItem (Join-Path $SoftwarePath '*') -Include 'Ice.exe'
$AppShortcut = New-Shortcut -Target $Application -ShortcutFolder $StartMenuFolder -AllUsers -ShortcutName $ShortcutName
$DesktopShortcut = New-Shortcut -Target $AppShortcut -Desktop -ShortcutName $ShortcutName -AllUsers
New-StartTile -Shortcut $AppShortcut -Group $StartPinGroup
$DesktopShortcut | Out-Null

# Check for Config
if (!(Test-Path (Join-Path $SoftwarePath 'config\MNPConfig.XML') -PathType Leaf)) {
    Start-Process $Application.FullName
}
# Check for License
if (!(Test-Path (Join-Path $SoftwarePath 'config\license.mnp') -PathType Leaf)) {
    Write-Warning 'Application Not Licensed'
}
Remove-Module MEInstallTools -Force