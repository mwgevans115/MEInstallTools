param (
    [Parameter(HelpMessage = "Path to install ICE")]
    $SoftwarePath = "C:\MNP\Software",
    [Parameter(HelpMessage = "Path to backup ICE")]
    $SoftwareBackup = "C:\MNP\Backup",
    [Parameter(HelpMessage = "URL for sharepoint site")]
    $URL = 'https://mnpmedialtd.sharepoint.com/sites/Releases',
    [Parameter(HelpMessage = "Sharepoint location for Ice")]
    $DocumentFolder = 'Shared Documents\Latest\Ice',
    [Parameter(HelpMessage = "Database Server Instance")]
    $DBServerInstance = 'localhost'
)
Remove-Module MEInstallTools -Force -ErrorAction SilentlyContinue
$Module = (Get-ChildItem -Path .\* -Recurse -Include 'MEInstallTools.psd1' | Select -First 1).FullName
Import-Module $Module

if (!(Test-Administrator)) {
    exit
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
# Print all Parameters Values if Verbose
$MyInvocation.MyCommand.Parameters.Keys | where {
    $_ -notin ([System.Management.Automation.Cmdlet]::CommonParameters) } |
ForEach-Object {
    $param = Get-Variable -Name $_
    Write-Verbose "$($param.Name) --> $($param.Value)"
}


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

Remove-Module MEInstallTools -Force
