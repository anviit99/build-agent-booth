param(
    [switch]$NoStart
)

$ErrorActionPreference = "Stop"
# Distinct task name so this variant never overwrites the booth-hdmi-xacquire task.
$TaskName = "Selfbooth HDMI XAcquire Agent (autodelete)"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RunScript = Join-Path $ScriptDir "run-agent.ps1"
$AgentExe = Join-Path $ScriptDir "selfbooth-agent.exe"
$EnvCandidates = @(
    (Join-Path $ScriptDir ".env.agent"),
    (Join-Path $ScriptDir "env.agent"),
    (Join-Path $ScriptDir "env")
)

if (-not (Test-Path -LiteralPath $RunScript)) {
    throw "Missing $RunScript"
}
if (-not (Test-Path -LiteralPath $AgentExe)) {
    throw "Missing $AgentExe"
}
if (-not ($EnvCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1)) {
    throw "Missing env file beside the scripts (.env.agent, env.agent, or env)."
}

# A ZIP downloaded from another computer may carry Mark-of-the-Web.
# Installation is an explicit trust action, so unblock this kit's launch files.
@($RunScript, $AgentExe) | Unblock-File -ErrorAction SilentlyContinue

$UserId = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$XmlEscape = {
    param([string]$Value)
    [System.Security.SecurityElement]::Escape($Value)
}

$EscapedUser = & $XmlEscape $UserId
$EscapedDirectory = & $XmlEscape $ScriptDir
$Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$RunScript`""
$EscapedArguments = & $XmlEscape $Arguments
$Now = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$TaskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Date>$Now</Date>
    <Description>Runs the Selfbooth HDMI + X Acquire agent (autodelete variant) at Windows logon and workstation unlock.</Description>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
      <UserId>$EscapedUser</UserId>
    </LogonTrigger>
    <SessionStateChangeTrigger>
      <Enabled>true</Enabled>
      <StateChange>SessionUnlock</StateChange>
      <UserId>$EscapedUser</UserId>
    </SessionStateChangeTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$EscapedUser</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>$EscapedArguments</Arguments>
      <WorkingDirectory>$EscapedDirectory</WorkingDirectory>
    </Exec>
  </Actions>
</Task>
"@

Register-ScheduledTask -TaskName $TaskName -Xml $TaskXml -Force | Out-Null
Write-Host "Installed scheduled task: $TaskName" -ForegroundColor Green
Write-Host "Triggers: Windows logon + workstation unlock ($UserId)" -ForegroundColor Green
Write-Host "Kit path: $ScriptDir" -ForegroundColor DarkGray
Write-Host "Reminder: do NOT keep the booth-hdmi-xacquire task enabled on the same WATCH_DIR." -ForegroundColor Yellow

if (-not $NoStart) {
    Start-ScheduledTask -TaskName $TaskName
    Write-Host "Task started. An existing agent from this kit will be kept." -ForegroundColor Green
}
