Set-VMHost -VirtualHardDiskPath C:\VHD -VirtualMachinePath C:\VHD
if ((Get-VMSwitch -Name Pri-TA).SwitchType -eq 'Private') {Remove-VMSwitch -Name Pri-TA -Force}
if ((Get-VMSwitch -Name Pri-NY).SwitchType -eq 'Private') {Remove-VMSwitch -Name Pri-NY -Force}
