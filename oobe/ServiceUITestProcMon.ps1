# Usage for Test-Scenario: 
#   1. Open Command Prompt during OOBE with Shift + F10
#   2. Open PowerShell and run: iex (irm https://raw.githubusercontent.com/everydayintech/OSDCloud-Public/main/oobe/ServiceUITestProcMon.ps1); Restart-Computer -Force
#   3. Wait for PowerShell to Start automatically after Restart

# Note: for consecutive Tests, you can use the retry.cmd shortcut to start the script again

# Usage for OSDCloud Deployment:
#   1. Save this Script to Disk during WinPE Phase
#   2. Run this Script during Windows Specialize Phase using Unattend.xml


Start-Transcript -Path 'C:\OSDCloud\temp\ServiceUITest.log' -Append

Import-Module OSD


#=======================================================================
# retry shortcut for debugging
#=======================================================================

$retrycmd = @"
start /wait Powershell -ExecutionPolicy Bypass -Command "iex (irm https://raw.githubusercontent.com/everydayintech/OSDCloud-Public/main/oobe/ServiceUITestProcMon.ps1); Restart-Computer -Force"
"@

$retrycmd | Out-File -FilePath 'C:\Windows\System32\retry.cmd' -Encoding ascii -Force


#=======================================================================
# Download executables
#=======================================================================

Save-WebFile `
    -SourceUrl 'https://raw.githubusercontent.com/everydayintech/OSDCloud-Public/main/raw/ServiceUI64.exe' `
    -DestinationName 'ServiceUI64.exe' `
    -DestinationDirectory 'C:\OSDCloud\temp' -Overwrite


Save-WebFile `
    -SourceUrl 'https://raw.githubusercontent.com/everydayintech/OSDCloud-Public/main/raw/Procmon64.exe' `
    -DestinationName 'Procmon64.exe' `
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
    # Unregister-ScheduledTask -TaskName "OSD ServiceUI" -Confirm:$false

    #$ProcessAttachTo = 'RuntimeBroker.exe'
    $ProcessAttachTo = 'WWAHost.exe'

    do {

        Write-Host -ForegroundColor DarkGray "Waiting for $ProcessAttachTo to start"
        Start-Sleep -Seconds 1

    } until(Get-Process -Name ($ProcessAttachTo.Split('.')[0]) -ErrorAction 'silentlycontinue')


    reg add "HKCU\SOFTWARE\Sysinternals\Process Monitor" /v EulaAccepted /t REG_DWORD /d 1 /f

    Write-Host -ForegroundColor DarkGray "Found $ProcessAttachTo running, launching ServiceUI64.exe to start Procmon64.exe"
    Write-Host -ForegroundColor DarkGray "ServiceUI64.exe -process:$ProcessAttachTo C:\OSDCloud\temp\Procmon64.exe"
    C:\OSDCloud\temp\ServiceUI64.exe -process:RuntimeBroker.exe C:\OSDCloud\temp\Procmon64.exe

    Stop-Transcript
}
$ScheduledTaskScript.ToString() | Out-File -FilePath 'C:\OSDCloud\temp\ServiceUIScheduledTask.ps1' -Encoding utf8 -Force

Stop-Transcript