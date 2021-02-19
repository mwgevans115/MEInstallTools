Function Update-Folder {
    <#
    .SYNOPSIS
        This is a basic overview of what the script is used for..


    .NOTES
        Name: Update-Folder
        Author: Mark Evans
        DateCreated: 2021-02-18


    .EXAMPLE
        Update-Folder -Name "Joe Bloggs"


    .LINK

    #>

    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [string[]]  $SourceFolder,
        [string] $TargetFolder,
        [string] $BackupFile
    )

    BEGIN { Write-Debug -Message "BEGIN $($MyInvocation.MyCommand) : Version $($MyInvocation.MyCommand.Version)" }

    PROCESS {
        Write-Debug -Message "PROCESS $($MyInvoication.MyCommand)"
        foreach ($iSourceFolder in $SourceFolder) {
            $difference = Compare-Folder $iSourceFolder $TargetFolder
            ($difference | Where-Object { $_.SideIndicator -eq '<=' -and ($_.Target) }).Target | Compress-Archive -DestinationPath $BackupFile
            $difference | Where-Object { $_.SideIndicator -eq '<=' } | ForEach-Object {
                Copy-Item $_.Source (Join-Path $TargetFolder $_.File) # Update to safe copy
            }
            <# {
                    try {
                        if ((Get-Random 2) -gt 0 -and (Test-Path (Join-Path $Path2 $_.F)) -and !((Get-ChildItem (Join-Path $Path2 $_.F)).IsReadOnly)){
                            $file = Get-ChildItem  -LiteralPath (Join-Path $Path2 $_.F)
                            $stream = $file.OpenWrite()
                        Write-Warning -Message 'File Locked'
                        }
                        Copy-Item "$Path1/$($_.F)" "$Path2/$($_.F)" -ErrorAction Stop
                    }
                    catch [System.IO.IOException]{
                        Write-Warning "Error - File in Use"
                        Write-Warning ("$i Error" + $_.Exception.Message)
                    }
                    catch [System.UnauthorizedAccessException]{
                        Write-Error "Insufficient permissions to write to file"
                        Write-Warning ("$i Error" + $_.Exception.Message)
                    }
                    catch {
                        $_.exception.GetType().fullname
                        Write-Warning ("$i Error" + $_.Exception.Message)
                    }
                    finally{
                        $stream.Close()} #>
        }
    }


    END { Write-Debug -Message "END: $($MyInvoication.MyCommand)" }
}
if ((Get-PSCallStack | Measure-Object).Count -eq 1) {
    Update-Folder -Debug
    Remove-Item Function:${1:Verb-Noun}
}