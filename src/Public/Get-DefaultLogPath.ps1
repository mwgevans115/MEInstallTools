Function Get-DefaultLogPath {
    <#
    .SYNOPSIS
        Function to return the default log path for a script based on
        BasePath\CompanyName\ProductName\ProductVersion

    .NOTES
        Name: Get-DefaultLogPath
        Author: Mark Evans
        Version: 1.0
        DateCreated: 02/02/2021


    .EXAMPLE
        Get-Something -ScriptFileInfo <ScriptFileInfo>


    .LINK

    #>

        [CmdletBinding()]
        param(
            [Parameter(
                Mandatory = $true,
                Position = 0
                )]
            [pscustomobject]$ScriptFileInfo
        )
        #BasePath
        $Path = $env:APPDATA
        #CompanyName
        If ($ScriptFileInfo.CompanyName){$Path = Join-Path $Path $ScriptFileInfo.CompanyName}
        #ProductName
        If ($ScriptFileInfo.Name){$Path = Join-Path $Path $ScriptFileInfo.Name}
        #ProductVersion
        If ($ScriptFileInfo.Version){$Path = Join-Path $Path $ScriptFileInfo.Version}
        If (Test-Path $Path -IsValid){
            return $Path
        } else {
            return $Env:TEMP
        }
    }
    #Get-DefaultLogPath -ScriptFileInfo (Test-ScriptFileInfo -Path .\Scripts\New-ScriptFile1.ps1)