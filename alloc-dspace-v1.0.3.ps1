############################################################
# DESCRIPTION: Windows disk partition space allocate PowerShell.
#    It increases the size of the provided partition to the 
#    maximum possible size. 
#
# USE: It requires the variable DRIVE (Windows drive letter, i.e. c, d...).
#
# PLAYBOOK: Used by windows-diskspace-allocate.yml
#
# VERSION: 1.0.0, Alain Trinh, 18/05/2020
#    - First working version
#
# VERSION: 1.0.1, Juan Lopez, 18/05/2020
#    - Added feature to accept input parameters
#    - Added and more comments and fixed small output text details
#
# VERSION: 1.0.2, Alain Trinh, 24/06/2020
############################################################

# EXIT CODE     COMMENTS
# 97            Issue to collect the drive letter to upgrade - drive letter not exist or is not a drive
# 98            Issue to collect the information, if local hard drive exist
# 99            Issue during the process to rescan the computer looking for disks and volumes
# 100           Partition Resize - Issue during resize process
# 101           Issue during the collect of volume information freespace before upgrade
# 102           Issue during the collect of volume information freespace after upgrade
# 103           Issue during upgrade - the drive letter has not been upgraded - no unallocated partition next to the partition to upgrade


#INPUT PARAMETERS
Param (
        [string]$sDriverLetter
)

#$sDiskExtendSize = "10"

#ENVIRONMENT VARIABLES
$sLocation = "C:\Temp\"

#Check if local hard drive exist, if driveletter equal drivetype=3
$sFormatDriveLetter = "'$sDriverLetter :'"
$sFinaleFormatDriveLetter = $sFormatDriveLetter.replace(' ','')
$sSearchLocalDrive = "DeviceID = $sFinaleFormatDriveLetter and drivetype='3'"

$sLocalDrive = Get-WmiObject -Class Win32_logicaldisk -Filter "$sSearchLocalDrive"

try
{
    if (-not $sLocalDrive)
        {
            $sExitCode = "97"
            Write-Host "The drive letter to upgrade not exist or is not a drive"
            Exit $sExitCode
        }
    else
        {
            $sExitCode = "0"
            #Write-Host "The drive letter $sDriverLetter is a hard drive"
        }
}
catch
{
    Write-Host $Error 
    $sExitCode = "98" 
    Exit 98 
}
finally
{
    Write-Host "Check if local hard drive exist - Exit code: " $sExitCode 
}


#Check volume $sDriverLetter freespace before upgrade
try
{
    $sDrive = Get-PSDrive $sDriverLetter
    $sDriveFreespace = $sDrive.free
    $sDriveFreespaceInGB = ($sDriveFreespace / 1GB)
    $sDriverFreespaceResult = [math]::Round($sDriveFreespaceInGB,2)
    $sExitCode = "0"
}
catch
{
    Write-Host $Error 
    $sExitCode = "101" 
    Exit 101 
}
finally
{
    Write-Host "Check volume $sDriverLetter freespace before upgrade: $sDriverFreespaceResult GB - Exit code: " $sExitCode 
}

    
try
{
    #Rescan the computer looking for disks and volumes
    $sRescanFileName = "allocate-disk-space-2k8-2016-rescan.txt"
    $sRescanFileResult = "allocate-disk-space-2k8-2016-rescan-result.txt"
    Set-Content $sLocation\$sRescanFileName "select volume $sDriverLetter"
    Add-Content $sLocation\$sRescanFileName "rescan"
    diskpart /s $sLocation\$sRescanFileName >$sLocation\$sRescanFileResult
    $sExitCode = "0"
}
catch
{
    Write-Host $Error 
    $sExitCode = "99" 
    Exit 99 
}
finally
{
    Write-Host "Rescan the computer looking for disks and volumes - Exit code: " $sExitCode 
}

try
{
    #Partition Resize
    $sResizeFileName = "allocate-disk-space-2k8-2016-resize.txt"
    $sResizeFileResult = "allocate-disk-space-2k8-2016-resize-result.txt"
    Set-Content $sLocation\$sResizeFileName "select volume $sDriverLetter"
    Add-Content $sLocation\$sResizeFileName "extend"
    diskpart /s $sLocation\$sResizeFileName >$sLocation\$sResizeFileResult 
    $sExitCode = "0"
}
catch
{
    Write-Host $Error 
    $sExitCode = "100" 
    Exit 100 
}
finally
{
    Write-Host "Partition Resize - Exit code: " $sExitCode 
}


#Check volume $sDriverLetter freespace after upgrade
try
{
    $sDrive2 = Get-PSDrive $sDriverLetter
    $sDriveFreespace2 = $sDrive2.free
    $sDriveFreespaceInGB2 = ($sDriveFreespace2 / 1GB)
    $sDriverFreespaceResult2 = [math]::Round($sDriveFreespaceInGB2,2)
    $sExitCode = "0"
}
catch
{
    Write-Host $Error 
    $sExitCode = "102" 
    Exit 102 
}
finally
{
    Write-Host "Volume $sDriverLetter freespace before upgrade: $sDriverFreespaceResult GB"
    Write-Host "Volume $sDriverLetter freespace after upgrade: $sDriverFreespaceResult2 GB"

    if ($sDriverFreespaceResult2 -gt $sDriverFreespaceResult)
    {
        $sFreespaceUpdate = $sDriverFreespaceResult2 - $sDriverFreespaceResult
        Write-Host "Volume $sDriverLetter freespace has been updated by $sFreespaceUpdate GB - Exit code: " $sExitCode
    }
    else
    {
        Write-host "Volume $sDriverLetter has not been upgraded - no unallocated partition - Exit code: 103"
		exit 103
    }
}
