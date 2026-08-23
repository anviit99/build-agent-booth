$ErrorActionPreference = "Stop"
$TaskName = "Selfbooth HDMI XAcquire Agent (autodelete)"
$Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if (-not $Task) {
    Write-Host "Scheduled task is not installed: $TaskName" -ForegroundColor Yellow
    exit 0
}

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
Write-Host "Removed scheduled task: $TaskName" -ForegroundColor Green
