Function Get-SQLServerInfo {

    <#
    .SYNOPSIS
        Runs a script containing statements supported by the SQL Server SQLCMD utility.

    .DESCRIPTION
        The Invoke-Sqlcmd cmdlet runs a script containing the languages and commands supported by the SQL Server SQLCMD utility.

        The commands supported are Transact-SQL statements and the subset of the XQuery syntax that is supported by the database engine.

        This cmdlet also accepts many of the commands supported natively by SQLCMD, such as GO and QUIT.

        This cmdlet also accepts the SQLCMD scripting variables, such as SQLCMDUSER. By default, this cmdlet does not set SQLCMD scripting variables.

        This cmdlet does not support the use of commands that are primarily related to interactive script editing.

        The commands not supported include :!!, :connect, :error, :out, :ed, :list, :listvar, :reset, :perftrace, and :serverlist.

        When this cmdlet is run, the first result set that the script returns is displayed as a formatted table.

        If subsequent result sets contain different column lists than the first, those result sets are not displayed.

        If subsequent result sets after the first set have the same column list, their rows are appended to the formatted table that contains the rows that were returned by the first result set.

        You can display SQL Server message output, such as those that result from the SQL PRINT statement, by specifying the Verbose parameter.

    .PARAMETER AbortOnError
        Indicates that this cmdlet stops the SQL Server command and returns an error level to the Windows PowerShell ERRORLEVEL variable if this cmdlet encounters an error.

        The error level returned is 1 if the error has a severity higher than 10, and the error level is 0 if the error has a severity of 10 or less.

        If the ErrorLevel parameter is also specified, this cmdlet returns 1 only if the error message severity is also equal to or higher than the value specified for ErrorLevel.

    .PARAMETER AccessToken
        A valid access token to be used to authenticate to SQL Server, in alternative to user/password or Windows Authentication.

        This can be used, for example, to connect to `SQL Azure DB` and `SQL Azure Managed Instance`  using a `Service Principal` or a `Managed Identity` (see references at the bottom of this page)

        Do not specify UserName , Password , or Credential when using this parameter.

    .PARAMETER ConnectionString
        Specifies a connection string to connect to the server.

    .PARAMETER ConnectionTimeout
        Specifies the number of seconds when this cmdlet times out if it cannot successfully connect to an instance of the Database Engine. The timeout value must be an integer value between 0 and 65534. If 0 is specified, connection attempts do not time out.

    .PARAMETER Credential
        The PSCredential object whose Username and Password fields will be used to connect to the SQL instance.

    .PARAMETER Database
        Specifies the name of a database. This cmdlet connects to this database in the instance that is specified in the ServerInstance parameter.

        If the Database parameter is not specified, the database that is used depends on whether the current path specifies both the SQLSERVER:\SQL folder and a database name. If the path specifies both the SQL folder and a database name, this cmdlet connects to the database that is specified in the path. If the path is not based on the SQL folder, or the path does not contain a database name, this cmdlet connects to the default database for the current login ID. If you specify the IgnoreProviderContext parameter switch, this cmdlet does not consider any database specified in the current path, and connects to the database defined as the default for the current login ID.

    .PARAMETER DedicatedAdministratorConnection
        Indicates that this cmdlet uses a Dedicated Administrator Connection (DAC) to connect to an instance of the Database Engine.

        DAC is used by system administrators for actions such as troubleshooting instances that will not accept new standard connections.

        The instance must be configured to support DAC.

        If DAC is not enabled, this cmdlet reports an error and will not run.

    .PARAMETER DisableCommands
        Indicates that this cmdlet turns off some sqlcmd features that might compromise security when run in batch files.

        It prevents Windows PowerShell variables from being passed in to the Invoke-Sqlcmd script.

        The startup script specified in the SQLCMDINI scripting variable is not run.

    .PARAMETER DisableVariables
        Indicates that this cmdlet ignores sqlcmd scripting variables. This is useful when a script contains many INSERT statements that may contain strings that have the same format as variables, such as $(variable_name).

    .PARAMETER EncryptConnection
        Indicates that this cmdlet uses Secure Sockets Layer (SSL) encryption for the connection to the instance of the Database Engine specified in the ServerInstance parameter.

        If this parameter is specified, SSL encryption is used.

        If you do not specify this parameter, specified encryption is not used.

    .PARAMETER ErrorLevel
        Specifies that this cmdlet display only error messages whose severity level is equal to or higher than the value specified. All error messages are displayed if this parameter is not specified or set to 0. Database Engine error severities range from 1 to 24.

    .PARAMETER HostName
        Specifies a workstation name. The workstation name is reported by the sp_who system stored procedure and in the hostname column of the sys.processes catalog view. If this parameter is not specified, the default is the name of the computer on which Invoke-Sqlcmd is run. This parameter can be used to identify different Invoke-Sqlcmd sessions.

    .PARAMETER IgnoreProviderContext
        Indicates that this cmdlet ignores the database context that was established by the current SQLSERVER:\SQL path. If the Database parameter is not specified, this cmdlet uses the default database for the current login ID or Windows account.

    .PARAMETER IncludeSqlUserErrors
        Indicates that this cmdlet returns SQL user script errors that are otherwise ignored by default. If this parameter is specified, this cmdlet matches the default behavior of the sqlcmd utility.

    .PARAMETER InputFile
        Specifies a file to be used as the query input to this cmdlet. The file can contain Transact-SQL statements, XQuery statements, and sqlcmd commands and scripting variables. Specify the full path to the file. Spaces are not allowed in the file path or file name. The file is expected to be encoded using UTF-8.

        You should only run scripts from trusted sources. Ensure all input scripts are secured with the appropriate NTFS permissions.

    .PARAMETER MaxBinaryLength
        Specifies the maximum number of bytes returned for columns with binary string data types, such as binary and varbinary. The default value is 1,024 bytes.

    .PARAMETER MaxCharLength
        Specifies the maximum number of characters returned for columns with character or Unicode data types, such as char, nchar, varchar, and nvarchar. The default value is 4,000 characters.

    .PARAMETER NewPassword
        Specifies a new password for a SQL Server Authentication login ID. This cmdlet changes the password and then exits. You must also specify the Username and Password parameters, with Password that specifies the current password for the login.

    .PARAMETER OutputAs
        Specifies the type of the results this cmdlet gets.

        If you do not specify a value for this parameter, the cmdlet sets the value to DataRows.

    .PARAMETER OutputSqlErrors
        Indicates that this cmdlet displays error messages in the Invoke-Sqlcmd output.

    .PARAMETER Password
        Specifies the password for the SQL Server Authentication login ID that was specified in the Username parameter. Passwords are case-sensitive. When possible, use Windows Authentication. Do not use a blank password, when possible use a strong password.

        If you specify the Password parameter followed by your password, the password is visible to anyone who can see your monitor.

        If you code Password followed by your password in a .ps1 script, anyone reading the script file will see your password.

        Assign the appropriate NTFS permissions to the file to prevent other users from being able to read the file.

    .PARAMETER QueryTimeout
        Specifies the number of seconds before the queries time out. If a timeout value is not specified, the queries do not time out. The timeout must be an integer value between 1 and 65535.

    .PARAMETER ServerInstance
        Specifies a character string or SQL Server Management Objects (SMO) object that specifies the name of an instance of the Database Engine. For default instances, only specify the computer name: MyComputer. For named instances, use the format ComputerName\InstanceName.

    .PARAMETER SeverityLevel
        Specifies the lower limit for the error message severity level this cmdlet returns to the ERRORLEVEL Windows PowerShell variable.

        This cmdlet returns the highest severity level from the error messages generated by the queries it runs, provided  that severity is equal to or higher than specified in the SeverityLevel parameter.

        If SeverityLevel is not specified or set to 0, this cmdlet returns 0 to ERRORLEVEL.

        The severity levels of Database Engine error messages range from 1 to 24.

        This cmdlet does not report severities for informational messages that have a severity of 10

    .PARAMETER SuppressProviderContextWarning
        Indicates that this cmdlet suppresses the warning that this cmdlet has used in the database context from the current SQLSERVER:\SQL path setting to establish the database context for the cmdlet.

    .PARAMETER Username
        Specifies the login ID for making a SQL Server Authentication connection to an instance of the Database Engine.

        The password must be specified through the Password parameter.

        If Username and Password are not specified, this cmdlet attempts a Windows Authentication connection using the Windows account running the Windows PowerShell session. When possible, use Windows Authentication.

    .PARAMETER Variable
        Specifies, as a string array, a sqlcmd scripting variable for use in the sqlcmd script, and sets a value for the variable.

        Use a Windows PowerShell array to specify multiple variables and their values.

    .EXAMPLE

    .OUTPUTS

    .LINK
        SQLServer_Cmdlets

    .LINK
        https://docs.microsoft.com/azure/azure-sql/database/authentication-aad-service-principal

    .LINK
        Service Principal

    .LINK
        https://docs.microsoft.com/en-us/azure/app-service/app-service-web-tutorial-connect-msi

    .LINK
        Managed Identity
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingUsernameAndPasswordParams", "")]
    [CmdletBinding(DefaultParameterSetName = 'ByConnectionParameters')]
    param(
        [Parameter(ParameterSetName = 'ByConnectionParameters', ValueFromPipeline = $true)]
        [psobject]
        ${ServerInstance},

        [Parameter(ParameterSetName = 'ByConnectionParameters')]
        [ValidateNotNullOrEmpty()]
        [string]
        ${Database},

        [Parameter(ParameterSetName = 'ByConnectionParameters')]
        [switch]
        ${EncryptConnection},

        [Parameter(ParameterSetName = 'ByConnectionParameters')]
        [ValidateNotNullOrEmpty()]
        [string]
        ${Username},

        [Parameter(ParameterSetName = 'ByConnectionParameters')]
        [ValidateNotNullOrEmpty()]
        [string]
        ${AccessToken},

        [Parameter(ParameterSetName = 'ByConnectionParameters')]
        [ValidateNotNullOrEmpty()]
        [string]
        ${Password},

        [Parameter(ParameterSetName = 'ByConnectionParameters')]
        [ValidateNotNullOrEmpty()]
        [pscredential]
        [System.Management.Automation.CredentialAttribute()]
        ${Credential},

        #[Parameter(Position=0)]
        #[ValidateNotNullOrEmpty()]
        #[string]
        #${Query},

        [ValidateRange(0, 65535)]
        [int]
        ${QueryTimeout},

        [Parameter(ParameterSetName = 'ByConnectionParameters')]
        [int]
        ${ConnectionTimeout},

        [ValidateRange(-1, 255)]
        [int]
        ${ErrorLevel},

        [ValidateRange(-1, 25)]
        [int]
        ${SeverityLevel},

        [ValidateRange(1, 2147483647)]
        [int]
        ${MaxCharLength},

        [ValidateRange(1, 2147483647)]
        [int]
        ${MaxBinaryLength},

        [switch]
        ${AbortOnError},

        [Parameter(ParameterSetName = 'ByConnectionParameters')]
        [switch]
        ${DedicatedAdministratorConnection},

        [switch]
        ${DisableVariables},

        [switch]
        ${DisableCommands},

        [Parameter(ParameterSetName = 'ByConnectionParameters')]
        [ValidateNotNullOrEmpty()]
        [string]
        ${HostName},

        [Parameter(ParameterSetName = 'ByConnectionParameters')]
        [string]
        ${NewPassword},

        [string[]]
        ${Variable},
<#
        [ValidateNotNullOrEmpty()]
        [string]
        ${InputFile},
#>
        [bool]
        ${OutputSqlErrors},

        [switch]
        ${IncludeSqlUserErrors},

        [Parameter(ParameterSetName = 'ByConnectionParameters')]
        [switch]
        ${SuppressProviderContextWarning},

        [Parameter(ParameterSetName = 'ByConnectionParameters')]
        [switch]
        ${IgnoreProviderContext},
<#
        [Alias('As')]
        [Microsoft.SqlServer.Management.PowerShell.OutputType]
        ${OutputAs},
#>
        [Parameter(ParameterSetName = 'ByConnectionString', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        ${ConnectionString})

    begin {
        try {
            $outBuffer = $null
            if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer)) {
                $PSBoundParameters['OutBuffer'] = 1
            }
            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('SqlServer\Invoke-Sqlcmd', [System.Management.Automation.CommandTypes]::Cmdlet)
            $Query = @"
            Select
                @@VERSION as [Version],
                @@SERVERNAME As [ServerName],
                SUSER_NAME() as [Login],
                DB_NAME() as [Database],
                USER_NAME() as [User],
                SERVERPROPERTY('INSTANCEDEFAULTDATAPATH') AS [Default_Data_path],
                SERVERPROPERTY('INSTANCEDEFAULTLOGPATH') AS  [Default_log_path]
"@
            $scriptCmd = {& $wrappedCmd @PSBoundParameters -Query $Query | Select @{n="Version";e={$_.Version.Split("`n")[0]}},ServerName,Login,Database,User,Default_Data_path,Default_log_path}
            $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
            $steppablePipeline.Begin($PSCmdlet)
        }
        catch {
            throw
        }
    }

    process {
        try {
            $steppablePipeline.Process($_)
        }
        catch {
            throw
        }
    }

    end {
        try {
            $steppablePipeline.End()
        }
        catch {
            throw
        }
    }



} # End of function: Get-DBObjects
Get-SQLServerInfo