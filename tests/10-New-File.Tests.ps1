BeforeAll {
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '', Scope = '*', Target = 'SuppressImportModule')]
    $SuppressImportModule = $flase
    . $PSScriptRoot\Shared.ps1
}


Describe 'Verify Path Processing for Non-existing Paths Allowed Impl' {
    BeforeAll {
        New-Item (Join-Path $TestDrive 'WorkingFolder') -Force -ItemType Directory
        Push-Location -Path (Join-Path $TestDrive 'WorkingFolder')
        New-Item (Join-Path $TestDrive "Tests\foo[1].txt") -Force -ItemType File
    }
    It 'Processes non-wildcard absolute path to non-existing file via -Path param' {
        New-File -Path $TestDrive\ReadmeNew.md | Select-Object -ExpandProperty Object | Should -Be "$TestDrive\READMENew.md"
    }
    It 'Processes multiple absolute paths via -Path param' {
        New-File -Path $TestDrive\Readme.md, $TestDrive\XYZZY.ps1 | Select-Object -ExpandProperty Object |
        Should -Be @("$TestDrive\README.md", "$TestDrive\XYZZY.ps1")
    }
    It 'Processes relative path via -Path param' {
        New-File -Path ..\Examples\READMENew.md | Select-Object -ExpandProperty Object | Should -Be "$TestDrive\Examples\READMENew.md"
    }
    It 'Processes multiple relative path via -Path param' {
        New-File -Path ..\Examples\README.md, XYZZY.ps1 | Select-Object -ExpandProperty Object |
        Should -Be @("$TestDrive\Examples\README.md", "$TestDrive\WorkingFolder\XYZZY.ps1")
    }

    It 'Should accept pipeline input to Path' {
        Get-ChildItem -LiteralPath "$TestDrive\Tests\foo[1].txt" | New-File |
        Select-Object -ExpandProperty Object | Should -Be "$TestDrive\Tests\foo[1].txt"
    }
    AfterAll {
        Pop-Location
    }
}

