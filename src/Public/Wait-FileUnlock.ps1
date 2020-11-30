Function Wait-FileUnlock{
    Param(
        [Parameter()]
        [IO.FileInfo]$File,
        [int]$SleepInterval=500
    )
    while(1){
        try{
           $fs=$file.Open('open','read', 'Read')
           $fs.Close()
            Write-Verbose "$file not open"
           return
           }
        catch{
           Start-Sleep -Milliseconds $SleepInterval
           Write-Verbose '-'
        }
	}
}