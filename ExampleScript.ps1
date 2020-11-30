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
    [Parameter(Position = 1, HelpMessage = "Path to backup ICE")]
    $SoftwareBackup = "C:\MNP\Backup",
    [Parameter(Position = 2, HelpMessage = "Name of Folder in Start Menu")]
    $StartMenuFolder = "MNP",
    [Parameter(Position = 3, HelpMessage = "Name of Pinned Tile Group")]
    $StartPinGroup = "MNP",
    [Parameter(Position = 5, HelpMessage = "URL for sharepoint site")]
    $URL = 'https://mnpmedialtd.sharepoint.com/sites/Releases',
    [Parameter(Position = 6, HelpMessage = "Sharepoint location for Ice")]
    $DocumentFolder = 'Shared Documents\Latest\Ice'
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
if (Test-Path $SoftwarePath -PathType Container) {
    $BackupArchive = Join-Path $SoftwareBackup "$(Split-Path $SoftwarePath -Leaf) $(get-date -Format "yyyy-MM-dd HHmm").7z"
    Compress-7Zip -ArchiveFileName $BackupArchive -Path $SoftwarePath
}
else {
    New-Item $SoftwarePath -ItemType Directory -Force | Out-Null`
}

# Download Pre-Requisites
$PreReequisites = @('https://aka.ms/vs/16/release/vc_redist.x64.exe', 'https://aka.ms/vs/16/release/vc_redist.x86.exe', 'http://go.microsoft.com/fwlink/?LinkID=239648&clcid=0x409', 'https://go.microsoft.com/fwlink/?linkid=2129954') | % { Get-Installer -URI $_ }
$PreReequisiteFolder = Join-Path $SoftwarePath 'PreRequisites'
New-Item $PreReequisiteFolder -ItemType Directory -Force | Out-Null
$PreReequisites | % { Wait-FileUnlock $_.FullName -Verbose }
$PreReequisites | Move-Item -Destination $PreReequisiteFolder -Force

#Download ICE Software
$Downloads = Get-SharepointFolder -SiteURI $URL -DocumentFolder $DocumentFolder
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

# Create ODBC Connection
Set-ODBCConnection -DBName 'OrderActive' -ServerInstance $DBServerInstance

Remove-Module MEInstallTools -Force
