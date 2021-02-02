Function Get-LogFile {
    <#
    .SYNOPSIS
        Function to return the default log file for a script based on
        BasePath\CompanyName\ProductName\ProductVersion or
        if the script has a LogPath parameter it will use that

    .NOTES
        Name: Get-LogFile
        Author: Mark Evans
        Version: 1.0
        DateCreated: 02/02/2021


    .EXAMPLE
        Get-LogFile


    .LINK

    #>
    [OutputType([System.IO.FileInfo])]
    [CmdletBinding()]
    param(
    )
    $CallingCommand = Get-PSCallStack | Where-Object { $_.Command.EndsWith('.ps1') } | Select-Object -First 1
    $CallingScriptInfo = Test-ScriptFileInfo $CallingCommand.ScriptName -ErrorAction SilentlyContinue
    $CallingScriptParameters = (Get-Command $CallingCommand.ScriptName).parameters.Keys | `
        Where-Object { $_ -notin ([System.Management.Automation.Cmdlet]::CommonParameters) }
    $sScriptName = if ($CallingScriptInfo.Name) { $CallingScriptInfo.Name }else { $CallingCommand.Command.Replace('.ps1', '') }
    $sLogPath = if ('LogPath' -in $CallingScriptParameters) { Get-Variable -Name 'LogPath' -ValueOnly } else { Get-DefaultLogPath $CallingScriptInfo }
    $sLogName = $sScriptName
    $sLogName += " $(Get-Date -Format 'yyyyMMdd')"
    $sLastLog = Get-ChildItem -Path (Join-Path $sLogPath '*') -File -Include "$sLogName*.log" | Sort-Object -Property CreationTime -Descending | Select -ExpandProperty Name -First 1
    if ($sLastLog -match '\d+(?=\.)') {
        $Sequence = "{0:D2}" -f (([Int]$Matches[0]) + 1)
    }
    else {
        $Sequence = "{0:D2}" -f (0)
    }
    $sLogName += " $Sequence.log"
    $sLogFullName = Join-Path $sLogPath $sLogName
    Return New-Item $sLogFullName -ItemType File -Force
}