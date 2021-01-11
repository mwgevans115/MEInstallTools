<#
.Synopsis
    Schedules a file to be moved on reboot.
.DESCRIPTION
    Schedules a file to be moved on reboot. This cmdlet can move a file on reboot and optionally
    replace an existing file.
.EXAMPLE
   Move-FileOnReboot -Path "C:\Windows\System32\kernel32.dll" -Destination "C:\Windows\SysWow64\kernel32.dll" -ReplaceExisting
#>
function Move-FileOnReboot {
    [CmdletBinding()]
    param(
        # The source file to move.
        [Parameter(Mandatory = $true)]
        [IO.FileInfo]$Path,
        # The destination to move the file to.
        [Parameter(Mandatory = $true)]
        [IO.FileInfo]$Destination,
        # Specifies whether to replace an existing file.
        [Parameter()]
        [Switch]$ReplaceExisting
    )
    enum MoveFileFlags {
        MOVEFILE_REPLACE_EXISTING = 0x00000001
        MOVEFILE_COPY_ALLOWED = 0x00000002
        MOVEFILE_DELAY_UNTIL_REBOOT = 0x00000004
        MOVEFILE_WRITE_THROUGH = 0x00000008
        MOVEFILE_CREATE_HARDLINK = 0x00000010
        MOVEFILE_FAIL_IF_NOT_TRACKABLE = 0x00000020
    }
    $memberDefinition = @'
[DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Auto)]
public static extern bool MoveFileEx(string lpExistingFileName, string lpNewFileName,
int dwFlags);
'@

    $type = Add-Type -Name MoveFileUtils -MemberDefinition $memberDefinition -PassThru

    $Flags = [MoveFileFlags]::MOVEFILE_DELAY_UNTIL_REBOOT

    if ($ReplaceExisting) {
        $flags = $flags -bor [PoshInternals.MoveFileFlags]::MOVEFILE_REPLACE_EXISTING
    }

    if ($type::MoveFileEx($Path, $Destination, $flags) -eq 0) {
        throw New-Object System.Win32Exception
    }
}


<#
.Synopsis
    Schedules a file to be deleted on reboot.
.DESCRIPTION
    Schedules a file to be deleted on reboot.
.EXAMPLE
   Remove-FileOnReboot -Path "C:\Windows\System32\kernel32.dll"
#>
function Remove-FileOnReboot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [IO.FileInfo]$Path
    )
    enum MoveFileFlags {
        MOVEFILE_REPLACE_EXISTING = 0x00000001
        MOVEFILE_COPY_ALLOWED = 0x00000002
        MOVEFILE_DELAY_UNTIL_REBOOT = 0x00000004
        MOVEFILE_WRITE_THROUGH = 0x00000008
        MOVEFILE_CREATE_HARDLINK = 0x00000010
        MOVEFILE_FAIL_IF_NOT_TRACKABLE = 0x00000020
    }
    $memberDefinition = @'
[DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Auto)]
public static extern bool MoveFileEx(string lpExistingFileName, string lpNewFileName,
int dwFlags);
public static bool MoveFileEx(string sourcefile, int dwFlags)
{
    bool brc = false;
    brc = MoveFileEx(sourcefile, null, dwFlags);
    return brc;
}
'@

    $type = Add-Type -Name MoveFileUtils -MemberDefinition $memberDefinition -PassThru

    $Flags = [MoveFileFlags]::MOVEFILE_DELAY_UNTIL_REBOOT

    if ($type::MoveFileEx($Path, $Flags) -eq 0) {
        $LastError = [ComponentModel.Win32Exception][Runtime.InteropServices.Marshal]::GetLastWin32Error()
        Write-Output $lasterror
    }
}
