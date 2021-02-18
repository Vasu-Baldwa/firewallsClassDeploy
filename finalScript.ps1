$vms = Import-CSV "firewallsDC.csv"

$GC = $Host.UI.PromptForCredential("Please enter credentials", "Enter Guest credentials for VM", "Administrator", "")


foreach ($vm in $vms){

    $Template          = $vm.Template
    $Location          = $vm.Location
    $VMName = $vm.Name
    $IP = $vm.IP
    $SNM = $vm.Subnet
    $GW = $vm.Gateway
    $DNS1 = $vm.DNS

    $VMName            = $vm.Name
    $Template          = $vm.Template
    $Location          = $vm.Location
    Write-Host "Generating new VM per spec sheet" -ForegroundColor Yellow
    New-VM -Name $VMName -Template $Template -Location $Location -ResourcePool $(Get-Cluster MAIN) -Datastore $(Get-DatastoreCluster THE-VAULT) -confirm:$False
    #Sets the new VM as a variable to make configuration changes faster
    $NewVM = Get-VM -Name $VMName
    #Powers on the VM
    Write-host "Powering on $VMName" -ForegroundColor Yellow
    Start-VM -VM $VMName -Confirm:$False


    #Updates VM Tools
    Get-VM $VMName | Wait-Tools -HostCredential $GC
    Get-VM $VMName | Update-Tools

    Sleep -Seconds 5
    Get-VM $VMName | Wait-Tools -HostCredential $GC
    Write-Host "VMWare tools are now running on"$VMName -ForegroundColor Green

    $Network = Invoke-VMScriptPlus -SkipCertificateCheck -NoIPinCert -VM $VMName -ScriptType Powershell -ScriptText "(gwmi Win32_NetworkAdapter -filter 'netconnectionid is not null').netconnectionid" -GuestCredential $GC
    $NetworkName = $Network.ScriptOutput
    $NetworkName = $NetworkName.Trim()
    Write-Host "Setting IP address for $VMname..." -ForegroundColor Yellow
    Sleep -Seconds 60
    $netsh = "c:\windows\system32\netsh.exe interface ip set address ""$NetworkName"" static $IP $SNM $GW"
    $netsh2 = "c:\windows\system32\netsh.exe interface ip set dnsservers ""$NetworkName"" static $DNS1"
    Invoke-VMScriptPlus -SkipCertificateCheck -NoIPinCert -VM $VMname -GuestCredential $GC -ScriptType bat -ScriptText $netsh
    Invoke-VMScriptPlus -SkipCertificateCheck -NoIPinCert -VM $VMname -GuestCredential $GC -ScriptType bat -ScriptText $netsh2
    Write-Host "Setting IP address completed." -ForegroundColor Green

}