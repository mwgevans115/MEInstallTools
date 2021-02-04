function Get-ScriptScope {
    <#
    .SYNOPSIS
        Returns the scope number for the calling script or zero if not found


    .NOTES
        Name: Get-ScriptScope
        Author: Mark Evans <mark@madspaniels.co.uk>
        Version: 1.0
        DateCreated: 2020-Dec-10


    .EXAMPLE
        Get-ScriptScope


    .LINK

    #>

    [OutputType([int])]
    param()
    $SaveErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    do {
        $loop_index++;
    }
    until((Get-Variable -Name MyInvocation -ValueOnly -Scope $loop_index).MyCommand.Name.EndsWith('.ps1') -or !(Get-Variable -Scope $loop_index))
    try {
        Get-Variable -Scope $loop_index | Out-Null
        $loop_index - 1
    }
    catch {
        0
    }
    $ErrorActionPreference = $SaveErrorActionPreference
}