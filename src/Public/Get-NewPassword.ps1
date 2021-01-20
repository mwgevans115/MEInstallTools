function Get-NewPassword {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
    param (
        [Int]$Length = 15
    )
    try {
        [reflection.assembly]::loadwithpartialname("system.web") | Out-Null
    }
    catch {
        Write-Log -Level ERROR -Message 'Unable to load module to create new password'
    }
    do {
        $Password = [System.Web.Security.Membership]::GeneratePassword($Length, 3)
    } until (!($Password.Contains(';') -or ($Password.Contains("'"))))

    Return ConvertTo-SecureString -String "$Password" -AsPlainText -Force
}