function Install-Modules {
    param (
        [String[]]
        $Modules=@('Logging','SqlServer','SharePointPnPPowerShellOnline'),
        [ValidateSet("CurrentUser", "AllUsers")]
        $Scope = "CurrentUser"
    )
    $InstallModuleParams = @{
        Force = $true
        Scope = $Scope
        AllowClobber = $true
    }
    @('PackageManagement') + $Modules  | ForEach-Object {
        $LatestVersion = [Version](Find-Module -Name $_).Version
        $CurrentVersion = Get-Module -ListAvailable -Name $_ | ForEach-Object { [Version]$_.Version } | Sort-Object $_ | Select-Object -Last 1
        IF ($LatestVersion -gt $CurrentVersion) {
            Write-Warning "Installing Module $_ Version $($LatestVersion.ToString())"
            if ($_ -eq 'PackageManagement'){Install-PackageProvider NuGet -Force -Scope $Scope}
            Install-Module @InstallModuleParams -Name $_
        } else {
            Write-Debug "Modile $_ Version $($CurrentVersion.ToString()) already installed"
        }
        Remove-Module -Name $_ -Force -ErrorAction SilentlyContinue
        Import-Module -Name $_ -Force
    }
}
#Install-Modules -Modules @('Logging')
