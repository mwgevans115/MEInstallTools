function Read-ScriptParameters {
    [CmdletBinding()]
    param (
        [Parameter()]
        $ScriptParameters,
        [Parameter()]
        $BoundParameters
    )
    $ScriptParams = @{}
    $ScriptParameters.GetEnumerator() | Where-Object { $_.Key -notin ([System.Management.Automation.Cmdlet]::CommonParameters) } | ForEach-Object { $ScriptParams.Add($_.Key, $_.Value) }
    Write-Verbose "ScriptHas $($ScriptParams.Count)"
    if ($BoundParameters.Keys.Count -gt 0) {
        $UnsetParams = Compare-Object -ReferenceObject $($ScriptParams.Keys) -DifferenceObject $($PSBoundParameters.Keys)
    }
    else {
        $UnsetParams = (Compare-Object -ReferenceObject $($ScriptParams.Keys) -DifferenceObject (@{v123p32 = "" }).Keys | Where-Object { $_.SideIndicator -eq '<=' })
    }
    foreach ($item in $UnsetParams) {
        $Param = $ScriptParams[$item.InputObject]
        $value = $null
        $Message = $Param.Attributes[0].HelpMessage
        $default = (Get-Variable -Name $item.InputObject).Value
        if (!($value = Read-Host "$Message [$default]")) { $value = $default }
        Set-Variable -Name $item.InputObject -Value $value -Scope Global
    }
}