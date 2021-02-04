Function Get-ScriptParameter {
    <#
    .SYNOPSIS
        Returns the parameters defined for a calling script


    .NOTES
        Name: Get-ScriptParameter
        Author: Mark Evans <mark@madspaniels.co.uk>
        Version: 1.0
        DateCreated: 2020-Dec-10


    .EXAMPLE
        Get-ScriptParameter


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
        # Include powershell common paramters
        [Parameter()]
        [switch]
        $IncludeCommonParameters
    )

    BEGIN {
        Write-Debug "BEGIN: Fetch Parameters"
        $hParameters = (Get-Variable -Name 'MyInvocation' -ValueOnly -Scope (Get-ScriptScope)).MyCommand.Parameters
        if (!($IncludeCommonParameters)) {
            $hParameters = $hParameters.GetEnumerator() | Where-Object { $_.Key -notin ([System.Management.Automation.Cmdlet]::CommonParameters) }
        }
    }

    PROCESS {
        Write-Debug "PROCESS: Filter Parameters"
        foreach ($sParameterName in $ParameterName) {
                $hParameters.GetEnumerator() | Where-Object { $_.Key -like $sParameterName }
        }
    }

    END {
        Write-Debug "END: Complete"
    }
}
