function New-Shortcut {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [System.IO.FileInfo]
        [Parameter(Position = 0, Mandatory = $true, ParameterSetName = "Item")]
        [IO.FileInfo] $Target,
        [Parameter(Position = 0, Mandatory = $true, ParameterSetName = "Name")]
        [string] $TargetPath,
        [String]
        $ShortcutName,
        [String]
        $ShortcutFolder,
        [switch]
        $Desktop,
        [switch]
        $AllUsers
    )
    if ($PSCmdlet.ParameterSetName -eq "Item") {
        $TargetPath = Get-ChildItem $Target.FullName
    }
    if (!(Test-Path -Path $TargetPath -PathType Leaf)) {
        throw [System.IO.FileNotFoundException] "$TargetPath not found."
    }
    if ($PSCmdlet.ParameterSetName -eq 'Name') {
        $Target = Get-ChildItem $TargetPath
    }
    if (!($ShortcutName)) {
        $ShortcutName = $Target.BaseName
    }
    if (!($ShortcutName.EndsWith('.lnk'))) { $ShortcutName += '.lnk' }

    if ($AllUsers) {
        if ($Desktop) {
            $ShortcutRoot = [Environment]::GetFolderPath([System.Environment+SpecialFolder]::CommonDesktopDirectory)
        }
        else {
            $ShortcutRoot = [Environment]::GetFolderPath([System.Environment+SpecialFolder]::CommonStartMenu)
        }
    }
    else {
        if ($Desktop) {
            $ShortcutRoot = [Environment]::GetFolderPath([System.Environment+SpecialFolder]::DesktopDirectory)
        }
        else {
            $ShortcutRoot = [Environment]::GetFolderPath([System.Environment+SpecialFolder]::StartMenu)
        }
    }
    $ShortcutRoot = Join-Path $ShortcutRoot 'Programs'
    if ($ShortcutFolder) {
        $ShortcutRoot = Join-Path $ShortcutRoot $ShortcutFolder
        New-Item -Path $ShortcutRoot -ItemType Directory -Force | Out-Null
    }
    $ShortcutLink = Join-Path $ShortcutRoot $ShortcutName

    if ($PSCmdlet.ShouldProcess("$ShortcutLink", "Create")) {
        $WshShell = New-Object -comObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($ShortcutLink)
        $Shortcut.TargetPath = $TargetPath
        $Shortcut.Save()
        return (Get-ChildItem $ShortcutLink)
    }
    return
}