function Get-WordWrappedText {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory = 1, ValueFromPipeline = 1, ValueFromPipelineByPropertyName = 1)]
        [Object[]]$chunk,
        [Int]$LineLength = $Host.UI.RawUI.BufferSize.Width
    )
    PROCESS {
        $Lines = @()
        foreach ($line in $chunk) {
            $str = ''
            $counter = 0
            $line -split '\s+' | ForEach-Object {
                $counter += $_.Length + 1
                if ($counter -gt $LineLength) {
                    $Lines += , $str.trim()
                    $str = ''
                    $counter = $_.Length + 1
                }
                $str = "$str$_ "
            }
            $Lines += , $str.trim()
        }
        $Lines
    }
}