#הקמת המעבדה 
# שלב ראשון יצירת  סוויצ'ים וירטואליים
New-VMSwitch -name Pri-TA -SwitchType Private
New-VMSwitch -name Pri-NY -SwitchType Private
#שלב יצירת הדיסקים 
New-VHD -ParentPath C:\BASE\BASE19.vhdx -Path 'C:\VHD\DC1.vhdx' -Differencing -SizeBytes 50GB
New-VHD -ParentPath C:\BASE\BASE19.vhdx -Path 'C:\VHD\NYDC.vhdx' -Differencing -SizeBytes 50GB
New-VHD -ParentPath C:\BASE\BASE19CORE.vhdx -Path 'C:\VHD\RTR.vhdx' -Differencing -SizeBytes 50GB
New-VHD -ParentPath C:\BASE\BASEW10.vhdx -Path 'C:\VHD\W10CL1.vhdx' -Differencing -SizeBytes 50GB
New-VHD -ParentPath C:\BASE\BASEW10.vhdx -Path 'C:\VHD\W10CL2.vhdx' -Differencing -SizeBytes 50GB
#שלב חיבור הדיסקים למכונות 
New-VM -Name "DC1" -MemoryStartupBytes 2GB -VHDPath 'C:\VHD\DC1.vhdx' -SwitchName "Pri-TA" -Generation 2
New-VM -Name "NY-DC" -MemoryStartupBytes 2GB -VHDPath 'C:\vhd\nydc.vhdx' -SwitchName "Pri-NY" -Generation 2
New-VM -Name "RTR" -MemoryStartupBytes 1GB -VHDPath 'C:\VHD\RTR.vhdx' -SwitchName "Pri-TA" -Generation 2
New-VM -Name "W10CL1" -MemoryStartupBytes 1GB -VHDPath 'C:\VHD\W10CL1.vhdx' -SwitchName "Pri-TA" -Generation 2
New-VM -Name "W10CL2" -MemoryStartupBytes 1GB -VHDPath 'C:\VHD\W10CL2.vhdx' -SwitchName "Pri-NY" -Generation 2

Get-VM -Name * | Start-VM
# המתנה של שש דקות שהמכונות יעלו ואז אתחול מחדש
$totalTimes = 360

  $i = 0

  for ($i=0;$i -lt $totalTimes; $i++) {

  $percentComplete = ($i / $totalTimes) * 100

  Write-Progress -Activity 'Please Wait '  -PercentComplete $percentComplete

  sleep 1

}
Get-VM | Restart-VM -Force
# המתנה של דקה האתחול 
$totalTimes = 60

  $i = 0

  for ($i=0;$i -lt $totalTimes; $i++) {

  $percentComplete = ($i / $totalTimes) * 100

  Write-Progress -Activity 'Please Wait '  -PercentComplete $percentComplete

  sleep 1

}

#הגדרות בתוך המכונות עצמן 
#ניתן להתחבר באמצעות חיבור מרוחק 
# נגדיר משתנה עם הסיסמה והשם אותם אנו מכירים
$pass = ConvertTo-SecureString 'Pa55w.rd' -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ('user', $pass)
# DC1
$DC=New-PSSession -VMName DC1 -Credential $cred
Invoke-Command -Session $DC -ScriptBlock {New-NetIPAddress -InterfaceAlias Ethernet -IPAddress 10.0.0.1 -PrefixLength 24 -DefaultGateway 10.0.0.254} 
Invoke-Command -Session $DC -ScriptBlock {Get-NetAdapter -Name Ethernet | Rename-NetAdapter -NewName Client} # ישנה את שם כרטיס הרשת בהגדרות
Invoke-Command -Session $DC -ScriptBlock {Rename-LocalUser -Name Administrator -NewName Admin}
Invoke-Command -Session $DC -ScriptBlock {$pass = ConvertTo-SecureString 'Pa55w.rd' -AsPlainText -Force}
Invoke-Command -Session $DC -ScriptBlock {Set-LocalUser -Name Admin -Password $pass}
Invoke-Command -Session $DC -ScriptBlock {powercfg /x -monitor-timeout-ac 0} #ביטול מצב שינה למסך 
Invoke-Command -Session $DC -ScriptBlock {Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask -Verbose} # ביטול עליה  SERVERMANAGER
Invoke-Command -Session $DC -ScriptBlock {$HN=hostname}
Invoke-Command -Session $DC -ScriptBlock {Rename-Computer -ComputerName $HN -NewName DC1 -Restart}

#NY-DC
$NY=New-PSSession -VMName NY-DC -Credential $cred
Invoke-Command -Session $NY -ScriptBlock {New-NetIPAddress -InterfaceAlias Ethernet -IPAddress 20.0.0.1 -PrefixLength 24 -DefaultGateway 20.0.0.254}
Invoke-Command -Session $NY -ScriptBlock {Get-NetAdapter -Name Ethernet | Rename-NetAdapter -NewName Client}
Invoke-Command -Session $NY -ScriptBlock {powercfg /x -monitor-timeout-ac 0} #ביטול מצב שינה למסך 
Invoke-Command -Session $NY -ScriptBlock {Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask -Verbose} # ביטול עליה  SERVERMANAGER
Invoke-Command -Session $NY -ScriptBlock {$pass = ConvertTo-SecureString 'Pa55w.rd' -AsPlainText -Force}
Invoke-Command -Session $NY -ScriptBlock {Set-LocalUser -Name Administrator -Password $pass}
Invoke-Command -Session $NY -ScriptBlock {$HN=hostname} 
Invoke-Command -Session $NY -ScriptBlock {Rename-Computer -ComputerName $HN -NewName NY-DC -Restart}

#RTR
$RTR=New-PSSession -VMName RTR -Credential $cred
Invoke-Command -Session $RTR -ScriptBlock {New-NetIPAddress -InterfaceAlias Ethernet -IPAddress 10.0.0.254 -PrefixLength 24}
Invoke-Command -Session $RTR -ScriptBlock {Get-NetAdapter -Name Ethernet | Rename-NetAdapter -NewName Client}
Invoke-Command -Session $RTR -ScriptBlock {powercfg /x -monitor-timeout-ac 0} #ביטול מצב שינה למסך 
Invoke-Command -Session $RTR -ScriptBlock {$pass = ConvertTo-SecureString 'Pa55w.rd' -AsPlainText -Force}
Invoke-Command -Session $RTR -ScriptBlock {Set-LocalUser -Name Administrator -Password $pass}
Invoke-Command -Session $RTR -ScriptBlock {$HN=hostname}
Invoke-Command -Session $RTR -ScriptBlock {Rename-Computer -ComputerName $HN -NewName RTR -Restart}

#W10CL1
$CL1=New-PSSession -VMName W10CL1 -Credential $cred
Invoke-Command -Session $CL1 -ScriptBlock {New-NetIPAddress -InterfaceAlias Ethernet -IPAddress 10.0.0.10 -PrefixLength 24}
Invoke-Command -Session $CL1 -ScriptBlock {Get-NetAdapter -Name Ethernet | Rename-NetAdapter -NewName Client}
Invoke-Command -Session $CL1 -ScriptBlock {powercfg /x -monitor-timeout-ac 0} #ביטול מצב שינה למסך 
Invoke-Command -Session $CL1 -ScriptBlock {$HN=hostname}
Invoke-Command -Session $CL1 -ScriptBlock {Rename-Computer -ComputerName $HN -NewName W10CL1 -Restart}

#W10CL2
$CL2=New-PSSession -VMName W10CL2 -Credential $cred
Invoke-Command -Session $CL2 -ScriptBlock {New-NetIPAddress -InterfaceAlias Ethernet -IPAddress 20.0.0.10 -PrefixLength 24}
Invoke-Command -Session $CL2 -ScriptBlock {Get-NetAdapter -Name Ethernet | Rename-NetAdapter -NewName Client}
Invoke-Command -Session $CL2 -ScriptBlock {powercfg /x -monitor-timeout-ac 0} #ביטול מצב שינה למסך 
Invoke-Command -Session $CL2 -ScriptBlock {$HN=hostname}
Invoke-Command -Session $CL2 -ScriptBlock {Rename-Computer -ComputerName $HN -NewName W10CL2 -Restart}

# הגדרת הדומיין
$DC=New-PSSession -VMName DC1 -Credential $cred
Invoke-Command -Session $DC -ScriptBlock {Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -IncludeAllSubFeature}
Invoke-Command -Session $DC -ScriptBlock {Import-Module ADDSDeployment}
Invoke-Command -Session $DC -ScriptBlock {$pass = ConvertTo-SecureString 'Pa55w.rd' -AsPlainText -Force}
Invoke-Command -Session $DC -ScriptBlock {Install-ADDSForest -CreateDnsDelegation:$false -DatabasePath "C:\Windows\NTDS” -DomainMode “Win2012R2” -DomainName “TestLab.local” -DomainNetbiosName “TESTLAB” -ForestMode “Win2012R2” -InstallDns:$true -LogPath “C:\Windows\NTDS” -NoRebootOnCompletion:$false -SysvolPath “C:\Windows\SYSVOL” -Force:$true -SafeModeAdministratorPassword $pass}
# המתנה של שבע דקות שהשרת יעלה  
$totalTimes = 420

  $i = 0

  for ($i=0;$i -lt $totalTimes; $i++) {

  $percentComplete = ($i / $totalTimes) * 100

  Write-Progress -Activity 'Please Wait '  -PercentComplete $percentComplete

  sleep 1

}
# צירוף המכונות לדומיין 
$CL1=New-PSSession -VMName W10CL1 -Credential $cred
Invoke-Command -Session $CL1 -ScriptBlock  {$pass = ConvertTo-SecureString 'Pa55w.rd' -AsPlainText -Force}
Invoke-Command -Session $CL1 -ScriptBlock  {$cred = New-Object System.Management.Automation.PSCredential ('user', $pass)}
Invoke-Command -Session $CL1 -ScriptBlock {Set-DnsClientServerAddress -InterfaceAlias Client -ServerAddresses ("10.0.0.1")} # DNS SETTINGS
Invoke-Command -Session $CL1 -ScriptBlock {Add-Computer -DomainName "TestLab.local"  -Passthru -Verbose -Credential $cred}
Invoke-Command -Session $CL1 -ScriptBlock {Restart-Computer -Force}

$RTR=New-PSSession -VMName RTR -Credential $cred
Invoke-Command -Session $RTR -ScriptBlock  {$pass = ConvertTo-SecureString 'Pa55w.rd' -AsPlainText -Force}
Invoke-Command -Session $RTR -ScriptBlock  {$cred = New-Object System.Management.Automation.PSCredential ('user', $pass)}
Invoke-Command -Session $RTR -ScriptBlock {Set-DnsClientServerAddress -InterfaceAlias Client -ServerAddresses ("10.0.0.1")} # DNS SETTINGS
Invoke-Command -Session $RTR -ScriptBlock {Add-Computer -DomainName "TestLab.local"  -Passthru -Verbose -Credential $cred}
Invoke-Command -Session $RTR -ScriptBlock {Restart-Computer -Force}
# המתנה של חצי דקה  
$totalTimes = 30

  $i = 0

  for ($i=0;$i -lt $totalTimes; $i++) {

  $percentComplete = ($i / $totalTimes) * 100

  Write-Progress -Activity 'Please Wait '  -PercentComplete $percentComplete

  sleep 1

}

#שינוי הרשאות
$pass1 = ConvertTo-SecureString 'Pa55w.rd' -AsPlainText -Force
$cred1 = New-Object System.Management.Automation.PSCredential ('testlab\admin', $pass1)
#הקמת ראוטר
$RTR=New-PSSession -VMName RTR -Credential $cred1
Add-VMNetworkAdapter -VMName RTR -SwitchName Pri-NY
Invoke-Command -Session $RTR -ScriptBlock {Get-NetAdapter -Name Ethernet | Rename-NetAdapter -NewName NewYork}
Invoke-Command -Session $RTR -ScriptBlock {New-NetIPAddress -InterfaceAlias NewYork -IPAddress 20.0.0.254 -PrefixLength 24 }
Invoke-Command -Session $RTR -ScriptBlock {Install-WindowsFeature Routing -IncludeAllSubFeature -IncludeManagementTools}
Invoke-Command -Session $RTR -ScriptBlock {Restart-Computer}
# המתנה של חצי דקה  
$totalTimes = 30

  $i = 0

  for ($i=0;$i -lt $totalTimes; $i++) {

  $percentComplete = ($i / $totalTimes) * 100

  Write-Progress -Activity 'Please Wait '  -PercentComplete $percentComplete

  sleep 1

}

$RTR=New-PSSession -VMName RTR -Credential $cred1
Invoke-Command -Session $RTR -ScriptBlock {Install-RemoteAccess -VpnType RoutingOnly}
# המתנה של חצי דקה  
$totalTimes = 30

  $i = 0

  for ($i=0;$i -lt $totalTimes; $i++) {

  $percentComplete = ($i / $totalTimes) * 100

  Write-Progress -Activity 'Please Wait '  -PercentComplete $percentComplete

  sleep 1

}

#NY-DC הקמת DC
$NY=New-PSSession -VMName NY-DC -Credential $cred
Invoke-Command -Session $NY -ScriptBlock {Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -IncludeAllSubFeature}
Invoke-Command -Session $NY -ScriptBlock {Import-Module ADDSDeployment}
Invoke-Command -Session $NY -ScriptBlock {$pass = ConvertTo-SecureString 'Pa55w.rd' -AsPlainText -Force}
Invoke-Command -Session $NY -ScriptBlock {Set-DnsClientServerAddress -InterfaceAlias Client -ServerAddresses ("10.0.0.1")} # DNS SETTINGS
Invoke-Command -Session $NY -ScriptBlock {$pass1 = ConvertTo-SecureString 'Pa55w.rd' -AsPlainText -Force}
Invoke-Command -Session $NY -ScriptBlock {$cred1 = New-Object System.Management.Automation.PSCredential ('testlab\admin', $pass1)}
Invoke-Command -Session $NY -ScriptBlock {Install-ADDSDomainController -InstallDns -Credential $cred1 -DomainName 'Testlab.local' -SafeModeAdministratorPassword $pass1 -Force}
# המתנה של חמש דקות שהשרת יעלה  
$totalTimes = 300

  $i = 0

  for ($i=0;$i -lt $totalTimes; $i++) {

  $percentComplete = ($i / $totalTimes) * 100

  Write-Progress -Activity 'Please Wait '  -PercentComplete $percentComplete

  sleep 1

}
#צירוף לדומיין של מכונת CL2
$CL2=New-PSSession -VMName W10CL2 -Credential $cred
Invoke-Command -Session $CL2 -ScriptBlock {Set-DnsClientServerAddress -InterfaceAlias Client -ServerAddresses ("20.0.0.1")} # DNS SETTINGS
Invoke-Command -Session $CL2 -ScriptBlock  {$pass = ConvertTo-SecureString 'Pa55w.rd' -AsPlainText -Force}
Invoke-Command -Session $CL2 -ScriptBlock  {$cred = New-Object System.Management.Automation.PSCredential ('user', $pass)}
Invoke-Command -Session $CL2 -ScriptBlock {Add-Computer -DomainName "TestLab"  -Passthru -Verbose -Credential $cred}
Invoke-Command -Session $CL2 -ScriptBlock {Restart-Computer -Force}
