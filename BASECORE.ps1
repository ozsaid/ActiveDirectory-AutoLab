<# 
סקריפט בניית קבצי בייס לשימוש המעבדה
הסקריפט בונה קובץ מתוך אימג' של שרת 2019
מתקין בתוכו קובץ תשובות 
מבצע לו אקטיבציה




#>
<#

#>
#שלב ראשון יצירת הדיסק הוירטואלי
#verify the file doesn't already exist
mkdir C:\base
[string]$Path="C:\BASE\BASE19CORE.vhdx"
if (Test-Path -Path $path) {
    Write-Host "Disk image at $path already exists."
    #bail out
    Break
} 
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.MessageBox]::Show("Press OK to Select The Server 2019 ISO FILE (Default location C:\iso) choose core edition ")
#FILE EXPLORER DIALOG
$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
    InitialDirectory = 'C:\ISO'
    Filter = 'ISO Files (*.iso)|*.iso'
}
$null = $FileBrowser.ShowDialog()
$ISOFILE=$FileBrowser.FileName
Mount-DiskImage -ImagePath $ISOFILE
$ISOImage = Get-DiskImage -ImagePath $ISOFILE | Get-Volume
$WimFolder = $ISOImage.DriveLetter+":\sources"
$wimfile=$WimFolder+"\install.wim"
##########################################################
# Checking that a valid install.wim file is in WIM folder. 
##########################################################

Write-Host 'Checking if folder'$WimFolder 'contains a valid install.wim image...'
$WimCount = 0
while ($WimCount -eq 0) {
   
    if (Test-Path $WimFolder\install.wim)
        {
        $WimCount = 1
        }
    elseif (Test-Path $WimFolder)
        {
        $WimCount = 0
        cls
        Write-Host
        Write-Host ' No Windows image found. Please copy a valid'
        Write-Host ' install.wim to'$WimFolder 'and try again.'
        Write-Host ' ' -NoNewline
        Write-Host
        Pause
        }
    else
        {
        $WimCount = 0
        cls
        Write-Host
        Write-Host ' Path'$WimFolder 'does not exist.'
        Write-Host ' Create it and store valid install.wim file in it.'
        Write-Host
        Write-Host ' ' -NoNewline
        Pause
        }
    }
    $wimfile=$WimFolder+"\install.wim"

# הגדרת משתנים V
[string]$Path="C:\BASE\BASE19CORE.vhdx"
[uint64]$Size=50GB
[switch]$Dynamic
[UInt32]$BlockSizeBytes=2MB
[ValidateSet(512,4096)]
[Uint32]$LogicalSectorSizeBytes=512
[Uint32]$PhysicalSectorSizeBytes=512
$RESize = 300MB
$SysSize = 100MB
$MSRSize = 128MB
$RecoverySize = 1GB
Write-Host "Creating $path"


$vhdParams=@{
 ErrorAction= "Stop"
 Path = $Path
 SizeBytes = $Size
 Dynamic = $Dynamic
 BlockSizeBytes = $BlockSizeBytes
 LogicalSectorSizeBytes = $LogicalSectorSizeBytes
 PhysicalSectorSizeBytes = $PhysicalSectorSizeBytes
}

Try {
  Write-verbose ($vhdParams | out-string)
  $disk = New-VHD @vhdParams

}
Catch {
  Throw "Failed to create $path. $($_.Exception.Message)"
  #bail out
  Return
}
if ($disk) {
    #mount the disk image
    Write-Verbose "Mounting disk image"

    Mount-DiskImage -ImagePath $path
    #get the disk number
    $disknumber = (Get-DiskImage -ImagePath $path | Get-Disk).Number

    $WinPartSize = (Get-Disk -Number $disknumber).Size - ($RESize+$SysSize+$MSRSize+$RecoverySize)

    #initialize as GPT
    Write-Verbose "Initializing disk $DiskNumber as GPT"
    Initialize-Disk -Number $disknumber -PartitionStyle GPT 

    #clear the disk
    Write-Verbose "Clearing disk partitions to start all over"
    get-disk -Number $disknumber | Get-Partition | Remove-Partition -Confirm:$false

    #create the RE Tools partition
    Write-Verbose "Creating a $RESize byte Recovery tools partition on disknumber $disknumber"
    New-Partition -DiskNumber $disknumber -GptType '{de94bba4-06d1-4d40-a16a-bfd50179d6ac}' -Size $RESize |
    Format-Volume -FileSystem NTFS -NewFileSystemLabel "Windows RE Tools" -confirm:$false | Out-null

   $partitionNumber = (get-disk $disknumber | Get-Partition | where {$_.type -eq 'recovery'}).PartitionNumber

    Write-Verbose "Retrieved partition number $partitionnumber"

    #run diskpart to set GPT attribute to prevent partition removal
    #the here string must be left justified


    #create the system partition
    Write-Verbose "Creating a $SysSize byte System partition on disknumber $disknumber"
    <#
     There is a known bug where Format-Volume cannot format an EFI partition
     so formatting will be done with Diskpart
    #>

    $sysPartition = New-Partition -DiskNumber $disknumber -GptType '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}' -Size $SysSize

    $systemNumber = $sysPartition.PartitionNumber

    Write-Verbose "Retrieved system partition number $systemNumber"
"@
select disk $disknumber
select partition $systemNumber
format quick fs=fat32 label=System 
exit
@" | diskpart | Out-Null

    #create MSR
    write-Verbose "Creating a $MSRSize MSR partition"
    New-Partition -disknumber $disknumber -GptType '{e3c9e316-0b5c-4db8-817d-f92df00215ae}' -Size $MSRSize | Out-Null

    #create OS partition
    Write-Verbose "Creating a $WinPartSize byte OS partition on disknumber $disknumber"
    New-Partition -DiskNumber $disknumber -Size $WinPartSize | Out-Null

    #create recovery
    Write-Verbose "Creating a $RecoverySize byte Recovery partition"
    $RecoveryPartition = New-Partition -DiskNumber $disknumber -GptType '{de94bba4-06d1-4d40-a16a-bfd50179d6ac}' -UseMaximumSize | Out-Null
    $RecoveryPartitionNumber = $RecoveryPartition.PartitionNumber

    $RecoveryPartition | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Windows Recovery" -confirm:$false

    #run diskpart to set GPT attribute to prevent partition removal
    #the here string must be left justified
@"
select disk $disknumber
select partition $RecoveryPartitionNumber
exit
"@ | diskpart | Out-Null

    #dismount
    Write-Verbose "Dismounting disk image"

    Dismount-DiskImage -ImagePath $path

    #write the new disk object to the pipeline
    Get-Item -Path $path

} #if $disk

#Disk
$RefVHDXPath = 'C:\BASE\BASE19CORE.vhdx'
# Get the disk number
Mount-VHD -Path $RefVHDXPath 
$VHDDisk = Get-DiskImage -ImagePath $RefVHDXPath | Get-Disk
$VHDDiskNumber = [string]$VHDDisk.Number
$DNumber=(get-disk | Where-Object PartitionStyle -eq 'GPT').Number
Get-Partition -DiskNumber $DNumber | Where-Object Type -eq 'Basic' | Set-Partition -NewDriveLetter W 
Format-Volume -DriveLetter W -FileSystem NTFS -NewFileSystemLabel Windows -Confirm:$false -Force 
Get-Partition -DiskNumber $DNumber | Where-Object Type -eq 'System' | Set-Partition -NewDriveLetter S
Format-Volume -DriveLetter S -FileSystem FAT32 -Confirm:$false -Force
$IndexList = Get-WindowsImage -ImagePath $WimFile
Write-Verbose "$($indexList.count) images found"
$item = $IndexList | Out-GridView -OutputMode Single
$index = $item.ImageIndex
Write-Host "Selected image index  $index "
Write-Host "Image Name: [$($indexlist[$index].Imagename)]"
# Execute DISM to apply image to reference disk
Write-Host 'Using DISM to apply image to the volume'
Write-Host "Started at [$(Get-Date)]"
Write-Host 'THIS WILL TAKE SOME TIME!'
Dism.exe /apply-Image /ImageFile:$WimFile /index:$Index /ApplyDir:W:\
Write-Verbose "Finished at [$(Get-Date)]"
#ANSWERFILE
mkdir W:\Windows\Panther
New-Item  W:\Windows\Panther\Unattend.xml
$ANSWER = "W:\Windows\Panther\Unattend.xml"
Add-Content $Answer '<?xml version="1.0" encoding="utf-8"?>'
Add-Content $Answer '<unattend xmlns="urn:schemas-microsoft-com:unattend">'
Add-Content $Answer   ' <settings pass="windowsPE">'
Add-Content $Answer      '  <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
Add-Content $Answer        '    <InputLocale>en-US</InputLocale>'
Add-Content $Answer        '    <SystemLocale>en-US</SystemLocale>'
Add-Content $Answer        '    <UILanguage>en-US</UILanguage>'
Add-Content $Answer         '   <UserLocale>en-US</UserLocale>'
Add-Content $Answer      '  </component>'
Add-Content $Answer      '  <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
Add-Content $Answer       '     <UserData>'
Add-Content $Answer         '       <ProductKey>'
Add-Content $Answer         '           <Key>NPPR9-FWDCX-D2C8J-H872K-2YT4</Key>'
Add-Content $Answer         '       </ProductKey> '
Add-Content $Answer         '       <AcceptEula>true</AcceptEula> '
Add-Content $Answer          '      <Organization>TestLab</Organization>'
Add-Content $Answer      '      </UserData>'
Add-Content $Answer     '   </component>'
Add-Content $Answer  '  </settings>'
Add-Content $Answer   ' <settings pass="specialize">'
Add-Content $Answer    '    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
Add-Content $Answer    '        <TimeZone>Israel Standard Time</TimeZone>'
Add-Content $Answer    '        <CopyProfile>true</CopyProfile>'
Add-Content $Answer     '       <RegisteredOrganization>TestLab</RegisteredOrganization>'
Add-Content $Answer     '       <RegisteredOwner>Oz</RegisteredOwner>'
Add-Content $Answer    '    </component>'
Add-Content $Answer   '  </settings>'
Add-Content $Answer   ' <settings pass="oobeSystem">'
Add-Content $Answer     '   <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
Add-Content $Answer         '   <InputLocale>en-US</InputLocale>'
Add-Content $Answer          '  <SystemLocale>en-US</SystemLocale>'
Add-Content $Answer         '   <UILanguage>en-US</UILanguage>'
Add-Content $Answer         '   <UserLocale>en-US</UserLocale>'
Add-Content $Answer       '  </component>'
Add-Content $Answer       '  <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
Add-Content $Answer           ' <OOBE>'
Add-Content $Answer               ' <HideEULAPage>true</HideEULAPage>'
Add-Content $Answer               ' <HideLocalAccountScreen>true</HideLocalAccountScreen>'
Add-Content $Answer               ' <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>'
Add-Content $Answer               ' <HideOnlineAccountScreens>true</HideOnlineAccountScreens>'
Add-Content $Answer               ' <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>'
Add-Content $Answer               ' <ProtectYourPC>1</ProtectYourPC>'
Add-Content $Answer           ' </OOBE>'
Add-Content $Answer           ' <UserAccounts>'
Add-Content $Answer              '  <LocalAccounts>'
Add-Content $Answer                   ' <LocalAccount wcm:action="add">'
Add-Content $Answer                    '    <Password>'
Add-Content $Answer                        '    <Value>UABhADUANQB3AC4AcgBkAFAAYQBzAHMAdwBvAHIAZAA=</Value>'
Add-Content $Answer                           ' <PlainText>false</PlainText>'
Add-Content $Answer                      '  </Password>'
Add-Content $Answer                     '   <Description>LocalAccount</Description>'
Add-Content $Answer                       ' <DisplayName>User</DisplayName>'
Add-Content $Answer                       ' <Group>Administrators</Group>'
Add-Content $Answer                      ' <Name>User</Name>'
Add-Content $Answer                   ' </LocalAccount>'
Add-Content $Answer           '     </LocalAccounts>'
Add-Content $Answer           ' </UserAccounts>'
Add-Content $Answer       ' </component>'
Add-Content $Answer    '</settings>'
Add-Content $Answer   ' <cpi:offlineImage cpi:source="wim:c:/adk/install.wim#Windows 10 Enterprise" xmlns:cpi="urn:schemas-microsoft-com:cpi" />'
Add-Content $Answer '</unattend>'
 
#BOOT - Should be in EFI !!!
cmd /c w:\Windows\System32\bcdboot.exe W:\windows /s s: /F UEFI

#ACTIVATE
$ACT=$env:Temp 
iwr "https://github.com/massgravel/Microsoft-Activation-Scripts/archive/refs/heads/master.zip" -OutFile $ACT\act.zip
Expand-Archive -Path $ACT\act.zip -DestinationPath $ACT -Force
copy-item "$ACT\Microsoft-Activation-Scripts-master\MAS_1.4\Separate-Files-Version\Activators\HWID-KMS38_Activation\" -Destination W:\windows\setup\scripts -Recurse 
Rename-Item -Path W:\windows\setup\scripts\KMS38_Activation.cmd -NewName SetupComplete.cmd
Dismount-VHD $RefVHDXPath 
Dismount-DiskImage -ImagePath $ISOFILE
