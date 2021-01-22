function Set-CredentialManagerCredential {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
    param (
        [String]$Target,
        [Parameter(ParameterSetName='USER+PASS')]
        [String]$User,
        [Parameter(ParameterSetName='USER+PASS')]
        [SecureString]$Pass,
        [Parameter(ParameterSetName='CREDENTIAL')]
        [PSCredential]$UserCredential,
        [String]$Comment
    )
    IF($PSCmdlet.ParameterSetName -eq 'CREDENTIAL'){
        $User = $UserCredential.UserName
        $Pass = $UserCredential.Password
    }
    $TextPass = ConvertTo-PlainText $Pass
    $Target = if ($User){"$User@$Target"} else {$Target}
	ConvertFrom-CredMan(credman -AddCred -Target $Target -User $User -Pass $TextPass -Comment "$Comment")
}