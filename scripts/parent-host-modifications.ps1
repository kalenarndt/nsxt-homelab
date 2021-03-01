#
# Configures homelab to disable large pages, salting, and allows hyperthreading between vms
# 
#

param(
   [string]$vCenter = "vc.bmrf.io",
   [string]$username = "administrator@vsphere.local",
   [string]$password = "VMware123!"
)

Connect-VIServer -Server $vCenter -User $username -Password $password
# we should specify either -s or -o


$esxHosts = Get-VMHost | Sort Name
foreach($esx in $esxHosts){
      Write-Host "Disabling PageShare Salting on $esx"
      Get-AdvancedSetting -Entity $esx -Name Mem.ShareForceSalting | Set-AdvancedSetting -Value 0 -Confirm:$false | Out-Null
      Write-Host "Disabling Large Pages on $esx"
      Get-AdvancedSetting -Entity $esx -Name Mem.AllocGuestLargePage | Set-AdvancedSetting -Value 0 -Confirm:$false | Out-Null
      Write-Host "Enabling IntraVM Hyperthreading on $esx"
      Get-AdvancedSetting -Entity $esx -Name VMkernel.Boot.hyperthreadingMitigationIntraVM | Set-AdvancedSetting -Value false -Confirm:$false | Out-Null   
   }
