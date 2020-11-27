BeforeAll {
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '', Scope = '*', Target = 'SuppressImportModule')]
    $SuppressImportModule = $flase
    . $PSScriptRoot\Shared.ps1
    . $PSScriptRoot\Get-Function.ps1
}

Describe "Module Functions correctly exported"{
    BeforeAll{
        [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '', Scope = '*', Target = 'SuppressImportModule')]
        $ModuleCommands = Get-Command -Module $ModuleName
        [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '', Scope = '*', Target = 'SuppressImportModule')]
        $PublicFunctions = Get-ChildItem $PSScriptRoot\..\src\public\*.ps1 -Recurse -File |Get-Function| Select Name -ExpandProperty Extent | Select Name, File
        [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '', Scope = '*', Target = 'SuppressImportModule')]
        $PrivateFunctions = Get-ChildItem $PSScriptRoot\..\src\private\*.ps1 -Recurse -File |Get-Function| Select Name -ExpandProperty Extent | Select Name, File
    }
    it "Lists Correct Number of functions" {
        ($ModuleCommands).Count | Should -Be ($PublicFunctions | Measure-Object ).Count
    }
    it "Lists all Public Functions"{
        $result = $true
        foreach ($function in $PublicFunctions) {
            If ($ModuleCommands -like $function.Name){
            } else {
                $result = $false
            }
        }
        $result | Should -Be $true

    }
    it "No private functions are available in module"{
        $result = $false
        foreach ($function in $PrivateFunctions) {
            If ($ModuleCommands -like $function.Name){
                $result = $false
            } else {

            }
        }
        $result | Should -Be $false
    }

}
