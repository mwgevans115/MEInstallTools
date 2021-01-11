Function Test-Filelock {
    Param(
        [Parameter()]
        [IO.FileInfo]$File
    )
    try {
        $fs = $file.Open('open', 'read', 'Read')
        $fs.Close()
        Write-Verbose "$file not open"
        return $false
    }
    catch {
        return $true
    }

}