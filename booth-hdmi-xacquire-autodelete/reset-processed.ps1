# Deletes the agent's uploaded-photo store (processed-files.json).
#
# The store exists so a restart does not re-upload photos the API already has.
# Clearing it is safe: worst case a JPG still sitting in WATCH_DIR and younger
# than AGENT_BACKLOG_MAX_AGE_SEC gets uploaded a second time.
#
# Run this when the log shows "DETECTED: <file>" with no UPLOADED / NO SESSION
# line after it, or when /status reports a large skipped_uploaded count.

$procs = Get-Process -Name "selfbooth-agent" -ErrorAction SilentlyContinue
if ($procs) {
    Write-Host "Agent is still running - stop it first (stop-agent.cmd)." -ForegroundColor Red
    Write-Host "The running agent would just write the store back out." -ForegroundColor Red
    exit 1
}

$spoolDir = $env:AGENT_SPOOL_DIR
if ([string]::IsNullOrWhiteSpace($spoolDir)) {
    $base = $env:LOCALAPPDATA
    if ([string]::IsNullOrWhiteSpace($base)) { $base = $env:TEMP }
    $spoolDir = Join-Path $base "selfbooth\spool"
}
$storePath = Join-Path (Split-Path -Parent $spoolDir) "processed-files.json"

if (-not (Test-Path $storePath)) {
    Write-Host "Nothing to reset - no store at $storePath" -ForegroundColor Yellow
    exit 0
}

$sizeKB = [math]::Round((Get-Item $storePath).Length / 1KB, 1)
Remove-Item $storePath -Force
Write-Host "Deleted $storePath ($sizeKB KB)." -ForegroundColor Green
Write-Host "Start the agent again with run-agent.cmd." -ForegroundColor Green
