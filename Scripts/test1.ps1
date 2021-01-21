[CmdletBinding(DefaultParameterSetName = 'USER+PASSWORD')]
param (
    [Parameter(ParameterSetName = 'USER+PASSWORD')]
    [String]
    $OrderActiveUsername = 'MarkEvans',
    [Parameter(ParameterSetName = 'USER+PASSWORD')]
    [SecureString]$OrderActiveSecurePassword
)
Add-LoggingTarget -Name Console -Configuration @{Level = 'DEBUG'; Format = '[%{timestamp:+%T} %{level:-7}] %{message}' }
#region orderactivecredentials
$SaveCredentials = $true
If ($PSCmdlet.ParameterSetName -eq 'USER+PASSWORD') {
    if (!($OrderActiveSecurePassword)) {
        $CredentialManagerCredential = Get-CredentialManagerCredential -Target 'MNP' -User $OrderActiveUserName
        if ($CredentialManagerCredential.User) {
            Write-Log -Level INFO -Message 'Using Stored Credential'
            Write-Log -Level DEBUG -Message "`tTarget : {0}" -Arguments $CredentialManagerCredential.Target
            Write-Log -Level DEBUG -Message "`tUser   : {0}" -Arguments $CredentialManagerCredential.User
            Write-Log -Level DEBUG -Message "`tComment: {0}" -Arguments $CredentialManagerCredential.Comment
            $OrderActiveSecurePassword = $CredentialManagerCredential.SecurePass
            $SaveCredentials = $false
        }
        else {
            Write-Output "Enter Password for $OrderActiveUserName (Leave Blank to generate)"
            $OrderActiveSecurePassword = Read-Host -AsSecureString
            If ($OrderActiveSecurePassword.Length -eq 0) {
                Write-Log -Level WARNING -Message 'Generating Password for SQL Login "{0}"' -Arguments $OrderActiveUser
                $OrderActiveSecurePassword = Get-NewPassword
            }
            else {
                Write-Log -Level INFO -Message 'Using Input Password for SQL Login "{0}"' -Arguments $OrderActiveUser
            }
        }
    }
    $OrderActiveUserCredential = New-Object System.Management.Automation.PSCredential ($OrderActiveUsername, $OrderActiveSecurePassword)
}
if ($SaveCredentials) {
    Write-Log -Level WARNING -Message "Saving Credentials for {0} to Credential Manager" -Arguments $OrderActiveUserCredential.UserName
    $CredentialManagerCredential = Set-CredentialManagerCredential -Target 'MNP' -UserCredential $OrderActiveUserCredential -Comment "Set by install script $(Get-Date)"
    Write-Log -Level DEBUG -Message "`tTarget : {0}" -Arguments $CredentialManagerCredential.Target
    Write-Log -Level DEBUG -Message "`tUser   : {0}" -Arguments $CredentialManagerCredential.User
    Write-Log -Level DEBUG -Message "`tComment: {0}" -Arguments $CredentialManagerCredential.Comment
}
#endregion orderactivecredentials

$SQLParams = @{
    ServerInstance = 'localhost'
}
#region Checking/Creating OrderActive User on databases
Write-Log -Level INFO -Message "Checking/Creating Login on {0}" -Arguments $SQLParams.ServerInstance
$Login = Get-SqlLogin @SQLParams -LoginName $OrderActiveUserCredential.UserName -ErrorAction SilentlyContinue
If ($Login) {
    Write-Log -Level INFO -Message "`tLogin {0} Exists" -Arguments $OrderActiveUserCredential.UserName
    try {
        Invoke-Sqlcmd @SQLParams -Query 'Select ''String''' -Credential $OrderActiveUserCredential -ErrorAction SilentlyContinue
    }
    catch {
        if (Invoke-Sqlcmd @SQLParams -Query "Exec sp_who" | Where-Object {$_.ItemArray[3] -eq $OrderActiveUserCredential.UserName}){
            Write-Log -Level ERROR -Message "`tIncorrect Credentials and User {0} Logged In" -Arguments $OrderActiveUserCredential.UserName
            $PreRequisites = $false
        } else {
            Remove-SqlLogin @SQLParams -LoginName $OrderActiveUserCredential.UserName -Force
            Write-Log -Level WARNING -Message "`tIncorrect Credentials - Removing Login {0}" -Arguments $OrderActiveUserCredential.UserName
        }
    }
}
$Login = Get-SqlLogin @SQLParams -LoginName $OrderActiveUserCredential.UserName -ErrorAction SilentlyContinue
If (!($Login)) {
    Write-Log -Level WARNING -Message "`tCreating New Login {0}" -Arguments $OrderActiveUserCredential.UserName
    Add-SqlLogin @SQLParams -LoginPSCredential $OrderActiveUserCredential `
        -Enable -LoginType SqlLogin -EnforcePasswordExpiration:$false `
        -DefaultDatabase 'OrderActive' -GrantConnectSql -MustChangePasswordAtNextLogin:$false | Out-Null
}
$role = 'db_owner'
@('OrderActive', 'MNPServiceCfg', 'MNPCalendar', 'MNPUserMaster') | ForEach-Object {
    $userRoles = Get-DBLogin -Login $OrderActiveUserCredential.UserName -Database $_ -OutputAs DataTables
    $dvRoles = New-Object System.Data.DataView($userRoles)
    $dvRoles.RowFilter = "Isnull(DBUserName,'') = ''"   #"DBUserName <> ''"
    if ($dvRoles.Count -gt 0){
        Write-Log -Level WARNING "`tAdding User {0} for Login {1} on Database {2}" -Arguments $OrderActiveUserCredential.UserName,$OrderActiveUserCredential.UserName,$_
        $Query = "DROP USER IF EXISTS $($OrderActiveUserCredential.UserName); CREATE USER $($OrderActiveUserCredential.UserName) FOR LOGIN $($OrderActiveUserCredential.UserName);"
        Invoke-Sqlcmd @SQLParams -Database $_ -Query $Query
    } else {
        Write-Log -Level DEBUG -Message "`tUser {0} for Login {1} on Database {2} {3}" -Arguments $OrderActiveUserCredential.UserName,$OrderActiveUserCredential.UserName,$_,'EXISTS'
    }
    $dvRoles.RowFilter = "DBUserRole = 'db_owner'"
    if ($dvRoles.Count -gt 0) {
        Write-Log -Level DEBUG -Message "`tUser {0} in db_owner role on Database {1}" -Arguments $OrderActiveUserCredential.UserName,$_
    }
    else {
        Write-Log -Level WARNING -Message "`tUser {0} not in db_owner role on Database {1}" -Arguments $OrderActiveUserCredential.UserName,$_
        $Query = "ALTER ROLE [db_owner] ADD MEMBER [$($OrderActiveUserCredential.UserName)]"
        Invoke-Sqlcmd @SQLParams -Database $_ -Query $Query
    }
}
#endregion

Wait-Logging
Invoke-Sqlcmd @SQLParams -Query 'Select ''String''' -Credential $OrderActiveUserCredential

