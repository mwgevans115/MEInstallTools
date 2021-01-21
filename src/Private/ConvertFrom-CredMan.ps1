function ConvertFrom-Credman {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '')]
    param (
        $CredText
    )
    New-Object PSObject -Property @{
        Target       = $(try {($CredText.Split("`n") -Match 'Target').Split(':')[1].Trim()}catch{''})
        User         = $(try {($CredText.Split("`n") -Match 'UserName').Split(':')[1].Trim()}catch{''})
        Comment      = $(try {($CredText.Split("`n") -Match 'Comment').Split(':')[1].Trim()}catch{''})
        SecurePass   = $(try {ConvertTo-SecureString ($CredText.Split("`n") -Match 'Password').Split(':')[1].Trim() -AsPlainText -Force }catch{$null})
    }
}