[CmdletBinding()]
param (
    [Parameter(HelpMessage="Test Parameter")]
    [string]
    $Test,
    [Parameter(HelpMessage="Test Parameter 1")]
    [string]
    $Test1 = "Fred"
)
Remove-Module MEInstallTools -Force -ErrorAction SilentlyContinue
Import-Module .\src\MEInstallTools.psd1
#Get-DownloadFolder
#Read-ScriptParameters $MyInvocation.MyCommand.Parameters $PSBoundParameters
# $x = New-Shortcut -TargetPath 'C:\MNP\Software\ICE.exe' -ShortcutFolder 'Test'
# New-StartTile -Shortcut $x -Group 'Fred' -Verbose
Get-Installer 'https://aka.ms/vs/16/release/vc_redist.x64.exe' -Verbose
Remove-Module MEInstallTools -Force