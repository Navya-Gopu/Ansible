<#

	.SYNOPSIS
    Script to Re-Install McAfee  - For local execution

	.DESCRIPTION
    The script checks if McAfee Agent is installed.
	If yes, it uninstall it and install the 5.6.2 Version

	Version: 1.2
    Created by: Daniel de la Torre Bueno
    Team:       Airbus ABC Antivirus Team

	.VERSION HISTORY
	Ver 1.0 - 03/03/2020
	-	Initial Version

	Ver 1.1 - 04/03/2020
	-   Added functions and FrmInst method for uninstall
	
	Ver 1.2 - 06/03/2020 - Patrick RAZANAPARANY - Airbus ABC Grid Team
	-   UPDATE for ABC Automation Project : Re-Install version (McAfee need to be present)

#>

#region Variables

[bool]$CheckMAInstall = $False
[string]$MAPackagePath = "C:\Temp\FramePkg_5.6.2.exe"

#endregion Variables

#region Functions

function Get-MAInfo {

    (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*).displayname -contains "McAfee Agent"

}

function Install-MA {

    Write-Verbose ("[INSTALL] Beginning McAfee Agent installation...")
    $MAInstallPID = (Start-Process -FilePath "$MAPackagePath" -ArgumentList '/INSTALL=AGENT','/SILENT' -PassThru).Id
    Wait-Process $MAInstallPID
	Write-Verbose ("[INSTALL] McAfee Agent installation ended ...")
}

function Uninstall-MA {
    param(
        [string] [Parameter(Mandatory = $true)] $Method
		)

    if ($Method -eq "RIPPER") {
        
        Write-Verbose ("[UNINSTALL] Beginning McAfee Agent uninstallation by RIPPER...")
        $ProcessPID = (Start-Process -FilePath "$MAPackagePath" -ArgumentList '/ripper' -PassThru).Id
        Wait-Process $ProcessPID
		Write-Verbose ("[UNINSTALL] uninstall by RIPPER ended ...")
    }

    if ($Method -eq "FRMINST") {

        [string]$Path64 = "C:\Program Files\McAfee\Agent\x86\FrmInst.exe" 
        [string]$Path32 = "C:\Program Files (x86)\McAfee\Common Framework\x86\FrmInst.exe"

        Write-Verbose ("[UNINSTALL] Beginning McAfee Agent uninstallation by FRMINST...")

        if (Test-Path $Path64) {

            $ProcessPID = (Start-Process -FilePath $Path64 -ArgumentList '/forceuninstall','/SILENT' -PassThru).Id
            Wait-Process $ProcessPID

        }

        if (Test-Path $Path32) {
            $ProcessPID = (Start-Process -FilePath $Path32 -ArgumentList '/forceuninstall','/SILENT' -PassThru).Id
            Wait-Process $ProcessPID
        }
		Write-Verbose ("[UNINSTALL] uninstall by FRMINST ended ...")
    }
}

#endregion Functions

#region Process Data

    try {
        
		$ExitCode = 1
		if (-Not (Test-Path $MAPackagePath)) {
			Write-Host "McAfee Package NOT FOUND"
			[Environment]::Exit($ExitCode)
		}
		
        $CheckMAInstall = Get-MAInfo
        if ($CheckMAInstall -eq $True) {
            # McAfee present - Launch Uninstall

            Uninstall-MA -Method "FRMINST"

            $CheckMAInstall = Get-MAInfo
            if ($CheckMAInstall -eq $False) {
                # Uninstall successful - Launch Install
                Install-MA

                $CheckMAInstall = Get-MAInfo
                if ($CheckMAInstall -eq $True){
					Write-Host "McAfee Agent Installation Successful."
					$ExitCode = 0
				}
				else {
					Write-Host "UNABLE to RE-INSTALL McAfee Agent"
					$ExitCode = 2
                }
            }
            else {
                # FRMINST Mode failed Try by Ripper method
                Uninstall-MA -Method "RIPPER"

                $CheckMAInstall = Get-MAInfo
                if ($CheckMAInstall -eq $False) {
                    # Uninstall by ripper successful - Launch Install
                    Install-MA

                    $CheckMAInstall = Get-MAInfo
                    if ($CheckMAInstall -eq $True) {
						Write-Host "McAfee Agent Installation Successful."
						$ExitCode = 0
					}
					else {
                        Write-Host "UNABLE to RE-INSTALL McAfee Agent"
						$ExitCode = 3
                    }
                }
				else {
					Write-Host "McAfee Agent Uninstall by Ripper mode FAILED."
					$ExitCode = 4
				}
            }
        }
        else {
            Write-Verbose "McAfee Agent does not exist on this machine."
			$ExitCode = 5
        }
    }
    catch {
        
        Write-Host "UNABLE to RE-INSTALL McAfee Agent due to Exception"
		$ExitCode = 9
    }
	
	[Environment]::Exit($ExitCode)
#endregion Process Data
