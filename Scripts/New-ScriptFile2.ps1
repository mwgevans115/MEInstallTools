
<#PSScriptInfo

.VERSION 0.0.1

.GUID 2dcc6677-0849-4f50-b440-75b7e13fe5c0

.AUTHOR Mark Evans <mark.evans@mnpthesolution.com>

.COMPANYNAME MNP

.COPYRIGHT 2021 MNP. All rights reserved.

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


.PRIVATEDATA

#>

<#

.SYNOPSIS
  <Overview of script>

.DESCRIPTION
  <Brief description of script>

.PARAMETER <Parameter_Name>
    <Brief description of parameter input required. Repeat this attribute if required>

.INPUTS
  <Inputs if any, otherwise state None>

.OUTPUTS
  <Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>

.NOTES
  Version:        0.0.1
  Author:         Mark Evans <mark.evans@mnpthesolution.com>
  Creation Date:  02/02/2021
  Purpose/Change: Initial script development

.EXAMPLE
  <Example goes here. Repeat this attribute for more than one example>
#>[CmdletBinding()]
param (
    # Parameter with help message can have default changed by user/data file
    [Parameter(HelpMessage = "Prompt Displayed to User")]
    #[TypeName]
    ='<default>',
    [Parameter()]
    #[TypeName]
    ='<default>'
)
#region --------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
#$ErrorActionPreference = "SilentlyContinue"

#Load required Modules
#endregion
#region ---------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
Test-ScriptFileInfo $MyInvocation.MyCommand.Path
$sScriptVersion = "1.0"

#Log File Info
$sLogPath = "C:\Windows\Temp"
$sLogName = "<script_name>.log"
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName
#endregion
#region ----------------------------------------------------[Functions]------------------------------------------------------------

<#

Function <FunctionName>{
  Param()

  Begin{
    Log-Write -LogPath $sLogFile -LineValue "<description of what is going on>..."
  }

  Process{
    Try{
      <code goes here>
    }

    Catch{
      Log-Error -LogPath $sLogFile -ErrorDesc
<#PSScriptInfo

.VERSION 0.0.1

.GUID 2dcc6677-0849-4f50-b440-75b7e13fe5c0

.AUTHOR Mark Evans <mark.evans@mnpthesolution.com>

.COMPANYNAME MNP

.COPYRIGHT 2021 MNP. All rights reserved.

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


.PRIVATEDATA

#>

<#

.DESCRIPTION
 My new script file test

#>
Param()

.Exception -ExitGracefully $True
      Break
    }
  }

  End{
    If($?){
      Log-Write -LogPath $sLogFile -LineValue "Completed Successfully."
      Log-Write -LogPath $sLogFile -LineValue " "
    }
  }
}

#>
#endregion
#region ----------------------------------------------------[Execution]------------------------------------------------------------

#Log-Start -LogPath $sLogPath -LogName $sLogName -ScriptVersion $sScriptVersion
#Script Execution goes here
#Log-Finish -LogPath $sLogFile
#endregion
Wait-Logging

