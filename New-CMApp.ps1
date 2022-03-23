<#
.SYNOPSIS
Create Config Manager Apps from the same Framework the the Intune APPs with the same detection clauses
	
.DESCRIPTION
Create Config Manager Apps from the same Framework the the Intune APPs with the same detection clauses

.EXAMPLE 
C:\PS> New-CMApp.ps1

.EXAMPLE 
C:\PS> New-CMApp.ps1 -packagePath "Microsoft-BGInf- 4.26" -DistributionPointGroupName "Alle Server" -SourceLocation "\\sccm01-2019\Intune-Apps$"

.EXAMPLE 
C:\PS> \\cm01\SMS_Applications$\_Fabian\Intune-Apps\New-CMApp.ps1 -packagePath "Microsoft-BGInfo-4.26" -DistributionPointGroupName "PS1 Head Quarter DP Group 1" -SourceLocation "\\cm01\SMS_Applications$\_Fabian\Intune-Apps"

.EXAMPLE 
C:\PS> \\CM01\Intune-Apps$\New-CMApp.ps1 -packagePath "Microsoft-BGInfo-4.26" -DistributionPointGroupName "PS1 Head Quarter DP Group 1" -SourceLocation "\\CM01\Intune-Apps$"

.PARAMETER 	packagePath 
Subfolder for the Application package.

.PARAMETER 	DistributionPointGroupName
DistributionPointGroupName

.PARAMETER 	SourceLocation
UNC Path on Server for the Sources

.NOTES
Author     : Fabian Niesen (www.fabian-niesen.de)
Filename   : New-CMApp.ps1
Requires   : PowerShell Version 3.0
Version    : 0.4
History    : 0.4   FN  22.03.2022  Bugfixes and some clean up
             0.3   FN  95.07.2021  Bugfixes and additional improvments - Thanks to Oliver Düsterhöft
             0.2   FN  28.06.2021  initial version
             
.LINK
https://github.com/InfrastructureHeroes/Intune-Apps

.KnownBugs / ToDo
- Only PS1 is supported now, MSI and EXE needs to be added
#>
[CmdLetBinding()]
param(
    [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true,
        ValueFromPipeline = $True,
        HelpMessage = 'Please enter path to package folder, containing Config.xml file'
    )]
    [Alias("PackageName")]
    [string[]] $packagePath,
    [Parameter(Mandatory = $false, Position = 2, ValueFromPipelineByPropertyName = $true,
        ValueFromPipeline = $True,
        HelpMessage = 'Please enter Distribution Point Group Name'
    )]
    [string] $DistributionPointGroupName = "Alle Server",
    [Parameter(Mandatory = $false, Position = 3, ValueFromPipelineByPropertyName = $true,
        ValueFromPipeline = $True,
        HelpMessage = 'Please enter UNC for IntuneApp Folder'
    )]
    [string] $SourceLocation = "\\sccm01-2019\Intune-Apps$\",
    [string] $SCCMServer = ([System.Net.Dns]::GetHostByName(($env:computerName))).Hostname,
    [string] $CollectionName = "All Systems"

)


####################################################
####################################################
#region Build Functions  - Based on Upload-IntuneWin.ps1
<#

.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.
Build Functions - Based on Upload-IntuneWin.ps1 - Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.

#>

####################################################

Function Start-Log {
    param (
        [string]$FilePath,

        [Parameter(HelpMessage = 'Deletes existing file if used with the -DeleteExistingFile switch')]
        [switch]$DeleteExistingFile
    )
    # Some improvements bei Oliver Düsterhöft
	Write-Verbose "Start-Log() - starting"
    Write-Verbose "Start-Log() - FilePath                   ='$FilePath'"
	Write-Verbose "Start-Log() - DeleteExistingFile         ='$DeleteExistingFile'"
    Write-Verbose "Start-Log() - logPath (Global)           ='$logPath'"
    Write-Verbose "Start-Log() - EventLogSource (Global)    ='$EventLogSource'"
    Write-Verbose "Start-Log() - ScriptLogFilePath (Script) ='$script:ScriptLogFilePath'"	
    #Create Event Log source if it's not already found...
    If (!([system.diagnostics.eventlog]::SourceExists($EventLogSource))) { New-EventLog -LogName $EventLogName -Source $EventLogSource }

    Try {
        If (!(Test-Path $logPath)) 
        { 
            Write-Verbose "Start-Log() - Create Log-Folder '$logPath'"
            New-Item $logPath -ItemType Directory 
        }
        else 
        { 
            Write-Verbose "Start-Log() - Log-Folder exists" 
        }
        If ($DeleteExistingFile) { 
            Write-Host "Start-Log() - Delete-Existing-File '$FilePath'  - if exists"
            If (Test-Path $FilePath  ) {
                Write-Verbose "Start-Log() - Delete-Existing-File '$FilePath'  - file found"
                Remove-Item $FilePath -Force
                If (!(Test-Path $FilePath)  ) { Write-Verbose "Start-Log() - Delete-Existing-File '$FilePath'  - file deleted" }                }
            }


        If (!(Test-Path $FilePath)  ) {
            Write-Verbose "Start-Log() - Create the log file '$FilePath'"
            New-Item $FilePath -Type File -Force | Out-Null
            }
        else { Write-Verbose "Start-Log() - Log-File exists" }

        ## Set the global variable to be used as the FilePath for all subsequent Write-Log
        ## calls in this session
        $script:ScriptLogFilePath = $FilePath
    }
    Catch {
        Write-Error $_.Exception.Message
    }
        Write-Verbose "Start-Log() - finished"
}

####################################################

Function Write-Log {
    #Write-Log -Message 'warning' -LogLevel 2
    #Write-Log -Message 'Error' -LogLevel 3
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
			
        [Parameter()]
        [ValidateSet(1, 2, 3)]
        [int]$LogLevel = 1,

        [Parameter(HelpMessage = 'Outputs message to Event Log,when used with -WriteEventLog')]
        [switch]$WriteEventLog
    )
    Write-Host
    Write-Host $Message
    Write-Host
    $TimeGenerated = "$(Get-Date -Format HH:mm:ss).$((Get-Date).Millisecond)+000"
    $Line = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="" type="{4}" thread="" file="">'
    $LineFormat = $Message, $TimeGenerated, (Get-Date -Format MM-dd-yyyy), "$($MyInvocation.ScriptName | Split-Path -Leaf):$($MyInvocation.ScriptLineNumber)", $LogLevel
    $Line = $Line -f $LineFormat
    Add-Content -Value $Line -Path $ScriptLogFilePath
    If ($WriteEventLog) { Write-EventLog -LogName $EventLogName -Source $EventLogSource -Message $Message  -Id 100 -Category 0 -EntryType Information }
}

####################################################

function IsNull($objectToCheck) {
    if ($objectToCheck -eq $null) {
        return $true
    }

    if ($objectToCheck -is [String] -and $objectToCheck -eq [String]::Empty) {
        return $true
    }

    if ($objectToCheck -is [DBNull] -or $objectToCheck -is [System.Management.Automation.Language.NullString]) {
        return $true
    }

    return $false
}


####################################################

Function Get-XMLConfig {
    <#
.SYNOPSIS
This function reads the supplied XML Config file
.DESCRIPTION
This function reads the supplied XML Config file
.EXAMPLE
Get-XMLConfig -XMLFile PathToXMLFile
This function reads the supplied XML Config file
.NOTES
NAME: Get-XMLConfig
#>

    [cmdletbinding()]

    param
    (
        [Parameter(Mandatory = $true)]
        [string]$XMLFile,
        [bool]$Skip = $false
    )

    Begin {
        Write-Log -Message "$($MyInvocation.InvocationName) function..."
    }

    Process {
        $dayDateTime = (Get-Date -UFormat "%A %d-%m-%Y %R")
        If (-Not(Test-Path $XMLFile)) {
            Write-Log -Message "Error - XML file not found: $XMLFile" -LogLevel 3
            Return $Skip = $true
        }
        Write-Log -Message "Reading XML file: $XMLFile"
        [xml]$script:XML_Content = Get-Content $XMLFile

        ForEach ($XMLEntity in $XML_Content.GetElementsByTagName("Azure_Settings")) {
            If (IsNull($Username)) {
                $script:Username = [string]$XMLEntity.Username
            }
            $script:baseUrl = [string]$XMLEntity.baseUrl
            $script:logRequestUris = [string]$XMLEntity.logRequestUris
            $script:logHeaders = [string]$XMLEntity.logHeaders
            $script:logContent = [string]$XMLEntity.logContent
            $script:azureStorageUploadChunkSizeInMb = [string]$XMLEntity.azureStorageUploadChunkSizeInMb
            $script:sleep = [int32]$XMLEntity.sleep
        }

        ForEach ($XMLEntity in $XML_Content.GetElementsByTagName("IntuneWin_Settings")) {
            If ($script:AADGroupName.Length -gt 50) {
                Write-Log -Message "Error - AAD group name longer than 50 chars. Shorten then retry."
                Exit
            }

            $script:AppType = [string]$XMLEntity.AppType
            If ( ( $AppType -eq "EXE" ) -or ( $AppType -eq "MSI" ) ) {
                Write-Log -Message "Reading commands for AppType: $AppType"
                $script:installCmdLine = [string]$XMLEntity.installCmdLine
                $script:uninstallCmdLine = [string]$XMLEntity.uninstallCmdLine
            }
            If ( $AppType -eq "Edge" ) {
                Write-Log -Message "Reading commands for AppType: $AppType"
                $script:displayName = [string]$XMLEntity.displayName
                $script:Description = [string]$XMLEntity.Description + "`nObject creation: $dayDateTime"
                $script:Publisher = [string]$XMLEntity.Publisher
                $script:Channel = [string]$XMLEntity.Channel
                $script:AADGroupName = [string]$XMLEntity.AADGroupName
                Return
            }
            $script:RuleType = [string]$XMLEntity.RuleType
            If ($RuleType -eq "FILE") {
                Write-Log -Message "Reading detection for RuleType: $RuleType"
                $script:FilePath = [string]$XMLEntity.FilePath
            }
            $script:ReturnCodeType = [string]$XMLEntity.ReturnCodeType
            $script:InstallExperience = [string]$XMLEntity.InstallExperience
            $script:PackageName = [string]$XMLEntity.PackageName
            $script:displayName = [string]$XMLEntity.displayName
            $script:Description = [string]$XMLEntity.Description + "`nObject creation: $dayDateTime"
            $script:Publisher = [string]$XMLEntity.Publisher
            $script:Category = [string]$XMLEntity.Category
            $script:LogoFile = [string]$XMLEntity.LogoFile
            $script:AADGroupName = [string]$XMLEntity.AADGroupName
            $script:Version = [string]$XMLEntity.Version
                               
            #Strip .ps1 extension, if entered into XML file...
            $lastFourChars = $PackageName.Substring($PackageName.Length - 4)
            If ($lastFourChars -eq ".ps1") { $script:PackageName = $PackageName.Substring(0, $PackageName.Length - 4) }
        }

    }

    End {
        If ($Skip) { Return }# Just return without doing anything else
        Write-Log -Message "Returning..."
        Return
    }

}
####################################################
#>


#endregion Build Functions  - Based on Upload-IntuneWin.ps1
##########################################################################################################
$runpath = Get-Location
IF ( $packagePath.StartsWith(".\") ) { $packagePath = $packagePath.TrimStart(".\") }
IF ( $packagePath.EndsWith("\") )    { $packagePath = $packagePath.TrimEnd("\") }
$ScriptName = $myInvocation.MyCommand.Name
$ScriptName = $ScriptName.Substring(0, $ScriptName.Length - 4)
Write-Verbose "ScriptName  : $ScriptName"
#$ScriptSource = $myInvocation.MyCommand.Source.Substring(0, $ScriptName.Length + 5)
$ScriptSource = $PSScriptRoot
Write-Verbose "ScriptSource: $ScriptSource"
$rundate = Get-Date -format yyyyMMdd-HHmm
$LogName = $ScriptName + "_" + $packagePath + "_" + $rundate
#$logPath = "$($env:LocalAppData)\Microsoft\Temp\IntuneApps\$ScriptName"
#$logPath = "$($env:ProgramData)\Microsoft\IntuneApps\$ScriptName" 
$logPath = $ScriptSource + "\_Logs"
$logFile = "$logPath\$LogName.log"
Write-Host "LogFile     : $logFile"
$script:EventLogName = "Application"
$script:EventLogSource = "EventSystem"
Start-Log -FilePath $logFile 
Write-Host "Script log file path is [$logFile]" -f Cyan
Write-Log -Message "Starting $ScriptName version $BuildVer" -WriteEventLog
If ( ! ( Test-Path ("FileSystem::$SourceLocation\$packagePath") ) ) { Write-Log -Message ("MAIN() - Error - path not valid: " + $SourceLocation + "\" + $packagePath)  ; Exit }
Get-XMLConfig -XMLFile ("FileSystem::$SourceLocation\$packagePath\Config.xml")
If ( $script:AppType -notlike "PS1") { Write-Log -Message "Actual is only PS1 Deploments from Intune-Scripts supported, but feel free to commit a change to GitHub ;)" -LogLevel 3 ; Exit }
IF (!(get-psdrive -PSProvider CMSite)) 
{
    Write-Log -Message "Import-Module ConfigurationManager"
    #Import-Module ConfigurationManager
    Import-Module "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1" -Verbose:$false
    New-PSDrive -Name "SCCM" -PSProvider "AdminUI.PS.Provider\CMSite" -Root $SCCMServer -Description "Primary site"
}
Set-Location $(((get-psdrive -PSProvider CMSite).Name) + ":")
$site = $(Get-CMSite).SiteCode
Write-Log -Message "CM SiteCode: $site"
IF ( $(Get-CMDistributionPointGroup -Name $DistributionPointGroupName ).count -ne 1 ) 
{ 
    Write-Log -Message "Error - DistributionPointGroupName not valid: DistributionPointGroupName"
    Exit 
}

$PackageName = $script:PackageName
$InstallCommand = 'Powershell.exe -ExecutionPolicy ByPass -File "' + $PackageName + '.ps1" -install'
$UninstallCommand = 'Powershell.exe -ExecutionPolicy ByPass -File "' + $PackageName + '.ps1" -uninstall'
$RebootBehavior = "NoAction"
Write-Log -Message "Setting detection clauses"
$clause1 = New-CMDetectionClauseRegistryKeyValue -Hive LocalMachine -KeyName "SOFTWARE\Microsoft\IntuneApps" -PropertyType String -ValueName "$PackageName" -Value -ExpectedValue "Installed" -ExpressionOperator Contains
$clause2 = New-CMDetectionClauseRegistryKeyValue -Hive CurrentUser -KeyName "SOFTWARE\Microsoft\IntuneApps" -PropertyType String -ValueName "$PackageName" -Value -ExpectedValue "Installed" -ExpressionOperator Contains
$clause3 = New-CMDetectionClauseFile -FileName $($PackageName + ".tag") -Path "%PROGRAMDATA%\Microsoft\IntuneApps\$PackageName" -Existence
$clause4 = New-CMDetectionClauseFile -FileName $($PackageName + ".tag") -Path "%LOCALAPPDATA%\Microsoft\IntuneApps\$PackageName" -Existence
#$clause1,$clause2,$clause3,$clause4 | FT -AutoSize
IF ($SourceLocation.EndsWith("\") -like "False") { $SourceLocation =$SourceLocation+"\" }
$ContentLocation = $SourceLocation + $packagePath + "\source\"
Write-Verbose "PackageName: $PackageName"
Write-Log -Message  "InstallCommand: $InstallCommand"
Write-Log -Message  "UninstallCommand: $UninstallCommand"
Write-Log -Message "New-CMApplication $PackageName"

IF ( ! ( Get-CMApplication -Name $PackageName  )) #Detect different version is missing#
    {
    IF ( IsNull($script:Version) ) 
    { 
        New-CMApplication -Name $PackageName -Description $script:Description -AutoInstall $true -Publisher $script:Publisher -ReleaseDate $(Get-Date)  | Format-Table -Property LocalizedDisplayName,DateLastModified -AutoSize  
    }
    ELSE 
    { 
        New-CMApplication -Name $PackageName -Description $script:Description -AutoInstall $true -Publisher $script:Publisher -ReleaseDate $(Get-Date) -SoftwareVersion $script:Version  | Format-Table -Property LocalizedDisplayName,DateLastModified -AutoSize  
    }
    $app = Get-CMApplication -Name $PackageName
    IF ( ! (Test-Path $($site + ":\Application\Intune-Apps")) ) 
        { 
            Write-Log -Message "Ceate CM Application folder for Intune-Apps"
            New-Item -Path $($site + ":\Application\Intune-Apps") 
        }
    Move-CMObject -FolderPath $($site + ":\Application\Intune-Apps") -InputObject $app
    } 
    Else 
    { 
        Write-Log -Message "CMApplication $PackageName already exists - Skip Creation" -LogLevel 2 
    } 

    $DeploymentTypeName = "Install " + $PackageName

    IF ( ! ( Get-CMDeploymentType -ApplicationName $PackageName | Where-Object { $_.LocalizedDisplayName -like $DeploymentTypeName }  )) {
    If ( $script:AppType -like "PS1")
    {
        Write-Log -Message "Add-CMScriptDeploymentType $DeploymentTypeName"
        Add-CMScriptDeploymentType -ApplicationName $PackageName -DeploymentTypeName $DeploymentTypeName -InstallCommand $InstallCommand -LogonRequirementType WhetherOrNotUserLoggedOn -MaximumRuntimeMins 15 -UninstallCommand $UninstallCommand -RebootBehavior $RebootBehavior -AddDetectionClause $clause1,$clause2,$clause3,$clause4  -DetectionClauseConnector @{"LogicalName"=$clause1.Setting.LogicalName;"Connector"="OR"},@{"LogicalName"=$clause2.Setting.LogicalName;"Connector"="OR"},@{"LogicalName"=$clause3.Setting.LogicalName;"Connector"="OR"},@{"LogicalName"=$clause4.Setting.LogicalName;"Connector"="OR"} -ContentLocation $ContentLocation -InstallationBehaviorType InstallForSystem -SlowNetworkDeploymentMode Download -UserInteractionMode Normal -ContentFallback -EstimatedRuntimeMins 15 | Format-Table -Property LocalizedDisplayName,Technology -AutoSize
    } ELSE {
        Write-Log -Message "CMScriptDeploymentType $PackageName already exists - Skip Creation" -LogLevel 2 }
    }
    ### Add other Deployment Types here ###    
    Write-Log -Message "New-CMApplicationDeployment for $PackageName"
    IF ( ! ( Get-CMApplicationDeployment -Name $PackageName -CollectionName $CollectionName )) 
    {
        New-CMApplicationDeployment -CollectionName "$CollectionName" -Name "$PackageName" -DeployAction Install -DeployPurpose Available -UserNotification DisplayAll -AvailableDateTime (get-date) -TimeBaseOn LocalTime -DistributeContent -DistributionPointGroupName $DistributionPointGroupName |  Format-Table -Property ApplicationName,Enabled,StartTime
    } 
    ELSE 
    {
        Write-Log -Message "CMApplicationDeployment $PackageName already exists - Skip Creation" -LogLevel 2
    }

Set-Location $runpath
#Remove-PSDrive -Name $site -PSProvider "AdminUI.PS.Provider\CMSite" 
