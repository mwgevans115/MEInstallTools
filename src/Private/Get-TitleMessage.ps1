function Get-TitleMessage {
    param (
        [String]$Title,
        [Int]
        $LogFormatLength = 19,
        [Int]
        $LogLineLength = $Host.UI.RawUI.BufferSize.Width - $LogFormatLength,
        [char]$PadChar = '*'
    )
    If ($Title){ $Title = " $Title " }
    Return $Title.PadLeft(($LogLineLength / 2) + ($Title.Length / 2), $PadChar).PadRight($LogLineLength, $PadChar)
}