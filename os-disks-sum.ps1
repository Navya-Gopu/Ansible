# EXIT CODE     COMMENTS
# 97            The sum of all the disks of the host is greater than 1 TB, the upgrade must be done manually
# 98            Unexpected error

param(
[Parameter(Mandatory=$False)]
[string]$MAXSIZEGB
)

$ExitCode = 0
$iMaxSizeGb = 1000
$sHost = hostname

# Input control
if ($MAXSIZEGB) {
	try {
		$iMaxSizeGb = [int] $MAXSIZEGB
	}
	catch {
		Write-Host "FAILED_ARGUMENT_ERROR MAXSIZEGB numeric value expected. "
		[Environment]::Exit(1)
	}
}

try {

	# Get DISKS INFORMATION
	$sDisksInfo = Get-WmiObject -class win32_logicaldisk | Measure-Object -Sum size
	$sDiskSum = $sDisksInfo.sum
	[int]$sConvertDiskSum = ($sDiskSum / 1GB)

	if ($sConvertDiskSum -gt $iMaxSizeGb){
		$ExitCode = 97
		$sExitMessage =  "The sum of the disks $sConvertDiskSum GB, is greater than $iMaxSizeGb GB, the upgrade must be done manually"
	}
    else {
		$sExitMessage = "The sum of the disks is $sConvertDiskSum GB for the host $sHost, the upgrade can continue"
	}
	Write-Host $sExitMessage
}
catch {
	Write-Host $Error 
	$ExitCode = 98
}

[Environment]::Exit($ExitCode)
