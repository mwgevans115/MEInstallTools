
Add-LoggingTarget -Name Console -Configuration @{Level = 'DEBUG' }
$webConfig = (get-content C:\wwwroot\oms-admin\Web.config) -as [XML]
Write-Log -Level INFO -Message "Documenting web.config settings"
@('AuthMode', 'Environment.AllowDebugProfiler', 'Environment.IsTest',
    'ValidationExpression_Code', 'ValidationExpression_Sku',
    'ValidationExpression_SourceCode', 'Validation_ForceNewCodesUppercase',
    'AppSecrets.UseMachineEncryptionVector', 'AppSecrets.AllowPasswordsInMemory',
    'UI.Active', 'Pages.Active') | ForEach-Object {
    $node = $webConfig.SelectSingleNode("//appSettings/add[@key='$_']")
    Write-Log -Level DEBUG -Message "`t{0} : {1}" -Arguments $node.key, $node.value
}

Write-Log "Setting Connection Strings"
$ConnectionSecrets = (Get-Content 'C:\wwwroot\oms-admin\ConnectionStrings.secret') -as [XML]
$ConnectionStrings = $ConnectionSecrets.SelectSingleNode("//connectionStrings")
@(@{Name = 'MNPUserMaster'; Database = 'MNPUserMaster'; ProviderName = "System.Data.SqlClient" },
    @{Name = 'Admin'; Database = 'OrderActive'; ProviderName = "System.Data.SqlClient" }) | ForEach-Object {
    $Builder = New-Object -TypeName 'System.Data.SqlClient.SqlConnectionStringBuilder'
    $builder["Data Source"] = "localhost"
    $builder["integrated Security"] = $true
    $builder["Initial Catalog"] = "$($_.Database)"
    $Builder["Persist Security Info"] = $true
    $Builder["User ID"] = "OrderActive"
    $Builder["Application Name"] = "OMSAdmin"
    $node = $ConnectionStrings.SelectSingleNode("//add[@name='$($_.Name)']")
    If (!($node)) {
        $node = $ConnectionStrings.AppendChild($ConnectionSecrets.CreateElement("add"))
    }
    $node.SetAttribute("name", "$($_.Name)")
    $node.SetAttribute("connectionString", $Builder.ConnectionString)
    $node.SetAttribute("providerName", $_.ProviderName)
}
$ConnectionSecrets.Save('C:\wwwroot\oms-admin\ConnectionStrings.secret')

Write-Log "Setting appSettings Secrets"
$AppSettingsSecrets = (Get-Content 'C:\wwwroot\oms-admin\AppSettings.secret') -as [XML]
$AppSettings = $AppSettingsSecrets.SelectSingleNode("//appSettings")
@(@{key="Admin.Password";value=""},
@{key="MNPUserMaster.Password";value=""}) | ForEach-Object {
    $node = $AppSettings.SelectSingleNode("//add[@key='$($_.key)']")
    If (!($node)) {
        $node = $AppSettings.AppendChild($AppSettingsSecrets.CreateElement("add"))
    }
    $node.SetAttribute("key", $_.key)
    $node.SetAttribute("value", $_.value)
}
$AppSettingsSecrets.Save('C:\wwwroot\oms-admin\AppSettings.secret')
$R = Invoke-WebRequest 'http://localhost:8080/Home/Encrypt' -SessionVariable Session
# This command stores the first form in the Forms property of the $R variable in the $Form variable.
$Form = $R.Forms[0]
# These commands populate the string to encrypt and the passwordmode of the respective Form fields.
$Form.Fields["StringToEncrypt"] = "Password"
$Form.Fields["PasswordMode"] = $true
# This command creates the Uri that will be used to log in to facebook.
# The value of the Uri parameter is the value of the Action property of the form.
#$Uri = "https://www.facebook.com" + $Form.Action
# Now the Invoke-WebRequest cmdlet is used to sign into the Facebook web service.
# The WebRequestSession object in the $FB variable is passed as the value of the WebSession parameter.
# The value of the Body parameter is the hash table in the Fields property of the form.
# The value of the *Method* parameter is POST. The command saves the output in the $R variable.
$R = Invoke-WebRequest -Uri 'http://localhost:8080/Home/Encrypt' -WebSession $Session -Method POST -Body $Form.Fields
if ($R.StatusDescription -eq 'OK') {
    if ($r.Content -match '(?<=<pre>).*?(?=</pre>)') {
        $EncryptedPassword = $Matches[0]
    }
}
Write-Log "Updating appSettings Secrets with encrypted password"
$AppSettingsSecrets = (Get-Content 'C:\wwwroot\oms-admin\AppSettings.secret') -as [XML]
$AppSettings = $AppSettingsSecrets.SelectSingleNode("//appSettings")
@(@{key="Admin.Password";value="$EncryptedPassword"},
@{key="MNPUserMaster.Password";value="$EncryptedPassword"}) | ForEach-Object {
    $node = $AppSettings.SelectSingleNode("//add[@key='$($_.key)']")
    If (!($node)) {
        $node = $AppSettings.AppendChild($AppSettingsSecrets.CreateElement("add"))
    }
    $node.SetAttribute("key", $_.key)
    $node.SetAttribute("value", $_.value)
}
$AppSettingsSecrets.Save('C:\wwwroot\oms-admin\AppSettings.secret')
