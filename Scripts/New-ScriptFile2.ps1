
<#PSScriptInfo

.VERSION 0.0.1

.GUID 166f5383-8be2-437c-9c15-de7703c4c4ae

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
  Creation Date:  03/02/2021
  Purpose/Change: Initial script development

.EXAMPLE
  <Example goes here. Repeat this attribute for more than one example>
#>
[CmdletBinding()]
param (
    # Parameter with help message can have default changed by user/data file
    [Parameter(HelpMessage = "Prompt Displayed to User")]
    #[TypeName]
    $ParameterName='<default>',
    [Parameter()]
    #[TypeName]
    $ParameterName1='<default>'
)
#region ---------------------------------------------------[Declarations]----------------------------------------------------------
DATA required_modules {@('Logging')}
DATA logging_defaultlevel {''} #Set to override powershell log levels

#endregion
#region --------------------------------------------------[Initialisations]--------------------------------------------------------
#Set Error Action to Silently Continue
#$ErrorActionPreference = "SilentlyContinue"

Remove-Module MEInstallTools -Force -ErrorAction SilentlyContinue
If (Get-Module -ListAvailable -Name MEInstallTools) {
  Import-Module MEInstallTools
}
else {
  $Module = (Get-ChildItem -Path .\src\* -Recurse -Include 'MEInstallTools.psd1' | Select -First 1).FullName
  Import-Module $Module
}

#Load required Modules
Install-Modules -Modules $required_modules

#Script Version
#$oScriptInfo = Test-ScriptFileInfo -LiteralPath ($MyInvocation.MyCommand.Path)

#Set Log File
$fLogFile = Get-LogFile

#Initialise Logging
Set-InitialLogging $fLogFile.FullName 'debug' '[%{timestamp:+%T} %{level:-7}] %{message}'
Write-LogHeader

#Allow user to enter parameters
Read-ScriptParameter -UseStored:$save_defaultparametervalues
Write-LogScriptParameter

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
      Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
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

