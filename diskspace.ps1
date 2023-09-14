#PAGE FILE SIZE
$sPagefileInfo = Get-WmiObject -Class Win32_PageFileUsage | Select-Object *
$sPagefileSize = $sPagefileInfo.AllocatedBaseSize /1024
#write-host "pagefile size in GB: " $sPagefileSize

#DISK INFO
$sImportDiskInfo = Get-WmiObject -Class win32_logicaldisk | where caption -eq "C:" 
$sfreespace = ([math]::Round(($sImportDiskInfo.FreeSpace /1GB),2))
$sdiskSize = ([math]::Round(($sImportDiskInfo.Size /1GB),2))

#write-host "free space on C:\ in GB: " $sfreespace 
#write-host "disk size in GB: " $sdiskSize 

$sRAM = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).sum /1gb
#write-host "ram in GB: " $sRAM

#FREE SPACE ON DISK C: FOR OS UPGRADE
$Targetfreespace = $sRAM + 20
#$Targetfreespace = 60
#write-host "required free space for os upgrade: " $Targetfreespace "GB"


#DISK C READY FOR OS UPGRADE
$Targetdisksize =  $sdiskSize + $Targetfreespace - $sfreespace
$NumberofGBtoUpgrade = $Targetfreespace - $sfreespace

#write-host "Target disk size for C:"$Targetdisksize
#write-host "Number of GB to upgrade for C: drive:" $NumberofGBtoUpgrade

if ($sfreespace -le $Targetfreespace)
    {
        Write-host "not enough free space for os upgrade - Free space on C: is $sfreespace GB, expected free space:  $Targetfreespace GB"
        Write-Host "Disk increase on C drive is necessary before to launch the os upgrade - Current disk size on C:" $sdiskSize "GB, target disk size for C:" $Targetdisksize "GB, free space missing" $NumberofGBtoUpgrade "GB"
	exit 1
    }
else
    {
        write-host "enough free space for os upgrade - Required free space on C:" $Targetfreespace "GB, available free space on C:" $sfreespace "GB"
    }
    
