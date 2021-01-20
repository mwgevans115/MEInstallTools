function ConvertFrom-Credman {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '')]
    param (
        $CredText
    )
    New-Object PSObject -Property @{
        Target       = ($CredText.Split("`n") -Match 'Target').Split(':')[1].Trim()
        User         = ($CredText.Split("`n") -Match 'UserName').Split(':')[1].Trim()
        Comment      = ($CredText.Split("`n") -Match 'Comment').Split(':')[1].Trim()
        SecurePass   = ConvertTo-SecureString ($CredText.Split("`n") -Match 'Password').Split(':')[1].Trim() -AsPlainText -Force
    }
}