<#
        .DESCRIPTION
    Script: List service not started after migration to W2k16
#>
#--------------------------------------------------------------------
## Input variables
#param (
    #[Parameter(Mandatory = $True)]
    #[String]$File,


#$sPath = "C:\~LOGS\MyWM\CompareServices"
#$sFile = "C:\~LOGS\MyWM\CompareServices\NotStartedAutoServices_Comma.csv"
#$sLoadFile =  Get-Content -Path $sFile | select -Skip 1
$sFile = "C:\~LOGS\MyWM\CompareServices\NotStartedAutoServices_Comma.csv"
$sFile_new = "C:\~LOGS\MyWM\CompareServices\NotStartedAutoServices_Comma-no-quote.csv" 
(Get-Content -Path $sFile).Replace('"','') | Set-Content -Path $sFile_new 
$sLoadFile =  Get-Content -Path $sFile_new | select -Skip 1

foreach($line in $sLoadFile)
{
    $sServiceName = $line.split(",")[0]
    $sServiceDisplayName = $line.split(",")[2]
    $sServiceStateBefore = $line.split(",")[5]
    $sServiceStateAfter = $line.split(",")[6]

    write-host "Service $sServiceDisplayName is $sServiceStateAfter, the service was $sServiceStateBefore before migration" 
}
#-------------------------------------------------------------------------
