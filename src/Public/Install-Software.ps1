function Install-Software {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        $Source
    )
    $Package = Get-Version $Source | Select -Last 1
    If (!($Package.Version)) {
        throw "Package $($Source.Name) does not have package version"
    }
    $Pattern = '\bv?[0-9]+\.[0-9]+\.[0-9]+(?:\.[0-9]+)?\b'
    $New = ''
    $strReplace = [regex]::Replace($Package.ProductName, $Pattern, $New) + '*'
    $Installed = Get-Package $strReplace -ErrorAction SilentlyContinue
    if (!($Installed)) {
        if ($PSCmdlet.ShouldProcess("$($Package.ProductName)", "Installing")) {
            If ((Get-Module -Name Logging) -and (Get-LoggingTarget)) { Write-Log -Level WARNING "Installing {0}" -Arguments $Package.ProductName }
            else { Write-Verbose "Installing $($Package.ProductName)" }
            $result = Install-Package $Source | Out-Null
        }
    }
    elseif ([version]$Installed.Version -lt [version]$Package.Version) {
        if ($PSCmdlet.ShouldProcess("$($Package.ProductName)", "Upgrading")) {
            If ((Get-Module -Name Logging) -and (Get-LoggingTarget)) {
                Write-Log -Level WARNING "Upgrading {0}" -Arguments $Package.ProductName
                Write-Log -Level DEBUG "From {0} to {1}" -Arguments $Installed.Version, $Package.Version
            }
            else {
                Write-Verbose "Upgrading $($Package.ProductName)"
                Write-Verbose "Installed $($Installed.Version)"
                Write-Verbose "New Version $($Package.Version)"
            }
            $result = Install-Package $Source
        }
    }
    else {
        If ((Get-Module -Name Logging) -and (Get-LoggingTarget)) {
            Write-Log -Level INFO -Message "Package {0} Version {1} Already Installed" `
                -Arguments $Package.ProductName, $Installed.Version
        }
        else {
            Write-Verbose "Package $($Package.ProductName) Already Installed"
            Write-Verbose "Installed $($Installed.Version)"
        }
    }
    $result | Out-Null
}