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
Get-DownloadFolder
Read-ScriptParameters $MyInvocation.MyCommand.Parameters $PSBoundParameters
$Test
$Test1

Remove-Module MEInstallTools -Force