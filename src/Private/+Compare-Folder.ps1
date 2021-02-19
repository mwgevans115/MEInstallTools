Function Compare-Folder {
    <#
    .SYNOPSIS
        This is a basic overview of what the script is used for..


    .NOTES
        Name: Compare-Folder
        Author: Mark Evans
        DateCreated: 2021-02-18


    .EXAMPLE
        Compare-Folder -Name "Joe Bloggs"


    .LINK

    #>

    [CmdletBinding()]
    param(
        [string[]]  $SourceFolder,
        [string]  $DestinationFolder
    )

    BEGIN {
        Write-Debug -Message "BEGIN $($MyInvocation.MyCommand) : Version $($MyInvocation.MyCommand.Version)"
        $targetFiles = Get-ChildItem -Path $DestinationFolder -Recurse
    }

    PROCESS {
        Write-Debug -Message "PROCESS $($MyInvoication.MyCommand)"
        foreach ($item in $SourceFolder) {
            $sourceFiles = Get-ChildItem -Path $item -Recurse
            $difference = compare-object $sourceFiles $targetFiles -Property { $_.FullName.Replace($item, '').Replace($DestinationFolder, '') }, { (Get-FileHash –Path $_.FullName).Hash } -IncludeEqual
            $difference | Select-Object @{N = 'File'; E = { $_.' $_.FullName.Replace($item, '''').Replace($DestinationFolder, '''') ' } }, `
                SideIndicator, `
            @{N = 'Source'; E = { $s = Join-Path $item $_.' $_.FullName.Replace($item, '''').Replace($DestinationFolder, '''') '; if (Test-Path $s) { $s } else { $null } } }, `
            @{N = 'Target'; E = { $t = Join-Path $DestinationFolder $_.' $_.FullName.Replace($item, '''').Replace($DestinationFolder, '''') '; if (Test-Path $t) { $t } else { $null } } }
        }
    }

    END { Write-Debug -Message "END: $($MyInvoication.MyCommand)" }
}
if ((Get-PSCallStack | Measure-Object).Count -eq 1) {
    $x = Compare-Folder $path1 $path2 -Debug
    $x
    Remove-Item Function:Compare-Folder
}