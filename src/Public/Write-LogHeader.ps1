function Write-LogHeader {
    [CmdletBinding()]
    param (
        [Parameter()]
        [Int]
        $LogFormatLength = 19,
        [Parameter()]
        [Int]
        $LogLineLength = $Host.UI.RawUI.BufferSize.Width - $LogFormatLength
    )
    $CallingCommandStack = (Get-PSCallStack)[1]
    #$Title = " $($CallingCommandStack.Command) "
    Write-Log -Level INFO -Message '{0}' -Arguments (Get-TitleMessage $CallingCommandStack.Command $LogFormatLength $LogLineLength)
    $ArgLines = (Get-WordWrappedText -chunk $CallingCommandStack.Arguments -LineLength ($LogLineLength - 4))
    foreach ($line in $ArgLines ) {
        Write-Log -Level INFO -Message "* {0} *" -Arguments $Line.PadRight($LogLineLength - 4, ' ')
    }
    Write-Log -Level INFO -Message '{0}' -Arguments (Get-TitleMessage '' $LogFormatLength $LogLineLength)
    $ScriptInfo = Test-ScriptFileInfo  (Get-PSCallStack)[1].InvocationInfo.MyCommand.Source
    If ($ScriptInfo) {
        Write-Log -Level DEBUG -Message "* {0} *" -Arguments "Script Name:        $($ScriptInfo.Name)".PadRight($LogLineLength - 4, ' ')
        Write-Log -Level DEBUG -Message "* {0} *" -Arguments "Script Version:     $($ScriptInfo.Version)".PadRight($LogLineLength - 4, ' ')
        Write-Log -Level DEBUG -Message "* {0} *" -Arguments "Script Author:      $($ScriptInfo.Author)".PadRight($LogLineLength - 4, ' ')
        Write-Log -Level DEBUG -Message "* {0} *" -Arguments "Script Description: ".PadRight($LogLineLength - 4, ' ')
        $Lines = (Get-WordWrappedText -chunk $ScriptInfo.Description -LineLength ($LogLineLength - 8))
        foreach ($line in $lines) {
            Write-Log -Level DEBUG -Message "*     {0} *" -Arguments $Line.PadRight($LogLineLength - 8, ' ')
        }
        $Title = ''
        Write-Log -Level DEBUG -Message '{0}' -Arguments $Title.PadLeft(($LogLineLength / 2) + ($Title.Length / 2), '*').PadRight($LogLineLength, '*')
    }
}
