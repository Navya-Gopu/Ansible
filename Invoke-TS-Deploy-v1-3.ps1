<#

	.DESCRIPTION
    Script to invoke the deployment of ISO for W2012 Migration

    Created by: Giancarlo Pannullo
    Contact:    Giancarlo.Pannullo@atos.net

    Team:       Airbus ABC Patching team
    Email:      MS-AIRBUS-ABC-PATCHING@atos.net

    Version:    1.3

    .VERSION HISTORY
    Ver 1.3 - 06/04/2020
        -	Added Parameters
        -   Added POC Switch
        -   Added Policy Refresh by WMI

    Ver 1.2 - 10/03/2020
        -	Added SCCM CB Support

    Ver 1.1 - 12/01/2020
        -	Added POC
        -   Time increase for policy refresh

    Ver 1.0 - 17/12/2019
        -	Initial Version

#>
[CmdletBinding()]
param (

    [Parameter(Mandatory = $false)]
    [String]$SMSDLLPath = "C:\temp\InvokeTSMig\smsclictr.automation.DLL",

    [Parameter(Mandatory = $false)]
    [Switch]$UsePOC,

    [Parameter(Mandatory = $false)]
    [Switch]$WhatIf

)

# Variables
Start-Transcript -Path "C:\temp\InvokeTSMig\TSMig_transcript.log"
$ComputerName = $ENV:COMPUTERNAME
$WMITriggers = @("{00000000-0000-0000-0000-000000000021}*Request Machine Assigments",
    "{00000000-0000-0000-0000-000000000108}*Software Update Assigments",
    "{00000000-0000-0000-0000-000000000113}*Scan Update Source",
    "{00000000-0000-0000-0000-000000000042}*Policy Agent Validate Machine Policy / Assignment",
    "{00000000-0000-0000-0000-000000000021}*Request Machine Policies",
    "{00000000-0000-0000-0000-000000000022}*Evaluate Machine Policies")

if ($UsePOC) {

    $TSPkgName = "AtoS - W2k8 R2 To W2k12R2 Mig POC" # For SCCM 2007 POC
    $TSPkgNameCB = "AtoS ABC - W2k8 R2 To W2k12R2 Mig"

}
else {

    $TSPkgName = "AtoS - W2k8 R2 To W2k12R2 Mig"
    $TSPkgNameCB = "AtoS ABC - W2k8 R2 To W2k12R2 Mig"

}

# Check Site Code ?
# $SCCMSiteCode = New-Object –ComObject "Microsoft.SMS.Client"

# Load the .DLL locally to be able manage SMS Client from CLI
If (Test-Path -Path $SMSDLLPath) {

    Add-Type -Path $SMSDLLPath
    $ReRun = New-Object -TypeName smsclictr.automation.SMSClient($Computername)

    # Request to refresh the machine policy to have the last packages and wait 30 Seconds to let the server download the policies
    $ReRun.RequestMachinePolicy()

    #region Invoke SCCM Policies
    $WMITriggers | ForEach-Object {

        $strName = $_.Split("*")[1]
        $strAction = $_.Split("*")[0]

        try {

            $WMIPath = ("\\{0}\root\ccm:SMS_Client" -f $ENV:COMPUTERNAME)
            Write-Verbose ("[WMI Invoke] - InvokeCMD: {0}\{1}" -f $WMIPath, $strAction)
            $SMSwmi = [wmiclass]$WMIPath
            [Void]$SMSwmi.TriggerSchedule($strAction)

        }
        catch {

            Write-Warning ("WMI Invoke: Failed to invoke {0} for {1} due {2}" -f $strAction, $strName, $_.Exception.Message)

        }

    }
    Write-Host "WMI Invoke: Policies refresh time finished"
    #endregion Invoke SCCM Policies

    Write-Host "Waiting 360 Seconds to refresh the policies"
    Start-Sleep -seconds 360

    #
    # Commands below are used to automatically detect the last version of the Task Sequence package for the migration
    #
    # List the Advertisements available for the server and look for Task Sequence of the Upgrade

    $Adv = $ReRun.SoftwareDistribution.Advertisements
    $AtoSTS = $Adv | Where-Object { $_.PKG_Name -eq $TSPkgName -or $_.PKG_Name -eq $TSPkgNameCB } | Select-object PRG_ProgramID, PRG_ProgramName, ADV_AdvertisementID, PKG_PackageID, PKG_Name

    # Store the ID’s in the variables to launch the TS

    $AdvID = $ATOSTS.Adv_AdvertisementID
    $PkgID = $ATOSTS.PKG_PackageID

    # Display the Output with the ID’s
    Write-Host ("ADV: {0} | PkgID: {1}" -f $AdvID, $PkgID)

    # If he found the Task Sequence Start Operation
    # Else no action is done
    if ($AtoSTS) {

        Write-Host ("Invoking TS {0}" -f $AdvID)
        $ReRun.SoftwareDistribution.RerunAdv($AdvID, $PkgID, "*")
        Write-Host "TaskSequence is starting... waiting 120 seconds while intial content is downloaded"
        Start-Sleep -Seconds 120

        # Msg from Execmgr.log in case to use GC
        # Execution is complete for program Start W2k8R2 Mig Copy. The exit code is 0, the execution status is Success

        do {

            $TSService = Get-Service -Name smstsmgr
            Write-Host "TaskSequence Service is still running... waiting to finish"
            Start-Sleep -Seconds 60

        } while ($TSService.status -ne "stopped" )

        Write-Host "Waiting 600 Seconds before check folders (modif: 09-04-2020)"
        Start-Sleep -Seconds 600

        if (-not ((Test-Path "D:\__MigLocal") -and (Test-Path "D:\_MigSRC") -and (Test-Path "D:\__MigLocal\_Main_W08R2-to-W12R2_customWIM.cmd")) ) {

            Write-Host "D:\__MigLocal | D:\_MigSRC: KO !"
            $ExitCode = "2"
            [Environment]::Exit($ExitCode)

        }
        Else {

            Write-Host "D:\__MigLocal | D:\_MigSRC: OK !"
            $ExitCode = "0"
            [Environment]::Exit($ExitCode)

        }

    }
    Else {

        Write-Warning "TS Not found...skipping TS Operation"
        $ExitCode = "1"
        [Environment]::Exit($ExitCode)

    }

}
