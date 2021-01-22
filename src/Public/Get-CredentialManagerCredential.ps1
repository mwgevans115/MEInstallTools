function Get-CredentialManagerCredential {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
    param (
        [String]$Target,
        [String]$User
    )
    ConvertFrom-CredMan(credman -GetCred -Target "$(if ($User){"$User@$Target"} else {$Target})")
}