# Dot source this script in any Pester test script that requires the module to be imported.
$ModuleName = 'MEInstallTools'
$ModuleManifestName = $ModuleName + '.psd1'
$ModuleManifestPath = "$PSScriptRoot\..\src\$ModuleManifestName"

if (!$SuppressImportModule) {
    # -Scope Global is needed when running tests from inside of psake, otherwise
    # the module's functions cannot be found in the MEInstallTools\ namespace
    Get-Module -Name $ModuleName -ErrorAction SilentlyContinue | Remove-Module -Force
    Import-Module $ModuleManifestPath -Scope Global
}

