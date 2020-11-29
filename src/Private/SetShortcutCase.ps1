function Set-ShortcutCase ($ShortcutName) {
    $temp = $ShortcutName.Split('.')
    $Result = (Get-Culture).TextInfo.ToTitleCase($temp[0].ToLower())
    for ($i = 1; $i -lt $temp.Count; $i++) {
        $Result += '.' + $temp[$i]
    }
    $Result
}