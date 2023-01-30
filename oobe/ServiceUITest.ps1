# iex (irm https://raw.githubusercontent.com/everydayintech/OSDCloud-Public/main/oobe/ServiceUITest.ps1); Restart-Computer -Force

Start-Transcript -Path 'C:\OSDCloud\temp\ServiceUITest.log' -Append

Import-Module OSD


#=======================================================================
# retry shortcut for debugging
#=======================================================================

$retrycmd = @"
start /wait Powershell -ExecutionPolicy Bypass -Command "iex (irm https://raw.githubusercontent.com/everydayintech/OSDCloud-Public/main/oobe/ServiceUITest.ps1); Restart-Computer -Force"
"@

$retrycmd | Out-File -FilePath 'C:\Windows\System32\retry.cmd' -Encoding ascii -Force


#=======================================================================
# Download ServiceUI64.exe
#=======================================================================

Save-WebFile `
    -SourceUrl 'https://raw.githubusercontent.com/everydayintech/OSDCloud-Public/main/raw/ServiceUI64.exe' `
    -DestinationName 'ServiceUI64.exe' `
    -DestinationDirectory 'C:\OSDCloud\temp' -Overwrite


#=======================================================================
# Create and register scheduled task on boot
#=======================================================================
Write-Host -ForegroundColor DarkGray "Registering OSD ServiceUI Scheduled Task"

$scheduledTaskRunAsSystem = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.6" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
<RegistrationInfo>
<Date>2014-10-01T00:00:00.0000000</Date>
<Author>System</Author>
<Description>everydayintech</Description>
</RegistrationInfo>
<Triggers>
<BootTrigger>
<Enabled>true</Enabled>
</BootTrigger>
</Triggers>
<Principals>
<Principal id="LocalSystem">
<UserId>S-1-5-18</UserId>
<RunLevel>HighestAvailable</RunLevel>
</Principal>
</Principals>
<Settings>
<MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
<DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
<StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
<AllowHardTerminate>true</AllowHardTerminate>
<StartWhenAvailable>false</StartWhenAvailable>
<RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
<IdleSettings>
<StopOnIdleEnd>true</StopOnIdleEnd>
<RestartOnIdle>false</RestartOnIdle>
</IdleSettings>
<AllowStartOnDemand>true</AllowStartOnDemand>
<Enabled>true</Enabled>
<Hidden>false</Hidden>
<RunOnlyIfIdle>false</RunOnlyIfIdle>
<DisallowStartOnRemoteAppSession>false</DisallowStartOnRemoteAppSession>
<UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
<WakeToRun>false</WakeToRun>
<ExecutionTimeLimit>PT72H</ExecutionTimeLimit>
<Priority>7</Priority>
</Settings>
<Actions Context="LocalSystem">
<Exec>
<Command>C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe</Command>
<Arguments>-ExecutionPolicy ByPass C:\OSDCloud\temp\ServiceUIScheduledTask.ps1</Arguments>
<WorkingDirectory>C:\OSDCloud\temp</WorkingDirectory>
</Exec>
</Actions>
</Task>
"@

$scheduledTaskRunAsDefaultuser0 = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.6" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Date>2014-10-01T00:00:00.0000000</Date>
    <Author>System</Author>
    <Description>everydayintech</Description>
    <URI>\OSD ServiceUI</URI>
  </RegistrationInfo>
  <Triggers>
    <BootTrigger>
      <Enabled>true</Enabled>
    </BootTrigger>
  </Triggers>
  <Principals>
    <Principal id="LocalSystem">
      <UserId>S-1-5-21-561738137-981327493-1153898575-1000</UserId>
      <LogonType>S4U</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <DisallowStartOnRemoteAppSession>false</DisallowStartOnRemoteAppSession>
    <UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT72H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="LocalSystem">
    <Exec>
      <Command>C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe</Command>
      <Arguments>-ExecutionPolicy ByPass C:\OSDCloud\temp\ServiceUIScheduledTask.ps1</Arguments>
      <WorkingDirectory>C:\OSDCloud\temp</WorkingDirectory>
    </Exec>
  </Actions>
</Task>
"@

$scheduledTaskXml = $scheduledTaskRunAsSystem

Register-ScheduledTask -TaskName "OSD ServiceUI" -Xml $scheduledTaskXml -Force

#=======================================================================
# Scheduled Task Script
#=======================================================================

Write-Host -ForegroundColor DarkGray "Setting ServiceUIScheduledTask.ps1"
$ScheduledTaskScript = {
    Start-Transcript -Path 'C:\OSDCloud\temp\ServiceUIScheduledTask.log' -Append

    Write-Host -ForegroundColor DarkGray "Unregistering OSD ServiceUI Scheduled Task"
    Unregister-ScheduledTask -TaskName "OSD ServiceUI" -Confirm:$false

    #$ProcessAttachTo = 'RuntimeBroker.exe'
    $ProcessAttachTo = 'WWAHost.exe'

    do {

        Write-Host -ForegroundColor DarkGray "Waiting for $ProcessAttachTo to start"
        Start-Sleep -Seconds 1

    } until(Get-Process -Name ($ProcessAttachTo.Split('.')[0]) -ErrorAction 'silentlycontinue')


    Write-Host -ForegroundColor DarkGray "Found $ProcessAttachTo running, launching ServiceUI64.exe to inject start PowerShell.exe"
    Write-Host -ForegroundColor DarkGray "ServiceUI64.exe -process:$ProcessAttachTo C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe -NoExit -ExecutionPolicy RemoteSigned C:\OSDCloud\temp\ServiceUIUserPSScript.ps1"
    C:\OSDCloud\temp\ServiceUI64.exe -process:RuntimeBroker.exe C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe -NoExit -ExecutionPolicy RemoteSigned C:\OSDCloud\temp\ServiceUIUserPSScript.ps1

    Stop-Transcript
}
$ScheduledTaskScript.ToString() | Out-File -FilePath 'C:\OSDCloud\temp\ServiceUIScheduledTask.ps1' -Encoding utf8 -Force

#=======================================================================
# Interactive Script called by Scheduled Task with ServiceUI.exe
#=======================================================================

Write-Host -ForegroundColor DarkGray "Setting ServiceUIUserPSScript.ps1"
$SystemUserPSScript = {
    Start-Transcript -Path 'C:\OSDCloud\temp\ServiceUIUserPSScript.log' -Append

    Write-Host -ForegroundColor DarkGray "========================================================================="
    Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) " -NoNewline
    Write-Host -ForegroundColor Cyan "ServiceUIUserPSScript.ps1"



    Function Set-WindowStyle 
    {
        param
        (
            [Parameter()]
            [ValidateSet('FORCEMINIMIZE', 'HIDE', 'MAXIMIZE', 'MINIMIZE', 'RESTORE', 
                'SHOW', 'SHOWDEFAULT', 'SHOWMAXIMIZED', 'SHOWMINIMIZED', 
                'SHOWMINNOACTIVE', 'SHOWNA', 'SHOWNOACTIVATE', 'SHOWNORMAL')]
            $Style = 'SHOW',
            [Parameter()]
            $MainWindowHandle = (Get-Process -Id $pid).MainWindowHandle
        )

        $WindowStates = @{
            FORCEMINIMIZE = 11; HIDE = 0
            MAXIMIZE = 3; MINIMIZE = 6
            RESTORE = 9; SHOW = 5
            SHOWDEFAULT = 10; SHOWMAXIMIZED = 3
            SHOWMINIMIZED = 2; SHOWMINNOACTIVE = 7
            SHOWNA = 8; SHOWNOACTIVATE = 4
            SHOWNORMAL = 1
        }
        Write-Verbose ("Set Window Style {1} on handle {0}" -f $MainWindowHandle, $($WindowStates[$style]))

        $Win32ShowWindowAsync = Add-Type -memberDefinition @" 
[DllImport("user32.dll")] 
public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
"@ -name "Win32ShowWindowAsync" -namespace Win32Functions -PassThru

        $Win32ShowWindowAsync::ShowWindowAsync($MainWindowHandle, $WindowStates[$Style]) | Out-Null
    }

    # Usage

    # Minimize a running process window
    # Get-Process -Name Taskmgr | %{Set-WindowStyle MINIMIZE $PSItem.MainWindowHandle}
    # Get-Process -Name notepad | %{Set-WindowStyle MINIMIZE $PSItem.MainWindowHandle}

    # # Restore a running process window - the last window called will be topmost
    # Get-Process -Name Taskmgr | %{Set-WindowStyle RESTORE $PSItem.MainWindowHandle}


    Write-Host -ForegroundColor DarkGray "Enable Debug-Mode (SHIFT + F10) with WscriptShell.SendKeys"
    $WscriptShell = New-Object -com Wscript.Shell

    #ALT + TAB
    Write-Host -ForegroundColor DarkGray "SendKeys: ALT + TAB"
    $WscriptShell.SendKeys("%({TAB})")

    Start-Sleep -Seconds 1

    #Shift + F10
    Write-Host -ForegroundColor DarkGray "SendKeys: SHIFT + F10"
    $WscriptShell.SendKeys("+({F10})")

    Start-Sleep -Milliseconds 300

    if(-NOT (Get-Process -Name cmd -ErrorAction 'SilentlyContinue'))
    {
        Write-Host -ForegroundColor DarkGray "Retry Debug-Mode (SHIFT + F10) with WscriptShell.SendKeys (first attempt did not start cmd.exe)"
        do {
            #ALT + TAB
            Write-Host -ForegroundColor DarkGray "SendKeys: ALT + TAB"
            $WscriptShell.SendKeys("%({TAB})")

            Start-Sleep -Seconds 1

            #Shift + F10
            Write-Host -ForegroundColor DarkGray "SendKeys: SHIFT + F10"
            $WscriptShell.SendKeys("+({F10})")
            
        } until (
            Get-Process -Name cmd -ErrorAction 'SilentlyContinue'
        )

    }

    Write-Host -ForegroundColor DarkGray "Debug-Mode enbled successfully, cmd.exe is running"


    Write-Host -ForegroundColor DarkGray "Acquire cmd.exe window handle and grab focus"
    Start-Sleep -Seconds 1

    Get-Process -Name cmd           | %{Set-WindowStyle MINIMIZE $PSItem.MainWindowHandle}

    Start-Sleep -Milliseconds 300

    Get-Process -Name cmd           | %{Set-WindowStyle RESTORE $PSItem.MainWindowHandle}

    Start-Sleep -Seconds 1

    Write-Host -ForegroundColor DarkGray "Start PowerShell.exe with UserPSScript.ps1 via SendKeys into cmd.exe"
    $WscriptShell.SendKeys("start powershell.exe -NoExit -ExecutionPolicy RemoteSigned C:\OSDCloud\temp\UserPSScript.ps1")

    Start-Sleep -Milliseconds 300

    $WscriptShell.SendKeys("{ENTER}")

    Get-Process -Name cmd           | %{Set-WindowStyle MINIMIZE $PSItem.MainWindowHandle}



    $null = Read-Host "Press ENTER to continue"


    Start-Sleep -Seconds 5


    Get-Process -Name cmd           | %{Set-WindowStyle MINIMIZE $PSItem.MainWindowHandle}
    Get-Process -Name WWAHost       | %{Set-WindowStyle MINIMIZE $PSItem.MainWindowHandle}
    #Get-Process -Name WWAHost       | %{Set-WindowStyle RESTORE $PSItem.MainWindowHandle}
    Get-Process -Name powershell    | %{Set-WindowStyle MAXIMIZE $PSItem.MainWindowHandle}


    #ALT + TAB
    # Write-Host -ForegroundColor DarkGray "Bring PowerShell window to foreground by pressing ALT + TAB 3 times"
    # $WscriptShell.SendKeys("%{TAB 3}")
    # # Start-Sleep -milliseconds 300
    # $WscriptShell.SendKeys("%({TAB})")


    # Add-Type -AssemblyName System.Windows.Forms
    # [System.Windows.Forms.SendKeys]::SendWait('%{TAB}')
    # [System.Windows.Forms.SendKeys]::SendWait('+({F10})')

    # Write-Host -ForegroundColor DarkGray "========================================================================="
    # Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) " -NoNewline
    # Write-Host -ForegroundColor Cyan "Loading PowerShell Modules"

    # #=======================================================================
    # # Load Modules
    # #=======================================================================
    # Write-Host -ForegroundColor DarkGray "iex (irm 'https://raw.githubusercontent.com/OSDeploy/OSD/master/cloud/functions.ps1')"
    # Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/OSDeploy/OSD/master/cloud/functions.ps1')

    # Write-Host -ForegroundColor DarkGray "iex (irm 'https://raw.githubusercontent.com/OSDeploy/OSD/master/cloud/modules/_oobe.psm1')"
    # Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/OSDeploy/OSD/master/cloud/modules/_oobe.psm1')

    # Write-Host -ForegroundColor DarkGray "iex (irm 'https://raw.githubusercontent.com/OSDeploy/OSD/master/cloud/modules/_oobestartup.psm1')"
    # Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/OSDeploy/OSD/master/cloud/modules/_oobestartup.psm1')

    # Write-Host -ForegroundColor DarkGray "iex (irm 'https://raw.githubusercontent.com/OSDeploy/OSD/master/cloud/modules/_winpeoobe.psm1')"
    # Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/OSDeploy/OSD/master/cloud/modules/_winpeoobe.psm1')


    # Write-Host -ForegroundColor DarkGray "========================================================================="
    # Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) " -NoNewline
    # Write-Host -ForegroundColor Cyan "Running OOBE Setup Tasks"    

    # #=======================================================================
    # # OOBE Setup Tasks
    # #=======================================================================
    # Write-Host -ForegroundColor DarkGray "iex (irm 'https://raw.githubusercontent.com/everydayintech/OSDCloud/main/temp/Set-KeyboardLayout.ps1')"
    # Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/everydayintech/OSDCloud/main/temp/Set-KeyboardLayout.ps1')

    # Write-Host -ForegroundColor DarkGray "osdcloud-StartOOBE -Display -DateTime -Autopilot -KeyVault"
    # osdcloud-StartOOBE -Display -DateTime -Autopilot -KeyVault

    # Write-Host -ForegroundColor DarkGray "osdcloud-UpdateWindows"
    # osdcloud-UpdateWindows

    # $null = Read-Host -Prompt "Press Enter to logoff and restart OOBE..."
    # logoff.exe

}
$SystemUserPSScript.ToString() | Out-File -FilePath 'C:\OSDCloud\temp\ServiceUIUserPSScript.ps1' -Encoding utf8 -Force


Write-Host -ForegroundColor DarkGray "Setting UserPSScript.ps1"
$UserPSScript = {
    Start-Transcript -Path 'C:\OSDCloud\temp\UserPSScript.log' -Append

    Write-Host -ForegroundColor DarkGray "========================================================================="
    Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) " -NoNewline
    Write-Host -ForegroundColor Cyan "UserPSScript.ps1"



    Function Set-WindowStyle 
    {
        param
        (
            [Parameter()]
            [ValidateSet('FORCEMINIMIZE', 'HIDE', 'MAXIMIZE', 'MINIMIZE', 'RESTORE', 
                'SHOW', 'SHOWDEFAULT', 'SHOWMAXIMIZED', 'SHOWMINIMIZED', 
                'SHOWMINNOACTIVE', 'SHOWNA', 'SHOWNOACTIVATE', 'SHOWNORMAL')]
            $Style = 'SHOW',
            [Parameter()]
            $MainWindowHandle = (Get-Process -Id $pid).MainWindowHandle
        )

        $WindowStates = @{
            FORCEMINIMIZE = 11; HIDE = 0
            MAXIMIZE = 3; MINIMIZE = 6
            RESTORE = 9; SHOW = 5
            SHOWDEFAULT = 10; SHOWMAXIMIZED = 3
            SHOWMINIMIZED = 2; SHOWMINNOACTIVE = 7
            SHOWNA = 8; SHOWNOACTIVATE = 4
            SHOWNORMAL = 1
        }
        Write-Verbose ("Set Window Style {1} on handle {0}" -f $MainWindowHandle, $($WindowStates[$style]))

        $Win32ShowWindowAsync = Add-Type -memberDefinition @" 
[DllImport("user32.dll")] 
public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
"@ -name "Win32ShowWindowAsync" -namespace Win32Functions -PassThru

        $Win32ShowWindowAsync::ShowWindowAsync($MainWindowHandle, $WindowStates[$Style]) | Out-Null
    }

    #=======================================================================

    # Get-Process -Name cmd           | %{Set-WindowStyle MINIMIZE $PSItem.MainWindowHandle}
    # Get-Process -Name WWAHost       | %{Set-WindowStyle MINIMIZE $PSItem.MainWindowHandle}
    # #Get-Process -Name WWAHost       | %{Set-WindowStyle RESTORE $PSItem.MainWindowHandle}
    # Get-Process -Name powershell    | %{Set-WindowStyle MAXIMIZE $PSItem.MainWindowHandle}



    Write-Host -ForegroundColor DarkGray "========================================================================="
    Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) " -NoNewline
    Write-Host -ForegroundColor Cyan "Loading PowerShell Modules"

    #=======================================================================
    # Load Modules
    #=======================================================================
    Import-Module OSD

    Write-Host -ForegroundColor DarkGray "Installing AutopilotOOBE Module"
    Install-Module AutopilotOOBE -Force

    Write-Host -ForegroundColor DarkGray "iex (irm 'https://raw.githubusercontent.com/OSDeploy/OSD/master/cloud/functions.ps1')"
    Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/OSDeploy/OSD/master/cloud/functions.ps1')

    # Write-Host -ForegroundColor DarkGray "iex (irm 'https://raw.githubusercontent.com/OSDeploy/OSD/master/cloud/modules/_oobe.psm1')"
    # Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/OSDeploy/OSD/master/cloud/modules/_oobe.psm1')

    # Write-Host -ForegroundColor DarkGray "iex (irm 'https://raw.githubusercontent.com/OSDeploy/OSD/master/cloud/modules/_oobestartup.psm1')"
    # Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/OSDeploy/OSD/master/cloud/modules/_oobestartup.psm1')

    # Write-Host -ForegroundColor DarkGray "iex (irm 'https://raw.githubusercontent.com/OSDeploy/OSD/master/cloud/modules/_winpeoobe.psm1')"
    # Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/OSDeploy/OSD/master/cloud/modules/_winpeoobe.psm1')


    Write-Host -ForegroundColor DarkGray "========================================================================="
    Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) " -NoNewline
    Write-Host -ForegroundColor Cyan "Running OOBE Setup Tasks"    

    #=======================================================================
    # OOBE Setup Tasks
    #=======================================================================
    Write-Host -ForegroundColor DarkGray "iex (irm 'https://raw.githubusercontent.com/everydayintech/OSDCloud/main/temp/Set-KeyboardLayout.ps1')"
    Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/everydayintech/OSDCloud/main/temp/Set-KeyboardLayout.ps1')

    Write-Host -ForegroundColor DarkGray "osdcloud-StartOOBE -Display -DateTime -Autopilot -KeyVault"
    osdcloud-StartOOBE -Autopilot -KeyVault

    Write-Host -ForegroundColor DarkGray "osdcloud-UpdateWindows"
    osdcloud-UpdateWindows


    Write-Host -ForegroundColor DarkGray "AutopilotOOBE test for @AkosBakos"
    Start-Process PowerShell -ArgumentList "-NoL -C Invoke-WebPSScript https://start-autopilotoobe.osdcloud.ch" -Wait

    Write-Host -ForegroundColor Cyan "Press Enter to logoff and restart OOBE" -NoNewline
    $null = Read-Host
    logoff.exe

}
$UserPSScript.ToString() | Out-File -FilePath 'C:\OSDCloud\temp\UserPSScript.ps1' -Encoding utf8 -Force




Stop-Transcript