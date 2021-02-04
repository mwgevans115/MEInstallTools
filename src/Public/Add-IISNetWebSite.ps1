Function Add-IISNetWebSite {
    <#
    .SYNOPSIS
        Returns the parameters defined for a calling script


    .NOTES
        Name: Get-ScriptParameter
        Author: Mark Evans <mark@madspaniels.co.uk>
        Version: 1.0
        DateCreated: 2020-Dec-10


    .EXAMPLE
        Get-ScriptParameter


    .LINK

    #>

    [CmdletBinding()]
    param(
        # Site Path
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [string[]]  $SitePath,
        [switch] $UseHTTPS,
        [string] $DNSName
    )

    BEGIN {
        Write-Debug "BEGIN: $($MyInvocation.MyCommand.Name)"
        Try {
            Import-Module WebAdministration -ErrorAction Stop
        }
        Catch {
            Write-Error -Message "Unable to load required module."
            Throw
        }
    }

    PROCESS {
        Write-Debug "PROCESS: $($MyInvocation.MyCommand.Name)"
        foreach ($sSitePath in $SitePath) {
            if (!(Test-Path $sSitePath)) { New-Item -Path $sSitePath -Force -ItemType Directory | Out-Null }
            $iisSite = Get-ChildItem 'IIS:\Sites' | Where-Object { $_.PhysicalPath -eq $sSitePath } | Select -First 1
            if (!$iisSite) {
                $sSiteName = Split-Path $sSitePath -Leaf
                $i = 0
                $sSite = $sSiteName
                while (Test-Path "IIS:\\Sites\$sSite") {
                    $i++
                    $sSite = "$sSiteName{0:D2}" -f ($i)
                }
                $sAppPoolName = "$($sSite)AppPool"
                # Create Pool
                if (!(test-path -Path IIS:\AppPools\$sAppPoolName)) {
                    Write-Log -Level WARNING -Message "`t{0} App Pool {1}" -Arguments 'CREATING', $sAppPoolName
                    $newAppPool = New-WebAppPool -Name "$sAppPoolName"
                    $newAppPool.autoStart = $true
                    $newAppPool.managedRuntimeVersion = 'v4.0'
                    $newAppPool | Set-Item
                }
                # Create Web Site
                $Port = Compare-Object (5000..6000) (Get-ListeningTCPConnections | Select -ExpandProperty ListeningPort -Unique) | Where-object { $_.SideIndicator -eq '<=' } | Get-Random | Select -ExpandProperty InputObject -First 1
                if (!(Test-Path -Path IIS:\Sites\$sSite)) {
                    Write-Log -Level WARNING -Message "`t{0} Web Site {1}" -Arguments 'CREATING', $sSite
                    New-WebSite -Name $sSite -Port $Port -HostHeader 'localhost' -PhysicalPath $sSitePath | Out-Null
                    Set-ItemProperty IIS:\Sites\$sSiteName -name applicationPool -value $sAppPoolName
                    If ($DNSName -and $DNSName -ne 'localhost') {
                        New-WebBinding -Name $sSite -Port 80 -HostHeader $DNSName
                        if ($UseHTTPS) {
                            $cert = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.Subject -eq "CN=$DNSName" }
                            if (!($cert)) {
                                $cert = New-SelfSignedCertificate -DnsName "$DNSName" -CertStoreLocation "cert:\LocalMachine\My"
                            }
                            $DestStore = new-object System.Security.Cryptography.X509Certificates.X509Store([System.Security.Cryptography.X509Certificates.StoreName]::Root, "localmachine")
                            $DestStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
                            $DestStore.Add($cert)
                            $DestStore.Close()
                            Add-ToHostsFile -DesiredIP '127.0.0.1' -HostName $DNSName
                            New-WebBinding -Name $sSite -Protocol "https" -Port 443 -IPAddress * -HostHeader $DNSName -SslFlags 1
                            (Get-WebBinding -Name $sSite -Port 443 -Protocol "https" -HostHeader $DNSName).AddSslCertificate($cert.Thumbprint, "my")
                        }
                    }
                }
                $iisSite = Get-ChildItem 'IIS:\Sites' | Where-Object { $_.PhysicalPath -eq $sSitePath } | Select -First 1
            }
            $Pool = "IIS:\AppPools\" + (Get-ItemProperty "IIS:\Sites\$($iissite.name)"  -name applicationPool )
            $ServiceAccount = (New-Object System.Security.Principal.SecurityIdentifier (
                    Get-Item $Pool | select -ExpandProperty applicationPoolSid
                )).Translate([System.Security.Principal.NTAccount])
            $Acl = Get-Acl $sSitePath
            $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("$ServiceAccount", "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")
            $Acl.SetAccessRule($Ar)
            Get-ChildItem $sSitePath -Recurse | Set-Acl -AclObject $Acl
            Set-Acl $sSitePath $Acl
            $uriArray = @()
            $Bindings = Get-WebBinding $iisSite.Name
            foreach ($binding in $Bindings) {
                $protocol = $binding.protocol
                $bindingInfo = $binding.bindingInformation.Split(':')
                if ($bindingInfo[2]) { $dns = $bindingInfo[2] }else { $dns = 'any' }
                if ($bindingInfo[1] -eq 80) { $port = '' } else { $port = ":$($bindingInfo[1])" }
                $uriArray += [uri]"$protocol`://$dns$port/"
            }
            [PSCustomObject]@{
                Name = $iisSite.Name
                Pool = $Pool
                Path = $iisSite.physicalPath
                Uri  = $uriArray
            }
        }
    }

    END {
        Write-Debug "END: $($MyInvocation.MyCommand.Name)"
    }
}


