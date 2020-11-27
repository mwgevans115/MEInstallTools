BeforeAll {
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '', Scope = '*', Target = 'SuppressImportModule')]
    $SuppressImportModule = $flase
    . $PSScriptRoot\Shared.ps1
}


Describe 'Verify Function Returns Path' {
    BeforeAll{
        $actual = Get-DownloadFolder
    }
    It 'Returns a String' {
        $actual | Should -BeOfType 'String'
    }
    It 'Should return a folder' {
        Test-Path -LiteralPath $actual -PathType Container | Should -BeTrue
    }
}

