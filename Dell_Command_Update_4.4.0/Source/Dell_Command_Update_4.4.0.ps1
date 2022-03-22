#region Initialisation...
<#

.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.

#>
####################################################
####################################################
#Instantiate Vars
####################################################
[CmdLetBinding()]
param(
    [Parameter()]
    [switch] $install,
    [switch] $unInstall,
    [switch] $userInstall,
    [string] $tagFile,
    [switch] $regTag
)
#$VerbosePreference = "Continue" #Enables Verbose Logging, can be enabled with -verbose on the cmdline too
$script:exitCode = 0

#Restart as 64-bit
if (![System.Environment]::Is64BitProcess) {
    $additionalArgs = ''
    foreach($Param in $PSBoundParameters.GetEnumerator())
    {
        if(-not $MyInvocation.MyCommand.Parameters[$Param.key].SwitchParameter)
        {
            $additionalArgs += "-$($Param.Key) $($Param.Value) "
        }
        else
        {
            $additionalArgs += "-$($Param.Key) "
        }
    }

    # start new PowerShell as x64 bit process, wait for it and gather exit code and standard error output
    $sysNativePowerShell = "$($PSHOME.ToLower().Replace("syswow64", "sysnative"))\powershell.exe"

    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $sysNativePowerShell
    $pinfo.Arguments = "-ex bypass -file `"$PSCommandPath`" $additionalArgs"
    $pinfo.RedirectStandardError = $true
    #$pinfo.RedirectStandardOutput = $true
    $pinfo.CreateNoWindow = $true
    
    #$pinfo.RedirectStandardError = $false
    #$pinfo.RedirectStandardOutput = $false
    #$pinfo.CreateNoWindow = $false
    
    $pinfo.UseShellExecute = $false
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null

    $exitCode = $p.ExitCode

    $stderr = $p.StandardError.ReadToEnd()
    $p.WaitForExit()

    if ($stderr) { Write-Error -Message $stderr }
}
Else {

$script:BuildVer = "1.1"
$script:ProgramFiles = $env:ProgramFiles
$script:ParentFolder = $PSScriptRoot | Split-Path -Parent
$script:ScriptName = $myInvocation.MyCommand.Name
$script:ScriptName = $scriptName.Substring(0, $scriptName.Length - 4)
$script:LogName = $scriptName + "_" + (Get-Date -UFormat "%d-%m-%Y")
If ( $userInstall ) {
    $script:logPath = "$($env:LOCALAPPDATA)\Microsoft\IntuneApps\$scriptName"
}
Else { 
    $script:logPath = "$($env:ProgramData)\Microsoft\IntuneApps\$scriptName" 
}
$script:logFile = "$logPath\$LogName.log"
Add-Type -AssemblyName Microsoft.VisualBasic
$script:EventLogName = "Application"
$script:EventLogSource = "EventSystem"
If ($VerbosePreference -eq 'Continue') {Start-Transcript -Path "$logPath\Transcript.log" -Append}
####################################################
####################################################
#Build Functions
####################################################

Function Start-Log {
    param (
        [string]$FilePath,

        [Parameter(HelpMessage = 'Deletes existing file if used with the -DeleteExistingFile switch')]
        [switch]$DeleteExistingFile
    )
		
    #Create Event Log source if it's not already found...
    if ([System.Diagnostics.EventLog]::Exists($script:EventLogName) -eq $false) {
            New-EventLog -LogName $EventLogName -Source $EventLogSource
        }
    if ([System.Diagnostics.EventLog]::SourceExists($script:EventLogSource ) -eq $false) {
            [System.Diagnostics.EventLog]::CreateEventSource($script:EventLogSource , $EventLogName)
        }
    #If (!([system.diagnostics.eventlog]::SourceExists($EventLogSource))) { New-EventLog -LogName $EventLogName -Source $EventLogSource }

    Try {
        If (!(Test-Path $FilePath)) {
            ## Create the log file
            New-Item $FilePath -Type File -Force | Out-Null
        }
            
        If ($DeleteExistingFile) {
            Remove-Item $FilePath -Force
        }
			
        ## Set the global variable to be used as the FilePath for all subsequent Write-Log
        ## calls in this session
        $script:ScriptLogFilePath = $FilePath
    }
    Catch {
        Write-Error $_.Exception.Message
    }
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

Function New-IntuneTag {
    <#
    .SYNOPSIS
    .DESCRIPTION
    .EXAMPLE
    .PARAMETER
    .INPUTS
    .OUTPUTS
    .NOTES
    .LINK
#>
    Param (
        [string]$TagFilePath = "$($env:ProgramData)\Microsoft\IntuneApps\$scriptName\",
        [string]$tagName
    )
              
    Begin {
        Write-Log -Message "Starting $($MyInvocation.InvocationName) function..."
    }

    Process {
        # Create a tag file just so Intune knows this was installed
        Write-Log "Creating Intune Tag file path: [$TagFilePath]"

        If (-not (Test-Path $TagFilePath) ) {

            New-Item -Path $TagFilePath -ItemType "directory" -Force | out-null
        }

        # Check if tagName already has .tag at the end
        If ($tagName.Substring(($tagName.Length - 4), 4) -eq ".tag") {
            Write-Log -Message "Using passed in tagName: $tagName"
            $tagFileName = "$TagFilePath\$tagName"
        }
        Else {
            Write-Log -Message "Using default of scriptname: $tagName and appending .tag"
            $tagFileName = "$TagFilePath\$tagName.tag"
        }
        
        Write-Log "Creating Intune Tag file: [$tagFileName]"
                       
        Set-Content -Path $tagFileName -Value "Installed"

        Write-Log -Message "Created Intune Tag file: [$tagFileName]"
                
    }
}

####################################################

Function Remove-IntuneTag {
    <#
    .SYNOPSIS
    .DESCRIPTION
    .EXAMPLE
    .PARAMETER
    .INPUTS
    .OUTPUTS
    .NOTES
    .LINK
#>
    Param (
        [string]$TagFilePath = "$($env:ProgramData)\Microsoft\IntuneApps\$scriptName\",
        [string]$tagName
    )
              
    Begin {
        Write-Log -Message "Starting $($MyInvocation.InvocationName) function..."
    }

    Process {
        # Remove the tag file so Intune knows this was uninstalled
        # Check if tagName already has .tag at the end
        If ($tagName.Substring(($tagName.Length - 4), 4) -eq ".tag") {
            Write-Log -Message "Using passed in tagName: $tagName"
            $tagFileName = "$TagFilePath\$tagName"
        }
        Else {
            Write-Log -Message "Using default of scriptname: $tagName and appending .tag"
            $tagFileName = "$TagFilePath\$tagName.tag"
        }
        
        Write-Log "Removing Intune Tag file: [$tagFileName]"
        
        If (Test-Path $tagFileName) {
            Remove-Item -Path $tagFileName -Force
        }

    }
}

####################################################

Function New-IntuneRegTag {
    <#
    .SYNOPSIS
    .DESCRIPTION
    .EXAMPLE
    .PARAMETER
    .INPUTS
    .OUTPUTS
    .NOTES
    .LINK
#>
    Param (
        [string]$TagRegPath = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\IntuneApps\",
        [string]$tagName
    )
              
    Begin {
        Write-Log -Message "Starting $($MyInvocation.InvocationName) function..."
    }

    Process {
        # Create a registry tag just so Intune knows this was installed
        Write-Log "Creating Intune Tag file path: [$TagRegPath\$tagName]"

        #Get-ItemProperty -Path "HKLM:\SOFTWARE\$TagRegPath" -Name $tagName

        New-Item -Path "Registry::$TagRegPath" -Force

        $returnCode = New-ItemProperty -Path "Registry::$TagRegPath" -Name $tagName -PropertyType String -Value "Installed" -Force
        Write-Log -Message "Return code: $returnCode" 
    }
}

####################################################

Function Remove-IntuneRegTag {
    <#
    .SYNOPSIS
    .DESCRIPTION
    .EXAMPLE
    .PARAMETER
    .INPUTS
    .OUTPUTS
    .NOTES
    .LINK
#>
    Param (
        [string]$TagRegPath = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\IntuneApps\",
        [string]$tagName
    )
              
    Begin {
        Write-Log -Message "Starting $($MyInvocation.InvocationName) function..."
    }

    Process {
        # Remove registry tag just so Intune knows this was uninstalled
        Write-Log "Removing Intune Tag file path: [$TagRegPath\$tagName]"
        
        $returnCode = Remove-ItemProperty -Path "Registry::$TagRegPath" -Name $tagName -Force
        Write-Log -Message "Return code: $returnCode"
    }
}

####################################################

Function New-RegKey {
    param($key)
  
    $key = $key -replace ':', ''
    $parts = $key -split '\\'
  
    $tempkey = ''
    $parts | ForEach-Object {
        $tempkey += ($_ + "\")
        if ( (Test-Path "Registry::$tempkey") -eq $false) {
            New-Item "Registry::$tempkey" | Out-Null
        }
    }
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
            
        If (-Not(Test-Path $XMLFile)) {
            Write-Log -Message "Error - XML file not found: $XMLFile" -LogLevel 3
            Return $Skip = $true
        }
        Write-Log -Message "Reading XML file: $XMLFile"
        [xml]$script:XML_Content = Get-Content $XMLFile

        ForEach ($XMLEntity in $XML_Content.GetElementsByTagName("Azure_Settings")) {
            $script:baseUrl = [string]$XMLEntity.baseUrl
            $script:logRequestUris = [string]$XMLEntity.logRequestUris
            $script:logHeaders = [string]$XMLEntity.logHeaders
            $script:logContent = [string]$XMLEntity.logContent
            $script:azureStorageUploadChunkSizeInMb = [int32]$XMLEntity.azureStorageUploadChunkSizeInMb
            $script:sleep = [int32]$XMLEntity.sleep
        }

        ForEach ($XMLEntity in $XML_Content.GetElementsByTagName("IntuneWin_Settings")) {
            $script:PackageName = [string]$XMLEntity.PackageName
            $script:displayName = [string]$XMLEntity.displayName
            $script:Description = [string]$XMLEntity.Description
            $script:Publisher = [string]$XMLEntity.Publisher
        }

    }

    End {
        If ($Skip) { Return }# Just return without doing anything else
        Write-Log -Message "Returning..."
        Return
    }

}

####################################################

Function Show-PWPromptForm {
    <#
.SYNOPSIS
This function shows a password prompt form
.DESCRIPTION
This function shows a password prompt form
.EXAMPLE
Show-PWPromptForm -promptMsg "Enter your network password"
This function shows a password prompt form
.NOTES
NAME: Show-PWPromptForm
#>

    [cmdletbinding()]

    param
    (
        [Parameter(Mandatory = $true)]
        [string]$promptTitle,

        [Parameter(Mandatory = $true)]
        [string]$promptMsg
    )

    Begin {
        Write-Log -Message "$($MyInvocation.InvocationName) function..."
    }

    Process {
            
        <# Build Form #>
        Write-Log -Message "Preparing form."

        # Bring in the Windows Forms Library 
        Add-Type -assembly System.Windows.Forms

        # Generate the form 
        $Form = New-Object System.Windows.Forms.Form

        # Window Font 
        $Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)

        # Font styles are: Regular, Bold, Italic, Underline, Strikeout
        $Form.Font = $Font

        # Window Basics
        $Form.Text = $promptTitle
        $Form.Width = 350
        $Form.Height = 300
        $Form.AutoSize = $true
        $Form.MinimizeBox = $False
        $Form.MaximizeBox = $False
        $Form.ControlBox = $True
        $Form.WindowState = "Normal"
        # Maximized, Minimized, Normal
        $Form.SizeGripStyle = "Hide"
        # Auto, Hide, Show
        $Form.ShowInTaskbar = $False
        $Form.Opacity = 1.0
        # 1.0 is fully opaque; 0.0 is invisible
        $Form.StartPosition = "CenterScreen"
        $Form.TopMost = $True
        # CenterScreen, Manual, WindowsDefaultLocation, WindowsDefaultBounds, CenterParent

        <# Header Text #>

        # Create the label
        $lbl_HeaderText = New-Object System.Windows.Forms.Label

        # Create Instruction String 
        $lbl_InstructionString = $promptMsg

        # Label Basics 
        $lbl_HeaderText.Text = $lbl_InstructionString
        $lbl_HeaderText.Location = New-Object System.Drawing.Point(10, 10)
        $lbl_HeaderText.AutoSize = $true

        # Add to form 
        $Form.Controls.Add($lbl_HeaderText)

        # Create the label
        $lbl_TxbHeader1 = New-Object System.Windows.Forms.Label

        # Label Basics 
        $lbl_TxbHeader1.Text = "Enter Password"
        $lbl_TxbHeader1.Location = New-Object System.Drawing.Point(20, 70)
        $lbl_TxbHeader1.AutoSize = $true

        # Add to form 
        $Form.Controls.Add($lbl_TxbHeader1)

        # Create the label
        $lbl_TxbHeader2 = New-Object System.Windows.Forms.Label

        # Label Basics 
        $lbl_TxbHeader2.Text = "Repeat Password"
        $lbl_TxbHeader2.Location = New-Object System.Drawing.Point(20, 130)
        $lbl_TxbHeader2.AutoSize = $true

        # Add to form 
        $Form.Controls.Add($lbl_TxbHeader2)

        # Create the label
        $lbl_FeedbackMsg = New-Object System.Windows.Forms.Label

        # Label Basics 
        $lbl_FeedbackMsg.Text = "Passwords Do Not Match"
        $lbl_FeedbackMsg.ForeColor = "Red"
        $lbl_FeedbackMsg.Location = New-Object System.Drawing.Point(20, 230)
        $lbl_FeedbackMsg.AutoSize = $true
        $lbl_FeedbackMsg.Visible = $false

        # Add to form 
        $Form.Controls.Add($lbl_FeedbackMsg)

        <# Text Boxes #>

        # Create Pw Box 1
        $txb_PwEnter1 = New-Object System.Windows.Forms.MaskedTextBox

        # Set Params
        $txb_PwEnter1.Width = 200
        $txb_PwEnter1.Height = 50 
        $txb_PwEnter1.Location = New-Object System.Drawing.Point(20, 95)
        $txb_PwEnter1.PasswordChar = '*'

        # Add to Form 
        $Form.Controls.Add($txb_PwEnter1)

        # Create Pw Box 2
        $txb_PwEnter2 = New-Object System.Windows.Forms.MaskedTextBox

        # Set Params
        $txb_PwEnter2.Width = 200
        $txb_PwEnter2.Height = 50 
        $txb_PwEnter2.Location = New-Object System.Drawing.Point(20, 155)
        $txb_PwEnter2.PasswordChar = '*'

        # Add to Form 
        $Form.Controls.Add($txb_PwEnter2)

        <# Buttons #>

        # Create a button
        $btn_InstallPrinters = New-Object System.Windows.Forms.Button

        # Button basics
        $btn_InstallPrinters.Location = New-Object System.Drawing.Size(20, 200)
        $btn_InstallPrinters.Size = New-Object System.Drawing.Size(150, 25)
        $btn_InstallPrinters.Text = "Install Printers"
        #$btn_InstallPrinters.DialogResult = [System.Windows.Forms.DialogResult]::OK
        
        $Form.AcceptButton = $btn_InstallPrinters

        # Set Function Handler
        $btn_InstallPrinters.Add_Click( {

                # Set Error Conditions 
                $InputErrorPresent = $false 
                $InputErrorMessage = "Unspecified Input Error"
    
                # Check if the PWs Match 
                if ($txb_PwEnter1.Text -ne $txb_PwEnter2.Text) {
                    # Set Error Conditions 
                    $InputErrorPresent = $true
                    $InputErrorMessage = "Entered Passwords do not match"

                    Write-Log -Message "User entered mismatched Passwords"
                }

                # Check if 1st PW box empty
                if ( IsNull ( $txb_PwEnter1.Text ) ) {
                    # Set Error Conditions 
                    $InputErrorPresent = $true
                    $InputErrorMessage = "Enter your password"

                    Write-Log -Message "1st PW box empty"
                }
    
                # Check if the error flag has been set 
                if ($InputErrorPresent) {
                    # Set and show error 
                    $lbl_FeedbackMsg.Text = $InputErrorMessage
                    $lbl_FeedbackMsg.Visible = $true

                    Write-Log -Message "Button clicked, but error message shown"

                    Return

                }
                else { 
                    # Clear Error Message 
                    $lbl_FeedbackMsg.Visible = $false 

                    Write-Log -Message "Passwords entered correctly"

                }

                Write-Log -Message "Returning with password string"
                $Script:pw = $txb_PwEnter1.Text

                # Now Close the form 
                $Form.Close()

                Return
                
            })

        # Add to Form 
        $Form.Controls.Add($btn_InstallPrinters)

        <# Show the Form #>
        Write-Log -Message "Form onscreen"
        #Set-Content -Path "C:\Windows\Temp\PPForm.tag" -Value "Running..."
        $Form.ShowDialog()

    }
}

####################################################

Function Is-VM {
<#
.SYNOPSIS
This function checks WMI to determine if the device is a VM
.DESCRIPTION
This function checks WMI to determine if the device is a VM
.EXAMPLE
Is-VM
This function checks WMI to determine if the device is a VM
.NOTES
NAME: Is-VM
#>

    [CmdletBinding()]
    Param ()
    
    Begin {
        Write-Log -Message "$($MyInvocation.InvocationName) function..."
    }

    Process
    {
        Write-Log -Message "Checking WMI class: Win32_ComputerSystem for string: *virtual*"
        Try {
            $ComputerSystemInfo = Get-CIMInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
            #$ComputerSystemInfo
            if ($ComputerSystemInfo.Model -like "*virtual*") {
                Write-Log -Message "Virtual string detected"
                $True
            }
            else {
                Write-Log -Message "Virtual string not found"          
                $False
            }
        }
        Catch [Exception] {
            Write-Log -Message "Error occurred: $($_.Exception.message)"
            Write-Warning "$($env:computername.ToUpper()) : $($_.Exception.message)"
        }
    }

    End {
        Write-Log -Message "Ending: $($MyInvocation.Mycommand)"
    }
}

####################################################

Function Install-Hotfix {
<#
.SYNOPSIS
This function installs the specified Hotfix
.DESCRIPTION
This function installs the specified Hotfix
.EXAMPLE
Install-Hotfix -HotFixID KBxxxxxx.msu
This function installs the specified Hotfix
.NOTES
NAME: Install-Hotfix
#>

    [CmdletBinding()]
    Param (

        [Parameter(Mandatory = $true)]
        [string]$HotFixID

        )
    
    Begin {
        Write-Log -Message "$($MyInvocation.InvocationName) function..."
    }

    Process
    {
        If (get-hotfix | Where-Object {$_.HotFixID -match $HotFixID}) {
            Write-Log -Message "Hotfix: $HotFixID already installed, returning."
            Return "Installed"
        }
        Write-Log -Message "Running Hotfix install for: wusa.exe ""$PSScriptRoot\$HotFixID"" /quiet /norestart /log:""$logPath\wusa.evtx"""
        Try {
            Start-Process -FilePath "wusa.exe" -ArgumentList """$PSScriptRoot\$HotFixID"" /quiet /norestart /log:""$logPath\wusa.evtx""" -WorkingDirectory "$PSScriptRoot" -Wait -WindowStyle Hidden -ErrorAction Stop
        }
        Catch {
            Write-Log -Message "Error occurred deploying Hotfix: $($_.Exception.message)"
            Write-Warning "$($env:computername.ToUpper()) : $($_.Exception.message)"
            Return "Failed"
        }

        <#
        If (get-hotfix | Where-Object {$_.HotFixID -match $HotFixID}) {
            Write-Log -Message "Hotfix: $HotFixID successfully installed."
            Return "Installed"
        }
        Else {
            Write-Log -Message "Error - something went wrong installing Hotfix: $HotFixID"
            Return "Failed"
        }
        #>
    }

    End {
        Write-Log -Message "Ending: $($MyInvocation.Mycommand)"
    }
}

####################################################
<#

.COPYRIGHT
Copyright (c) for Install and Uninstall commands & logic by Fabian Niesen
https://github.com/FabianNiesen/

#>

Start-Log -FilePath $logFile -DeleteExistingFile
Write-Host
Write-Host "Script log file path is [$logFile]" -ForegroundColor Cyan
Write-Host
Write-Log -Message "Starting $ScriptName version $BuildVer" -WriteEventLog
Write-Log -Message "Running from location: $PSScriptRoot" -WriteEventLog
Write-Log -Message "Script log file path is [$logFile]" -WriteEventLog
Write-Log -Message "Running in 64-bit mode: $([System.Environment]::Is64BitProcess)"


If ($Install) {
    Write-Log -Message "Performing Install steps..."
    Push-Location $(Split-Path $Script:MyInvocation.MyCommand.Path)
    # Known MSI IDs
    # Dell Update for Windows 10 {41D2D254-D869-4CD8-B440-5DF49083C4BA}
    # Dell Command | Update for Windows 10 {4CCADC13-F3AE-454F-B724-33F6D4E52022}
    # Dell Command | Update {4CD85DD3-A024-4409-A0F2-F70DE1E4A935} - Normal App
    $MSIGUIDs = get-wmiobject Win32_Product | Where-Object { $_.Name -like "Dell Command*Update*" -or $_.Name -like "Dell Update for*" }
    IF (! (IsNull($MSIGUIDs) ) )
    {
        Write-Log "Found the following products:
        $($MSIGUIDs.Name) - $($MSIGUIDs.IdentifyingNumber)"
        Write-Log "Stopping DellClientManagementService if running"
        Stop-Service "DellClientManagementService" -Force -ErrorAction SilentlyContinue
        foreach ( $MSIGUID in $MSIGUIDs )
        {  
            IF ( ! ($MSIGUID.IdentifyingNumber -like "{4CD85DD3-A024-4409-A0F2-F70DE1E4A935}")) 
            { 
                Write-Log "Remove MSI: $($MSIGUID.Name) - $($MSIGUID.IdentifyingNumber) "
                $MSIGUID.Uninstall()
                #Start-Process -NoNewWindow -FilePath "msiexec.exe" -ArgumentList " /x $MSIGUID /q REMOVE=ALL REBOOT=ReallySuppress" -Wait 
                Start-Sleep -Seconds 30
            } 
        }
    }
    Write-Log "Remove AppxPackage if found some"
    get-AppxPackage *DellCommandUpdate* -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*dell*Update*" }  | Remove-AppxProvisionedPackage -online -ErrorAction SilentlyContinue

    $exe = "./" + $(Get-ChildItem Dell-Command-Update-Application*.exe | Sort-Object -Property LastWriteTime -Descending)[0].Name
    $iargs = " /s"
    Write-Output "Lunch $exe with the following Args: $iargs "
    Start-Process -NoNewWindow -FilePath $exe -ArgumentList $iargs -Wait
    IF (Test-Path "config.bat" ) { Start-Process -NoNewWindow -FilePath ".\config.bat" -Wait } 
    
    #Handle Intune detection method
    If (! ($userInstall) ) {
            Write-Log -Message "Creating detection rule for System install"

            If ( $regTag ) {
                Write-Log -Message "Using RegTag: HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\IntuneApps\$ScriptName"
                New-IntuneRegTag -TagRegPath "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\IntuneApps" -tagName $ScriptName
            }
            Else {
                Write-Log -Message "Using FileTag"
                
                If ( ! ( IsNull ( $tagFile ) ) ) {
                    Write-Log -Message "Using tagFile name: $tagFile"
                    New-IntuneTag -TagFilePath "$logPath" -tagName $tagFile
                }
                Else { 
                    Write-Log -Message "Using default tagFile name: $scriptName"
                    New-IntuneTag -TagFilePath "$logPath" -tagName $scriptName 
                }
            }
        }
    ElseIf ( $userInstall ) {
            Write-Log -Message "Creating detection rule for User install"

            If ( $regTag ) {
                Write-Log -Message "Using RegTag: HKEY_CURRENT_USER\SOFTWARE\Microsoft\IntuneApps\$ScriptName"
                New-IntuneRegTag -TagRegPath "HKEY_CURRENT_USER\SOFTWARE\Microsoft\IntuneApps" -tagName $ScriptName
            }
            Else {
                Write-Log -Message "Using FileTag: "
                
                If ( ! ( IsNull ( $tagFile ) ) ) {
                    Write-Log -Message "Using tagFile name: $tagFile"
                    New-IntuneTag -TagFilePath "$logPath" -tagName $tagFile
                }
                Else { 
                    Write-Log -Message "Using default tagFile name: $scriptName"
                    New-IntuneTag -TagFilePath "$logPath" -tagName $scriptName 
                }
            } 
        }
}
ElseIf ( $UnInstall ) {
    Write-Log -Message "Performing Uninstall steps..."
    $MSIGUIDs = get-wmiobject Win32_Product | Where-Object { $_.Name -like "Dell Command*Update*" -or $_.Name -like "Dell Update for*" }
    Write-Log "Found the following products:
    $($MSIGUIDs.Name) - $($MSIGUIDs.IdentifyingNumber)"
    Write-Log "Stopping DellClientManagementService if running"
    Stop-Service "DellClientManagementService" -Force -ErrorAction SilentlyContinue
    foreach ( $MSIGUID in $MSIGUIDs )
    {  
        Write-Log "Remove MSI: $($MSIGUID.Name) - $($MSIGUID.IdentifyingNumber) "
        $MSIGUID.Uninstall()
        #Start-Process -NoNewWindow -FilePath "msiexec.exe" -ArgumentList " /x $MSIGUID /q" -Wait 
        Start-Sleep -Seconds 30 
    }
    get-AppxPackage *DellCommandUpdate* -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*dell*Update*" }  | Remove-AppxProvisionedPackage -online -ErrorAction SilentlyContinue


    #Handle Intune detection method
    If (! ($userInstall) ) {
            Write-Log -Message "Removing detection for System install"

            If ( $regTag ) {
                Write-Log -Message "Removing RegTag: HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\IntuneApps\$ScriptName"
                Remove-IntuneRegTag -TagRegPath "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\IntuneApps" -tagName $ScriptName
            }
            Else {
                Write-Log -Message "Removing FileTag"
                
                If ( ! ( IsNull ( $tagFile ) ) ) {
                    Write-Log -Message "Removing tagFile name: $tagFile"
                    Remove-IntuneTag -TagFilePath "$logPath" -tagName $tagFile
                }
                Else { 
                    Write-Log -Message "Removing default tagFile name: $scriptName"
                    Remove-IntuneTag -TagFilePath "$logPath" -tagName $scriptName 
                }
            }
        }
    ElseIf ( $userInstall ) {
            Write-Log -Message "Removing detection for User install"

            If ( $regTag ) {
                Write-Log -Message "Removing RegTag: HKEY_CURRENT_USER\SOFTWARE\Microsoft\IntuneApps\$ScriptName"
                Remove-IntuneRegTag -TagRegPath "HKEY_CURRENT_USER\SOFTWARE\Microsoft\IntuneApps" -tagName $ScriptName
            }
            Else {
                Write-Log -Message "Removing FileTag: "
                
                If ( ! ( IsNull ( $tagFile ) ) ) {
                    Write-Log -Message "Removing tagFile name: $tagFile"
                    Remove-IntuneTag -TagFilePath "$logPath" -tagName $tagFile
                }
                Else { 
                    Write-Log -Message "Removing default tagFile name: $scriptName"
                    Remove-IntuneTag -TagFilePath "$logPath" -tagName $scriptName 
                }
            } 
        }
}


Write-Log "$ScriptName completed." -WriteEventLog
If ($VerbosePreference -eq 'Continue') {Stop-Transcript}
exit $exitCode

##########################################################################################################
##########################################################################################################
#endregion Main Script work section
}