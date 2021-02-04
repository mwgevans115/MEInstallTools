Function Set-InitialLogging {
  <#
  .SYNOPSIS
      Function to Initialise Logging

  .NOTES
      Name: Set-InitialLogging
      Author: Mark Evans
      Version: 1.0
      DateCreated: 02/02/2021

  .EXAMPLE
      Set-InitialLogging -LiteralPath 'C:\fred.log'


  .LINK

  #>
  [OutputType([System.IO.FileInfo])]
  [CmdletBinding()]
  param(
    [String]$LiteralPath,
    [ValidateSet('DEBUG', 'INFO', 'WARNING', 'ERROR')]
    $logging_defaultlevel,
    [String]$DefaultFormat = '[%{timestamp:+%T}] [%{level:-7}] %{message}'

  )
  if ($logging_defaultlevel -notin @('DEBUG', 'INFO', 'WARNING', 'ERROR')) {
    if ($DebugPreference -ne 'SilentlyContinue') { $DebugLevel = 'DEBUG' } else {
      if ($VerbosePreference -ne 'SilentlyContinue') { $DebugLevel = 'INFO' } else {
        if ($WarningPreference -ne 'SilentlyContine') { $DebugLevel = 'WARNING' } else {
          $DebugLevel = 'ERROR'
        }
      }
    }
  }
  else { $DebugLevel = $logging_defaultlevel }
  Set-LoggingDefaultLevel -Level $DebugLevel
  Set-LoggingDefaultFormat $DefaultFormat
  Add-LoggingTarget -Name Console
  If ($LiteralPath) {
    Add-LoggingTarget -Name File -Configuration @{Path = $LiteralPath; LEVEL = 'DEBUG' }
  }
}











