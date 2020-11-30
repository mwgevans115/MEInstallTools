function New-StartTile {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        $Group,
        [System.IO.FileInfo]
        [Parameter(Mandatory = $true, ParameterSetName = "Item")]
        $Shortcut
    )


    if (!(Test-IsAdmin) ) {
        throw "This function requires elevation."
    }
    $ShortcutName = Set-ShortcutCase($Shortcut.Name)

    if (Get-Command Export-StartLayout) {
        # export current start layout to temporary file
        $tmp = New-TemporaryFile
        Export-StartLayout -Path $tmp.FullName

        # load start menu xml for manipulation
        $xml = New-Object -TypeName 'XML'
        $xml.Load($tmp.FullName)
        Remove-Item -Path $tmp.FullName

        $LayoutNode = $xml.DocumentElement.SelectSingleNode('//*[local-name()="StartLayout"]')
        $LayoutWidth = $LayoutNode.GroupCellWidth / 2
        # find existing Group
        $GroupNode = $xml.DocumentElement.SelectNodes("//*[local-name()=""Group"" and @Name=""$Group""]")
        # create group if it doesn't exist
        if (!($GroupNode) -or $GroupNode.Count -eq 0) {
            Write-Verbose "Creating Group Node"
            $GroupNodes = $xml.DocumentElement.SelectNodes('//*[local-name()="Group"]')
            $GroupNode = $GroupNodes[0].Clone()
            $GroupNode.RemoveAll()
            $GroupNode.SetAttribute("Name", $Group)
            $LayoutNode.PrependChild($GroupNode)
        }
        else {
            Write-Verbose "Group Node Exists"
        }
        # find existing Node
        # $DesktopApplicationTileNode = `
        #    $GroupNode.SelectNodes(".//*[substring(@DesktopApplicationLinkPath, string-length(@DesktopApplicationLinkPath)-string-length(""$ShortcutName"") +1)=""$ShortcutName"" ]")
        $DesktopApplicationTileNode = $GroupNode.SelectNodes(".//*") | Where-Object { $_.DesktopApplicationLinkPath.tolower().endswith($ShortcutName.ToLower()) } | Select -First 1
        # create if it doesn't exist
        If (!($DesktopApplicationTileNode) -or $DesktopApplicationTileNode.Count -eq 0) {
            Write-Verbose "Application Node Found"
            $GroupAppNodes = $GroupNode.SelectNodes('.//*')
            $Count = ($GroupAppNodes | Measure-Object | Select-Object -ExpandProperty Count)
            $Row = [Int]([Math]::Floor($Count / $LayoutWidth)) * 2
            $Col = [Int](($Count % $LayoutWidth)) * 2
            $DesktopApplicationTileNodes = $xml.DocumentElement.SelectNodes('//*[local-name()="DesktopApplicationTile"]')
            $DesktopApplicationTileNode = $DesktopApplicationTileNodes[0].Clone()
            $DesktopApplicationTileNode.RemoveAll()
            $DesktopApplicationTileNode.SetAttribute("Size", "2x2")
            $DesktopApplicationTileNode.SetAttribute("Column", "$Col")
            $DesktopApplicationTileNode.SetAttribute("Row", "$Row")
            $DesktopApplicationTileNode.SetAttribute("DesktopApplicationLinkPath", $Shortcut.FullName)
            $GroupNode.AppendChild($DesktopApplicationTileNode)
        }
        else {
            Write-Verbose "Updating existing application Node"
            $DesktopApplicationTileNode.SetAttribute("DesktopApplicationLinkPath", $Shortcut.FullName)
        }
        $xml.Save("$($tmp.FullName).xml")
        Import-StartLayout -LayoutPath "$($tmp.FullName).xml" -MountPath C:\
        #if (!($?)) { notepad "$($tmp.FullName).xml" }
        New-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows -Name Explorer -ErrorAction SilentlyContinue
        Reg Add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /V LockedStartLayout /T REG_DWORD /D 1 /F | Out-Null
        Reg Add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /V StartLayoutFile /T REG_EXPAND_SZ /D "$($tmp.FullName).xml" /F | Out-Null
        $explorerProcess = Stop-Process -ProcessName explorer -force -PassThru
        Wait-Process -Id $explorerProcess.Id -ErrorAction Ignore
        #while ( !(Get-Process -Name explorer -ErrorAction SilentlyContinue) ) {
        #    Write-Host '.' -NoNewline
        #    Start-Sleep -Milliseconds 10
        #}
        # wait for explorer to start
        Start-Sleep -Milliseconds 500
        $i = 0
        while (!(Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
            Write-Progress -Activity 'Restarting Explorer' -PercentComplete -1
            Start-Sleep -Milliseconds 10;
            $i++
            if ($i -gt 50){
                Start-Process 'explorer'
            }
        }
        # wait for explorer to stop processing
        while ((Get-Process -Name explorer).threads | Where-Object { $_.ThreadState -eq 'Running' }) {
            start-sleep -Milliseconds 10;
            Write-Progress -Activity 'Restarting Explorer' -PercentComplete -1
        }
        Write-Progress -Activity 'Restarting Explorer' -Completed

        #while ((Get-Process -Name explorer -ErrorAction SilentlyContinue).StartTime.AddMilliseconds(500) -gt (Get-Date) ){
        #    Write-Host '*' -NoNewline
        #    Start-Sleep -Milliseconds 10
        #}


        #Start-Sleep -s 10

        #sleep is to let explorer finish restart b4 deleting reg keys
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "LockedStartLayout" -Force
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "StartLayoutFile" -Force
        Stop-Process -ProcessName explorer -force
        Remove-Item "$($tmp.FullName).xml" -Force -ErrorAction Ignore
        $i = 0
        while (!(Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
            Write-Host '*' -NoNewline
            Start-Sleep -Milliseconds 10;
            $i++
            if ($i -gt 50){
                Start-Process 'explorer'
            }
        }

    }
}