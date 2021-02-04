Function Write-LogScriptParameter {
    <#
    .SYNOPSIS
        Returns the parameters defined for a calling script


    .NOTES
        Name: Write-LogScriptParameter
        Author: Mark Evans <mark@madspaniels.co.uk>
        Version: 1.0
        DateCreated: 2020-Dec-10


    .EXAMPLE
        Write-LogScriptParameter


    .LINK

    #>

    [CmdletBinding()]
    param(
        # Parameter Name - leave blank for all
        [Parameter(
            Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [string[]]  $ParameterName = '*',
        [Parameter()]
        [Int]
        $LogFormatLength = 19,
        [Parameter()]
        [Int]
        $LogLineLength = $Host.UI.RawUI.BufferSize.Width - $LogFormatLength
    )

    BEGIN {
        Write-Debug "BEGIN: $($MyInvocation.MyCommand.Name)"
        $iScriptScope = Get-ScriptScope
        Write-Log -Level INFO -Message '{0}' -Arguments (Get-TitleMessage "Parameter Values" $LogFormatLength $LogLineLength)
        $Length = 0
        $parametertable = @{}
    }

    PROCESS {
        Write-Debug "PROCESS: $($MyInvocation.MyCommand.Name)"
        foreach ($sParameterName in $ParameterName) {
            $Parameters = Get-ScriptParameter $sParameterName
            foreach ($parameter in $Parameters) {
                if ($parameter.Key.Length -gt $Length) { $Length = $parameter.Key.Length }
                $parametertable.Add($parameter.Key, (Get-Variable -Name $parameter.Key -Scope $iScriptScope -ValueOnly))
            }
        }
    }

    END {
        Write-Debug "END: $($MyInvocation.MyCommand.Name)"
        foreach ($param in $parametertable.GetEnumerator()) {
            Write-Log -Level INFO -Message "`t{0}: {1}" -Arguments @($param.Key.PadRight($Length, ' '), $param.Value)
        }
        Write-Log -Level INFO -Message '{0}' -Arguments (Get-TitleMessage "" $LogFormatLength $LogLineLength)
    }
}
