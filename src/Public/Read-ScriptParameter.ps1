Function Read-ScriptParameter {
    <#
    .SYNOPSIS
        Returns the parameters defined for a calling script


    .NOTES
        Name: Read-ScriptParameter
        Author: Mark Evans <mark@madspaniels.co.uk>
        Version: 1.0
        DateCreated: 2020-Dec-10


    .EXAMPLE
        Read-ScriptParameter


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
        # Switch to include bound parameters
        [Parameter()]
        [Switch]
        $IncludeBoundParameters,
        # Application datapath to store defaults
        [Parameter()]
        [String]
        $ApplicationData = (Join-Path $env:APPDATA '\Microsoft\Windows\Powershell\ParameterData'),
        # Switch to use stored defaults
        [Parameter()]
        [Switch]
        $UseStored,
        # Switch to save defaults
        [Parameter()]
        [Switch]
        $Store
    )

    BEGIN {
        Write-Debug "BEGIN: $($MyInvocation.MyCommand.Name)"
        $iScriptScope = Get-ScriptScope
        $BoundParameters = Get-Variable -Name 'PSBoundParameters' -Scope $iScriptScope -ValueOnly
        If (($UseStored -or $Store) -and -not (Test-Path $ApplicationData -PathType Container)) {
            New-Item -Path $ApplicationData -ItemType Directory -Force | Out-Null
            Write-Log -Level WARNING -Message "`t[{0}] Created {1}" -Arguments 'AppDataFolder', $ApplicationData
        }
        Write-Debug $iScriptScope
        Write-Debug $BoundParameters.Keys
    }

    PROCESS {
        Write-Debug "PROCESS: $($MyInvocation.MyCommand.Name)"
        foreach ($sParameterName in $ParameterName) {
            $Parameters = Get-ScriptParameter $sParameterName
            foreach ($parameter in $Parameters) {
                If (($BoundParameters.ContainsKey($parameter.Key) -and !($IncludeBoundParameters)) -or !($parameter.Value.Attributes[0].HelpMessage)) {
                    Write-Log -Level DEBUG -Message "`tVar [{0}]: Not Reading" -Arguments $parameter.Key
                }
                else {
                    $Message = $parameter.Value.Attributes[0].HelpMessage
                    $ParamDataFile = Join-Path $ApplicationData "$($parameter.Key).xml"
                    if ($UseStored -and (Test-Path $ParamDataFile) -and !($BoundParameters.ContainsKey($parameter.Key))) {
                        $default = (Import-Clixml $ParamDataFile)
                        Write-Log -Level DEBUG -Message "`tVar [{0}]: Reading Default from file [{1}]" -Arguments $parameter.Key, $default
                    }
                    else {
                        $default = Get-Variable -Name $parameter.Key -ValueOnly -Scope $iScriptScope
                        Write-Log -Level DEBUG -Message "`tVar [{0}]: Default from script [{1}]" -Arguments $parameter.Key, $default
                    }
                    Wait-Logging
                    if (!($value = Read-Host "$Message [$default]")) { $value = $default }else {
                        Write-Log -Level DEBUG -Message "`tVar [{0}]: Changed by user to [{1}]" -Arguments $parameter.Key, $value
                        If ($UseStored -or $Store) {
                            if ((Test-Path $ParamDataFile) -and (get-item $ParamDataFile -Force).Attributes.HasFlag([System.IO.FileAttributes]::Hidden)) {
                                (get-item $ParamDataFile -force).Attributes -= 'Hidden'
                            }
                            Export-Clixml $ParamDataFile -InputObject $value -Force
                            (get-item $ParamDataFile -force).Attributes += 'Hidden'
                            Write-Log -Level DEBUG -Message "`tVar [{0}]: Written to File" -Arguments $parameter.Key, $value
                        }
                    }
                    (Get-Variable -Name $parameter.Key -Scope $iScriptScope).Value = $value
                }
            }
        }
    }

    END {
        Write-Debug "END: $($MyInvocation.MyCommand.Name)"
    }
}
