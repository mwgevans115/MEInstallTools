function ConvertTo-PlainText {
    param (
        [SecureString]$EncryptedString
    )
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($EncryptedString)
    Return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
}