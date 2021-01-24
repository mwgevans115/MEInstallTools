function Install-Package {
    param (
        $Package
    )


    if ($Package.Name.EndsWith('.msi')) {
        $result = Install-MSI -MSI $Package
    }
    else {
        $result = Start-Process -Wait -FilePath "$($Package.FullName)" -ArgumentList "/qb" -PassThru
    }
    $Message = switch ($result.ExitCode) {
        1602 { "The user has cancelled the installation. Solution: just don’t cancel it" }
        1603 { "A fatal error occurred during installation."}
        1641 { "The requested operation completed successfully. The system will be restarted so the changes can take effect" }
        3010 { "The requested operation is successful. Changes will not be effective until the system is rebooted." }
        0 { "The requested operation completed successfully" }
        Default { "The requested operation failed" }
    }
    If ((Get-Module -Name Logging) -and (Get-LoggingTarget)) { Write-Log -Level WARNING "$Message"}
            else { Write-Verbose "$Message" }
    return $result
}