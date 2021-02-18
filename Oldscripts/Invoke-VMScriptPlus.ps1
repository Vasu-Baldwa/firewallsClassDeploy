class MyOBN:System.Management.Automation.ArgumentTransformationAttribute
{
[ValidateSet(
'Cluster', 'Datacenter', 'Datastore', 'DatastoreCluster', 'Folder',
'VirtualMachine', 'VirtualSwitch', 'VMHost', 'VIServer'
)]
[String]$Type
MyOBN([string]$Type)
{
$this.Type = $Type
}
[object] Transform([System.Management.Automation.EngineIntrinsics]$engineIntrinsics, [object]$inputData)
{
if ($inputData -is [string])
{
if (-NOT [string]::IsNullOrWhiteSpace( $inputData ))
{
$cmdParam = "-$(if($this.Type -eq 'VIServer'){'Server'}else{'Name'}) $($inputData)"
$sCmd = @{
Command = "Get-$($this.Type.Replace('VirtualMachine','VM')) $($cmdParam)"
}
return (Invoke-Expression @sCmd)
}
}
elseif ($inputData.GetType().Name -match "$($this.Type)Impl")
{
return $inputData
}
elseif ($inputData.GetType().Name -eq 'Object[]')
{
return ($inputData | ForEach-Object {
if ($_ -is [String])
{
return (Invoke-Expression -Command "Get-$($this.Type.Replace('VirtualMachine','VM')) -Name `$_")
}
elseif ($_.GetType().Name -match "$($this.Type)Impl")
{
$_
}
})
}
throw [System.IO.FileNotFoundException]::New()
}
}
function Invoke-VMScriptPlus
{
<#
.SYNOPSIS
Runs a script in a Linux guest OS.
The script can use the SheBang to indicate which interpreter to use.
.DESCRIPTION
This function will launch a script in a Linux guest OS.
The script supports the SheBang line for a limited set of interpreters.
.NOTES
Author:  Luc Dekens
Version:
1.0 14/09/17  Initial release
1.1 14/10/17  Support bash here-document
2.0 01/08/18  Support Windows guest OS, bat & powershell
2.1 03/08/18  PowerShell she-bang for Linux
2.2 17/08/18  Added ScriptEnvironment
2.3 11/03/19  Resolve IP to FQDN to support certificate for ESXi node
2.4 22/04/19  Switch to provide password inline to 'sudo' lines
2.5 07/06/19  Switch WaitForToolsVersionChange to wait for a version change
3.0 17/11/19  Added powershellv7 support, added InFile & OutFile
3.1 18/11/19  Added switch NoIPinCert
3.2 15/04/20  Added switch SkipCertificateCheck
.PARAMETER VM
Specifies the virtual machines on whose guest operating systems
you want to run the script.
.PARAMETER GuestUser
Specifies the user name you want to use for authenticating with the
virtual machine guest OS.
.PARAMETER GuestPassword
Specifies the password you want to use for authenticating with the
virtual machine guest OS.
.PARAMETER GuestCredential
Specifies a PSCredential object containing the credentials you want
to use for authenticating with the virtual machine guest OS.
.PARAMETER ScriptText
Provides the text of the script you want to run. You can also pass
to this parameter a string variable containing the path to the script.
Note that the function will add a SheBang line, based on the ScriptType,
if none is provided in the script text.
.PARAMETER ScriptType
The supported Linux interpreters.
Currently these are bash,perl,python3,nodejs,php,lua,powershell,powershellv6,powershellv7
.PARAMETER ScriptEnvironment
A string array with environment variables.
These environment variables are available to the script from ScriptText
.PARAMETER GuestOSType
Indicates which type of guest OS the VM is using.
The parameter accepts Windows or Linux. This parameter is a fallback for
when the function cannot determine which OS Family the Guest OS
belongs to
.PARAMETER CRLF
Switch to indicate of the NL that is returned by Linux, shall be
converted to a CRLF
.PARAMETER Sudo
Switch to convert all 'sudo' lines to an inline password 'sudo' line.
Only taken into account when the GuestOSType is 'Linux'
.PARAMETER KeepFiles
Switch to indicate that the temporary files, the script and the output files,
shall not be deleted.
Only to be used for debugging purposes.
.PARAMETER InFile
One or more files that will be copied to the guest OS.
These files will be copied to the directory from where the script will run
and can be used from within the script.
.PARAMETER InFile
One or more files that will be copied from the guest OS after the script has ran.
These files will be copied from the directory from where the script runs.
.PARAMETER Server
Specifies the vCenter Server systems on which you want to run the
cmdlet. If no value is passed to this parameter, the command runs
on the default servers. For more information about default servers,
see the description of Connect-VIServer.
.PARAMETER WaitForToolsVersionChange
When the invoked code changes the version of the VMware Tools, this switch
tells the function to wait till this version change is visible in the script
.PARAMETER NoIPinCert
When certificates are used that do not contain the IP address of the ESXi node
as a Subject Alternative Name (SAN), this switch tells the function to convert
the IP address in all URI used for file transfers, to a FQDN.
.PARAMETER NoIPinCert
When certificates are used that do not contain the IP address of the ESXi node
as a Subject Alternative Name (SAN), this switch tells the function to convert
the IP address in all URI used for file transfers, to a FQDN.
.PARAMETER SkipCertificateCheck
When a non-trusted certificate is used on the ESXi node that hosts the targetted
VM, the transfer of files to and from the VM's Guest OS will fail.
This switch tells the function to ignore invalid certificates on the ESXi node.
.EXAMPLE
$pScript = @'
#!/usr/bin/env perl
use strict;
use warnings;
print "Hello world\n";
'@
$sCode = @{
VM = $VM
GuestCredential = $cred
ScriptType = 'perl'
ScriptText = $pScript
}
Invoke-VMScriptPlus @sCode
.EXAMPLE
$pScript = @'
print("Happy 10th Birthday PowerCLI!")
'@
$sCode = @{
VM = $VM
GuestCredential = $cred
ScriptType = 'python3'
ScriptText = $pScript
}
Invoke-VMScriptPlus @sCode
.EXAMPLE
$pScript = @'
Get-Content -Path .\MyInput.txt | Set-Content -Path .\MyOutput.txt
'@
$sCode = @{
VM = $VM
GuestCredential = $cred
ScriptType = 'powershellv7'
ScriptText = $pScript
InFile = 'C:\Test\MyInput.txt'
OutFile = 'C:\Report\MyOutput.txt'
}
Invoke-VMScriptPlus @sCode
#>
[cmdletbinding()]
param(
[parameter(Mandatory = $true, ValueFromPipeline = $true)]
[MyOBN('VirtualMachine')]
[VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine[]]$VM,
[Parameter(Mandatory = $true, ParameterSetName = 'TextScript')]
[Parameter(Mandatory = $true, ParameterSetName = 'TextExe')]
[String]$GuestUser,
[Parameter(Mandatory = $true, ParameterSetName = 'TextScript')]
[Parameter(Mandatory = $true, ParameterSetName = 'TextExe')]
[SecureString]$GuestPassword,
[Parameter(Mandatory = $true, ParameterSetName = 'CredScript')]
[Parameter(Mandatory = $true, ParameterSetName = 'CredExe')]
[PSCredential[]]$GuestCredential,
[Parameter(Mandatory = $true, ParameterSetName = 'TextScript')]
[Parameter(Mandatory = $true, ParameterSetName = 'CredScript')]
[String]$ScriptText,
[Parameter(Mandatory = $true, ParameterSetName = 'TextScript')]
[Parameter(Mandatory = $true, ParameterSetName = 'CredScript')]
[ValidateSet('bash', 'perl', 'python3', 'nodejs', 'php', 'lua', 'powershell',
'powershellv6', 'powershellv7', 'bat', 'exe')]
[String]$ScriptType,
[Parameter(Mandatory = $true, ParameterSetName = 'TextExe')]
[Parameter(Mandatory = $true, ParameterSetName = 'CredExe')]
[string]$ExeName,
[String[]]$ScriptEnvironment,
[ValidateSet('Windows', 'Linux')]
[String]$GuestOSType,
[Switch]$CRLF,
[Switch]$Sudo,
[Switch]$KeepFiles,
[MyOBN('VIServer')]
[VMware.VimAutomation.ViCore.Types.V1.VIServer]$Server = $global:DefaultVIServer,
[Switch]$WaitForToolsVersionChange,
[String[]]$InFile,
[String[]]$OutFile,
[Switch]$NoIPinCert,
[Switch]$SkipCertificateCheck
)
Begin
{
#region Helper functions
function Send-GuestFile
{
[cmdletbinding()]
param(
[Parameter(Mandatory = $true)]
[String]$File,
[Parameter(Mandatory = $true, ParameterSetName = 'File')]
[String]$Source,
[Parameter(Mandatory = $true, ParameterSetName = 'Data')]
[String]$Data
)
if ($PSCmdlet.ParameterSetName -eq 'File')
{
$Data = Get-Content -Path $Source -Raw
}
$attr = New-Object VMware.Vim.GuestFileAttributes
$clobber = $true
$fileInfo = $gFileMgr.InitiateFileTransferToGuest($moref, $auth, $File, $attr, $Data.Length, $clobber)
if($Server.ProductLine -eq 'embeddedEsx'){
$fileInfo = $fileInfo.Replace('*',([System.Uri]$server.ServiceUri).Host)
}
if ($NoIPinCert.IsPresent)
{
$ip = $fileInfo.split('/')[2].Split(':')[0]
$hostName = Resolve-DnsName -Name $ip | Select-Object -ExpandProperty NameHost
$fileInfo = $fileInfo.replace($ip, $hostName)
}
$sWeb = @{
Uri = $fileInfo
Method = 'Put'
Body = $Data
}
if($SkipCertificateCheck.IsPresent){
if($PSVersionTable.PSVersion.Major -lt 6){
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}
else{
$sWeb.Add('SkipCertificateCheck',$true)   
}
}
Write-Verbose -Message "Copying $($PSCmdlet.ParameterSetName) to $File"
$copyResult = Invoke-WebRequest @sWeb
if ($copyResult.StatusCode -ne 200)
{
Throw "ScripText copy failed!`rStatus $($copyResult.StatusCode)`r$(($copyResult.Content | ForEach-Object{[char]$_}) -join '')"
}
}
function Receive-GuestFile
{
[cmdletbinding()]
param(
[String]$Source,
[String]$File
)
$fileInfo = $gFileMgr.InitiateFileTransferFromGuest($moref, $auth, $Source)
if($Server.ProductLine -eq 'embeddedEsx'){
$fileInfo.Url = $fileInfo.Url.Replace('*',([System.Uri]$server.ServiceUri).Host)
}
if ($NoIPinCert.IsPresent)
{
$ip = $fileInfo.Url.split('/')[2].Split(':')[0]
$hostName = Resolve-DnsName -Name $ip | Select-Object -ExpandProperty NameHost
$fileInfo.Url = $fileInfo.Url.replace($ip, $hostName)
}
$sWeb = @{
Uri = $fileInfo.Url
Method = 'Get'
}
if($SkipCertificateCheck.IsPresent){
if($PSVersionTable.PSVersion.Major -lt 6){
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}
else{
$sWeb.Add('SkipCertificateCheck',$true)   
}
}
$fileContent = Invoke-WebRequest @sWeb
if ($fileContent.StatusCode -ne 200)
{
Throw "Retrieve of script output failed!`rStatus $($fileContent.Status)`r$(($fileContent.Content | ForEach-Object{[char]$_}) -join '')"
}
if ($File)
{
$fileContent.Content | Set-Content -Path $File -Encoding byte -Confirm:$false
}
else
{
$fileContent.Content
}
}
#endregion
#region Set up guest operations
$si = Get-View ServiceInstance
$guestMgr = Get-View -Id $si.Content.GuestOperationsManager
$gFileMgr = Get-View -Id $guestMgr.FileManager
$gProcMgr = Get-View -Id $guestMgr.ProcessManager
#endregion
#region Set up shebang table
$shebangTab = @{
'bash' = '#!/usr/bin/env bash'
'perl' = '#!/usr/bin/env perl'
'python3' = '#!/usr/bin/env python3'
'nodejs' = '#!/usr/bin/env nodejs'
'php' = '#!/usr/bin/env php'
'lua' = '#!/usr/bin/env lua'
'powershellv6' = '#!/usr/bin/env pwsh'
'powershellv7' = '#!/usr/bin/env pwsh-preview'
}
#endregion
#region Handle SkipCertificateCheck (if used)
if($SkipCertificateCheck.IsPresent -and 
$PSVersionTable.PSVersion.Major -lt 6 -and
-not ([System.Management.Automation.PSTypeName]'TrustAllCertsPolicy')){
Add-Type @'
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
public bool CheckValidationResult(
ServicePoint srvPoint, X509Certificate certificate,
WebRequest request, int certificateProblem) {
return true;
}
}
'@
}
#endregion
}
Process
{
foreach ($vmInstance in $VM)
{
#region Test conditions for running script in guest OS
if ($vmInstance.PowerState -ne 'PoweredOn')
{
Write-Error "VM $($vmInstance.Name) is not powered on"
continue
}
$vmInstance.ExtensionData.UpdateViewData('Guest')
if ($vmInstance.ExtensionData.Guest.ToolsRunningStatus -ne 'guestToolsRunning')
{
Write-Error "VMware Tools are not running on VM $($vmInstance.Name)"
continue
}
if (-not $vmInstance.ExtensionData.Guest.GuestOperationsReady)
{
Write-Error "VM $($vmInstance.Name) is not ready to use Guest Operations"
continue
}
$moref = $vmInstance.ExtensionData.MoRef
#endregion
#region Create Authentication Object (User + Password)
if ('CredScript', 'CredExe' -contains $PSCmdlet.ParameterSetName)
{
$GuestUser = $GuestCredential.GetNetworkCredential().username
$plainGuestPassword = $GuestCredential.GetNetworkCredential().password
}
if ('TextScript', 'TextExe' -contains $PSCmdlet.ParameterSetName)
{
$bStr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($GuestPassword)
$plainGuestPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bStr)
}
$auth = New-Object VMware.Vim.NamePasswordAuthentication
$auth.InteractiveSession = $false
$auth.Username = $GuestUser
$auth.Password = $plainGuestPassword
#endregion
#region Determine GuestOSType
if (-not $GuestOSType)
{
Write-Verbose "No GuestOSType value provided. Trying to determine now."
switch -Regex ($vmInstance.Guest.OSFullName)
{
'Windows'
{
Write-Verbose "It's a Windows guest OS"
$GuestOSType = 'Windows'
if (-not $ExeName -and 'bat', 'powershell', 'powershellv6', 'powershellv7' -notcontains $ScriptType)
{
Write-Verbose "Invalid scripttype provided"
Write-Error "For a Windows guest OS the ScriptType can be Bat, PowerShell, PowerShellv6 or PowerShellv7"
continue
}
}
'Linux'
{
Write-Verbose "It's a Linux guest OS"
$GuestOSType = 'Linux'
if (-not $ExeName -and 'bat', 'powershell' -contains $ScriptType)
{
Write-Verbose "Invalid scripttype provided"
Write-Error "For a Linux guest OS the ScriptType cannot be Bat"
continue
}
}
Default
{
Write-Verbose "Can't determine guest OS type."
Write-Error "Unable to determine the guest OS type on VM $($vmInstance.Name)"
Write-Error "Try using the GuestOSType parameter."
continue
}
}
}
if ($GuestOSType -eq 'Linux')
{
Write-Verbose "Seems to be a Linux guest OS"
# Test if code contains a SheBang, otherwise add it
$targetCode = $shebangTab[$ScriptType]
if ($ScriptText -notmatch "^$($targetCode)")
{
Write-Verbose "Add SheBang $targetCode"
$ScriptText = "$($targetCode)`n`r$($ScriptText)"
}
# Take care of the 'sudo' switch
if ($Sudo)
{
Write-Verbose "Setting up sudo usage"
$ScriptText = ($ScriptText | ForEach-Object -Process {
$_ -replace 'sudo', "echo $plainGuestPassword | sudo -S"
})
}
}
#endregion
#region Create a temp directory
$tempFolder = $gFileMgr.CreateTemporaryDirectoryInGuest($moref, $auth, "$($env:USERNAME)_$($PID)", $null, $null)
Write-Verbose "Created temp folder in guest OS $tempFolder"
#endregion
#region Create temp file for script
$suffix = ''
if ('bat', 'exe' -contains $ScriptType)
{
$suffix = ".cmd"
}
if ('powershell', 'powershellv6', 'powershellv7' -contains $ScriptType)
{
$suffix = ".ps1"
}
Try
{
$tempFile = $gFileMgr.CreateTemporaryFileInGuest($moref, $auth, "$($env:USERNAME)_$($PID)", $suffix, $tempFolder)
Write-Verbose "Created temp script file in guest OS $tempFile"
}
Catch
{
Write-Verbose "Encountered a problem creating the script file in the guest OS"
Throw "$error[0].Exception.Message"
}
#endregion
#region Create temp file for output
Try
{
$tempOutput = $gFileMgr.CreateTemporaryFileInGuest($moref, $auth, "$($env:USERNAME)_$($PID)_output", $null, $tempFolder)
Write-Verbose "Created temp output file in guest OS $tempOutput"
}
Catch
{
Write-Verbose "Encountered a problem creating the output file in the guest OS"
Throw "$error[0].Exception.Message"
}
#endregion
#region Copy script to temp file
if ($ExeName)
{
Send-GuestFile -Data $ExeName -File $tempFile
Write-Verbose "Copied ExeName to temp script file"
}
else
{
if ($GuestOSType -eq 'Linux')
{
$ScriptText = $ScriptText.Split("`r") -join ''
}
Send-GuestFile -Data $ScriptText -File $tempFile
Write-Verbose "Copied scripttext to temp script file"
}
#endregion
#region Get current environment variables
$SystemEnvironment = $gProcMgr.ReadEnvironmentVariableInGuest($moref, $auth, $null)
#endregion
#region Copy InFiles to to guest OS
if ($InFile)
{
$InFile | ForEach-Object -Process {
$destinationFilePath = "$tempFolder/$(Split-Path -Path $_ -Leaf)"
Write-Verbose "Upload InFile $_"
Send-GuestFile -Source $_ -File $destinationFilePath
}
}
#endregion
#region Run script
if ($WaitForToolsVersionChange)
{
$toolsVersion = $vmInstance.ExtensionData.Guest.ToolsVersion
}
switch ($GuestOSType)
{
'Linux'
{
# Make temp file executable
$spec = New-Object VMware.Vim.GuestProgramSpec
$spec.Arguments = "751 $tempFile"
$spec.ProgramPath = '/bin/chmod'
Try
{
$procId = $gProcMgr.StartProgramInGuest($moref, $auth, $spec)
Write-Verbose "Make script file executable"
}
Catch
{
Write-Verbose "Encountered a problem making the script file executable in the guest OS"
Throw "$error[0].Exception.Message"
}
# Run temp file
$spec = New-Object VMware.Vim.GuestProgramSpec
if ($ScriptEnvironment)
{
$spec.EnvVariables = $SystemEnvironment + $ScriptEnvironment
}
$spec.Arguments = " > $($tempOutput) 2>&1"
$spec.ProgramPath = "$($tempFile)"
$spec.WorkingDirectory = $tempFolder
Try
{
$procId = $gProcMgr.StartProgramInGuest($moref, $auth, $spec)
Write-Verbose "Run script with '$($tempFile) > $($tempOutput)'"
}
Catch
{
Write-Verbose "Encountered a problem running the script file in the guest OS"
Throw "$error[0].Exception.Message"
}
}
'Windows'
{
# Run temp file
$spec = New-Object VMware.Vim.GuestProgramSpec
$spec.WorkingDirectory = $tempFolder
if ($ScriptEnvironment)
{
$spec.EnvVariables = $SystemEnvironment + $ScriptEnvironment
}
if ($ExeName)
{
$spec.ProgramPath = "cmd.exe"
$spec.Arguments = " /s /c start """" ""$ExeName"""
}
else
{
switch ($ScriptType)
{
'PowerShell'
{
$spec.Arguments = " /C powershell -NonInteractive -File $($tempFile) > $($tempOutput)"
$spec.ProgramPath = "cmd.exe"
}
{ 'PowerShellv6', 'PowerShellv7' -contains $_ }
{
$psCmd = 'pwsh.exe'
if ($ScriptType -eq 'PowerShellv7')
{
$psCmd = 'pwsh-preview.exe'
}
$spec.Arguments = " /C ""$psCmd"" -NonInteractive -File $($tempFile) > $($tempOutput)"
$spec.ProgramPath = "cmd.exe"
}
'Bat'
{
$spec.Arguments = " /s /c cmd > $($tempOutput) 2>&1 /s /c $($tempFile)"
$spec.ProgramPath = "cmd.exe"
}
}
}
Try
{
$procId = $gProcMgr.StartProgramInGuest($moref, $auth, $spec)
Write-Verbose "Run script with '$($spec.ProgramPath) $($spec.Arguments)'"
}
Catch
{
Write-Verbose "Encountered a problem running the script file in the guest OS"
Throw "$error[0].Exception.Message"
}
}
}
if ($WaitForToolsVersionChange)
{
Write-Verbose "Waiting for VMware Tools version to change"
while ($toolsVersion -eq $vmInstance.ExtensionData.Guest.ToolsVersion)
{
Start-Sleep -Seconds 1
$vmInstance.ExtensionData.UpdateViewData('Guest')
}
Write-Verbose "VMware Tools version changed from $toolsVersion to $($vmInstance.ExtensionData.Guest.ToolsVersion)"
}
#endregion
#region Wait for script to finish
Try
{
$pInfo = $gProcMgr.ListProcessesInGuest($moref, $auth, @($procId))
Write-Verbose "Wait for process to end"
while ($pInfo -and $null -eq $pInfo.EndTime)
{
Start-Sleep 1
$pInfo = $gProcMgr.ListProcessesInGuest($moref, $auth, @($procId))
}
}
Catch
{
Write-Verbose "Encountered a problem waiting for the script to end in the guest OS"
Throw "$error[0].Exception.Message"
}
#endregion
#region Retrieve output from script
Write-Verbose "Get output from $tempOutput"
$scriptOutput = Receive-GuestFile -Source $tempOutput
#endregion
#region Copy OutFiles from guest OS
if ($OutFile)
{
$OutFile | ForEach-Object -Process {
$sourceFilePath = "$tempFolder/$_"
Write-Verbose "Download OutFile $_"
Receive-GuestFile -Source $sourceFilePath -File $_
}
}
#endregion
#region Clean up
# Remove temporary folder
if (-not $KeepFiles)
{
$gFileMgr.DeleteDirectoryInGuest($moref, $auth, $tempFolder, $true)
Write-Verbose "Removed folder $tempFolder"
}
#endregion
#region Package result in object
New-Object PSObject -Property @{
VM = $vmInstance
ScriptOutput = & {
$out = ($scriptOutput | ForEach-Object { [char]$_ }) -join ''
if ($CRLF)
{
$out.Replace("`n", "`n`r")
}
else
{
$out
}
}
Pid = $procId
PidOwner = $pInfo.Owner
Start = $pInfo.StartTime
Finish = $pInfo.EndTime
ExitCode = $pInfo.ExitCode
ScriptType = $ScriptType
ScriptSize = $ScriptText.Length
ScriptText = $ScriptText
OutFiles = $OutFile
GuestOS = $GuestOSType
}
#endregion
}
}
}