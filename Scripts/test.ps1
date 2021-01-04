#1. Add site to trusted sites

#Setting IExplorer settings
Write-Verbose "Now configuring IE"

#Navigate to the domains folder in the registry
set-location "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
set-location ZoneMap\Domains

#Create a new folder with the website name
new-item testsite.site.com/ -Force #website part without https
set-location testsite.site.com/
new-itemproperty . -Name https -Value 2 -Type DWORD -Force

Write-Host "Site added Successfully"
Start-Sleep -s 2

# 2. Disable IE protected mode

# Disabling protected mode and making level 0

#Zone 0 – My Computer
#Zone 1 – Local Intranet Zone
#Zone 2 – Trusted sites Zone
#Zone 3 – Internet Zone
#Zone 4 – Restricted Sites Zone

#“2500” is the value name representing “Protected Mode” tick. 3 means Disabled, 0 – Enabled

#Disable protected mode for all zones
Set-ItemProperty -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\1" -Name 2500 -Value "3"
Set-ItemProperty -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\2" -Name 2500 -Value "3"
Set-ItemProperty -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" -Name 2500 -Value "3"
Set-ItemProperty -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\4" -Name 2500 -Value "3"

Write-Host "IE protection mode turned Off successfully"
Start-Sleep -s 2

# 3. Bring down security level for all zones

#Set Level 0 for low
Set-ItemProperty -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\1" -Name 1A10 -Value "0"
Set-ItemProperty -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\2" -Name 1A10 -Value "0"
Set-ItemProperty -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" -Name 1A10 -Value "0"
Set-ItemProperty -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\4" -Name 1A10 -Value "0"

Stop-Process -name explorer

function Disable-InternetExplorerESC {
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
    Stop-Process -Name Explorer
    Write-Host "IE Enhanced Security Configuration (ESC) has been disabled." -ForegroundColor Green
}
function Enable-InternetExplorerESC {
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 1
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 1
    Stop-Process -Name Explorer
    Write-Host "IE Enhanced Security Configuration (ESC) has been enabled." -ForegroundColor Green
}
function Disable-UserAccessControl {
    Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 00000000
    Write-Host "User Access Control (UAC) has been disabled." -ForegroundColor Green
}