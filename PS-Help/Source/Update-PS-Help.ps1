<#
.SYNOPSIS
Updates PowerShell Help source folder for deployment with Intune-Apps Framework
	
.DESCRIPTION
Updates PowerShell Help source folder for deployment with Intune-Apps Framework. This script needs to be run from his location. No Administrative permissions required.

.EXAMPLE 
C:\PS> Update-PS-Help.ps1

.NOTES
Author     : Fabian Niesen (www.fabian-niesen.de)
Filename   : Update-PS-Help.ps1
Requires   : PowerShell Version 3.0
Version    : 0.2
History    : 0.2   FN  23.03.2022 Add Header and some output, added installed local instead of de-DE
             
.LINK
https://github.com/InfrastructureHeroes/Intune-Apps

#>
[CmdLetBinding()] param()
$locCult = (Get-Culture)[0].Name
Write-Output "Update Help for all installed Modules in $locCult, if a locilized help is available"
IF (!(Test-Path $PSScriptRoot\PS-Help\$locCult)) { new-item -path $PSScriptRoot\PS-Help\de-DE -ItemType Directory -Confirm:$false -Force | Out-Null }
Save-Help -DestinationPath $PSScriptRoot\PS-Help\$locCult -Module $(Get-Module -ListAvailable) -UICulture $locCult -Force -ErrorAction SilentlyContinue
Write-Output "Update Help for all installed Modules in en-US"
IF (!(Test-Path $PSScriptRoot\PS-Help\en-US)) { new-item -path $PSScriptRoot\PS-Help\en-US -ItemType Directory -Confirm:$false -Force| Out-Null }
Save-Help -DestinationPath $PSScriptRoot\PS-Help\en-US -Module $(Get-Module -ListAvailable) -UICulture en-US -Force -ErrorAction SilentlyContinue
Write-Output "Done."