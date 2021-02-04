function Get-InternetExplorerESC {
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    if (Test-Path -path $AdminKey) {
        Return @{ Admin = (Get-ItemProperty -Path $AdminKey).IsInstalled
            User        = (Get-ItemProperty -Path $UserKey).IsInstalled
        }
    }
    else {
        Return @{ Admin = 0
            User        = 0
        }
    }
}

function Set-InternetExplorerESC {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true, ParameterSetName = "Flexible")]
        $Admin,
        [Parameter(Position = 1, Mandatory = $true, ParameterSetName = "Flexible")]
        $User,
        [Parameter(Position = 0, Mandatory = $true, ParameterSetName = "Disable")]
        [Switch]
        $DisableAll,
        [Parameter(Position = 0, Mandatory = $true, ParameterSetName = "Enable")]
        [Switch]
        $EnableAll
    )
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    if (Test-Path -path $AdminKey) {
        switch ($PsCmdlet.ParameterSetName) {
            'Disable' { if ($DisableAll) { $Admin = 0; $User = 0 } else { $Admin = 1; $User = 1 } }
            'Enable' { if ($EnableAll) { $Admin = 1; $User = 1 } else { $Admin = 0; $User = 0 } }
        }
        Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value $Admin
        Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value $User
        Stop-Process -Name Explorer
    }
}