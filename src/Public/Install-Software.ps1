function Install-Software {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        $Source
    )
    $Package = Get-Version $Source | Select -Last 1
    If (!($Package.Version)){
        throw "Package $($Source.Name) does not have package version"
    }
    $Pattern = '\bv?[0-9]+\.[0-9]+\.[0-9]+(?:\.[0-9]+)?\b'
    $New = ''
    $strReplace = [regex]::Replace($Package.ProductName, $Pattern, $New) + '*'
    $Installed = Get-Package $strReplace -ErrorAction SilentlyContinue
    if (!($Installed)) {
        if ($PSCmdlet.ShouldProcess("$($Package.Name)", "Installing")) {
            Write-Verbose "Installing $($Package.Name)"
            $result = Install-Package $Source | Out-Null
        }
    }
    elseif ([version]$Installed.Version -lt [version]$Package.Version) {
        if ($PSCmdlet.ShouldProcess("$($Package.ProductName)", "Upgrading")) {
            Write-Verbose "Upgrading $($Package.ProductName)"
            Write-Verbose "Installed $($Installed.Version)"
            Write-Verbose "New Version $($Package.Version)"
            $result = Install-Package $Source
        }
    }
    else {
        Write-Verbose "Package $($Package.ProductName) Already Installed"
        Write-Verbose "Installed $($Installed.Version)"
    }
    $result | Out-Null
}