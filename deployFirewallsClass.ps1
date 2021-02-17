$vms = Import-CSV "firewallsDC.csv"

#???
$GC = $Host.UI.PromptForCredential("Please enter credentials", "Enter Guest credentials for VM", "Administrator", "")
$credOSC = Get-Credential

Function Build-VM{
    foreach ($vm in $vms){
      
      #Assign Variables
      $VMName            = $vm.Name
      $Template          = Get-Template -Name $vm.Template
      $Cluster           = Get-Cluster MAIN #$vm.Cluster
      $Datastore         = Get-DatastoreCluster THE-VAULT #Get-Datastore -Name $vm.Datastore
      #$Custom            = "PowerCliOnly"
      $vCPU              = $vm.CPU
      $Memory            = $vm.RAM
      $HardDrive         = $vm.HDD
      $Network           = $vm.Network
      $Location          = $vm.Location
      $VMName            = $vm.Name
      $IP                = $vm.IP
      $SNM               = $vm.SubnetMask
      $GW                = $vm.Gateway
      $DNS1              = $vm.DNS

     
      Write-Host "Generating new VM per spec sheet" -ForegroundColor Yellow
      New-VM -Name $VMName -Location $Location -ResourcePool $(Get-Cluster MAIN) -Datastore $(Get-DatastoreCluster THE-VAULT) -NumCpu 2 -MemoryGB 8 -DiskGB 40 -DiskStorageFormat Thin  -Template $Template  -confirm:$False
      #Sets the new VM as a variable to make configuration changes faster
      $NewVM = Get-VM -Name $VMName

      Write-host "Setting Memory and vCPU on $VMName" -ForegroundColor Yellow
      $NewVM | Set-VM -MemoryGB $Memory -NumCpu $vCPU -Confirm:$false
      Write-host "Setting Network Adapter on $VMName" -ForegroundColor Yellow
      $NewVM | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName $Network -Confirm:$false

            
      #HDD
      #$NewVMHddSize = ($NewVM | Get-HardDisk | Where {$_.Name -eq "Hard disk 1"}).CapacityGB
      #IF ($HardDrive -gt $NewVMHddSize){$NewVM | Get-HardDisk | Where {$_.Name -eq "Hard disk 1"} | Set-HardDisk -CapacityGB $HardDrive -Confirm:$false}

      #Powers on the VM
      Write-host "Powering on $VMName" -ForegroundColor Yellow
      Start-VM -VM $VMName -Confirm:$False
      
    }
}

Function Config-VMNetwork{

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
}

Build-VM
Config-VMNetwork
