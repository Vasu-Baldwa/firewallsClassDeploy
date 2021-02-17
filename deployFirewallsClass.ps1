$vms = Import-CSV "firewallsDC.csv"

#???
$GC = $Host.UI.PromptForCredential("Please enter credentials", "Enter Guest credentials for VM", "Administrator", "")
 
foreach ($vm in $vms){
    #Assign Vars
    $VMName = $vm.Name
    $IP = $vm.IP
    $SNM = $vm.SubnetMask
    $GW = $vm.Gateway
    $DNS1 = $vm.DNS
    $Network = $vm.Network
    $Template = $vm.Template
    
    #Wait for install?
    DO {
        (Get-VMGuest $VMName).HostName
    }
    while ( ((Get-VMGuest $VMName).HostName) -Ne "$VMName")
    
    Get-VM $VMName | Update-Tools

    #Make sure VMTools is running
    $VMTool = Get-VM $VMName | Out-Null
    $VMTool | Select -ExpandProperty ExtensionData | Select -ExpandProperty guest
    $VMToolStatus = $VMTool.ToolsRunningStatus
    Write-host "Checking that VMWare Tools are running on"$VMName -ForegroundColor Yellow
    Sleep -Seconds 5
    Do {
        Write-host "Still checking for VMWare Tools on"$VMName -ForegroundColor Yellow; sleep -Seconds 5
    }
    While ($VMToolStatus -eq "guestToolsRunning")
    Write-Host "VMWare tools are now running on"$VMName -ForegroundColor Green
    
    #Configure IP
    $Network = Invoke-VMScript -VM $VMName -ScriptType Powershell -ScriptText "(gwmi Win32_NetworkAdapter -filter 'netconnectionid is not null').netconnectionid" -GuestUser administrator -GuestPassword password
    $NetworkName = $Network.ScriptOutput
    $NetworkName = $NetworkName.Trim()
    Write-Host "Setting IP address for $VMname..." -ForegroundColor Yellow
    Sleep -Seconds 60
    $netsh = "c:\windows\system32\netsh.exe interface ip set address ""$NetworkName"" static $IP $SNM $GW"
    $netsh2 = "c:\windows\system32\netsh.exe interface ip set dnsservers ""$NetworkName"" static $DNS1"
    Write-Host "Setting IP address completed." -ForegroundColor Green
}
