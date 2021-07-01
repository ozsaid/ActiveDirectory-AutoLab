New-ADOrganizationalUnit Sales
New-ADOrganizationalUnit Marketing
New-ADOrganizationalUnit Research
New-ADOrganizationalUnit Finance

Import-Csv .\LIST.csv | % {New-ADUser -Name $_.DISP -GivenName $_.GivenName -Surname $_.Surename -City $_.City -SamAccountName $_.SAM -UserPrincipalName $_.UPN -Department $_.DEP -Description $_.DES -DisplayName $_.DISP -Path $_.PATH -Company $_.COMP -AccountPassword (ConvertTo-SecureString $_.PASS -AsPlainText -Force) -Enabled $true -PasswordNeverExpires $true -PassThru}