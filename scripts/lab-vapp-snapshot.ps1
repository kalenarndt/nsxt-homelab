#
# Snapshot, Revert, and Remove Script 
# Hard code param values or use - commands 
# 
#

param(
   [string]$vCenter = "your-vcenter",
   [string]$username = "administrator@vsphere.local",
   [string]$password = "VMware1!",
   [switch]$snapshot,
   [switch]$revert,
   [string]$vappname = "Federation",
   [switch]$remove
)

Connect-VIServer -Server $vCenter -User $username -Password $password

if ($snapshot){
   $vAppVMs = Get-VM -Location (Get-vApp $vappname)
   foreach ($vm in $vAppVMs){
      $date = Get-Date -Format "MM-dd-yyyy"
      New-Snapshot -Name "$vm - $date" -Description "Snapshot Script on $date" -VM $vm -RunAsync -Confirm:$false | Out-Null
      Write-Output "Created Snapshot for $vm in $vappname"
   }
}


if ($revert){
   $vAppVMs = Get-VM -Location (Get-vApp $vappname)
   foreach ($vm in $vAppVMs){
      $snap = Get-Snapshot -VM $vm | Sort-Object -Property Created -Descending | Select-Object -First 1
      Set-VM -VM $vm -SnapShot $snap -RunAsync -Confirm:$false | Out-Null
      Write-Output "Reverted Snapshot for $vm in $vappname"
   }
}

if ($remove){
   $vAppVMs = Get-VM -Location (Get-vApp $vappname)
   foreach ($vm in $vAppVMs){
      Remove-Snapshot -Snapshot (Get-Snapshot -VM $vm | Sort-Object -Property Created -Descending | Select-Object -First 1) -RunAsync -Confirm:$false | Out-Null
      Write-Output "Removed Snapshot from $vm in $vappname"
   }
}