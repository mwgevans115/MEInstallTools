param (
    # Specifies a path to one or more locations. Unlike the Path parameter, the value of the LiteralPath parameter is
    # used exactly as it is typed. No characters are interpreted as wildcards. If the path includes escape characters,
    # enclose it in single quotation marks. Single quotation marks tell Windows PowerShell not to interpret any
    # characters as escape sequences.
    #[Parameter(Mandatory=$true,
    #           Position=0,
    #           ParameterSetName="LiteralPath",
    #           ValueFromPipelineByPropertyName=$true,
    #           HelpMessage="Literal path to one or more locations.")]
    #[Alias("PSPath")]
    #[ValidateNotNullOrEmpty()]
    #[string[]]
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
Import-Module .\src\MEInstallTools.psd1
#Get-DownloadFolder
#Read-ScriptParameters $MyInvocation.MyCommand.Parameters $PSBoundParameters
# $x = New-Shortcut -TargetPath 'C:\MNP\Software\ICE.exe' -ShortcutFolder 'Test'
# New-StartTile -Shortcut $x -Group 'Fred' -Verbose
# Get-Installer 'https://aka.ms/vs/16/release/vc_redist.x64.exe' -Verbose
#$x = [uri]'https://madspaniels.sharepoint.com/TeamSite/'
#Get-SharepointFolder -SiteURI $x -DocumentFolder 'Documents'

if (!(Test-Administrator)) {
    #exit
}
Read-ScriptParameters -ScriptParameters $MyInvocation.MyCommand.Parameters -BoundParameters $PSBoundParameters

# Prepare software folder, backup existing or create new
if (!(Test-Path $SoftwarePath -PathType Container)) {
    exit
}

$PreReequisiteFolder = Join-Path $SoftwarePath 'PreRequisites'
$PreReequisites = Get-ChildItem $PreReequisiteFolder
foreach ($prereq in $PreReequisites) {
    Install-Software $prereq -Verbose
}

# Create ODBC Connection
Set-ODBCConnection -DBName 'OrderActive' -ServerInstance $DBServerInstance

$Application = Get-ChildItem (Join-Path $SoftwarePath '*') -Include 'Ice.exe'
$AppShortcut = New-Shortcut -Target $Application -ShortcutFolder $StartMenuFolder -AllUsers -ShortcutName $ShortcutName
New-Shortcut -Target $AppShortcut -Desktop -ShortcutName $ShortcutName
New-StartTile -Shortcut $AppShortcut -Group $StartPinGroup

Remove-Module MEInstallTools -Force