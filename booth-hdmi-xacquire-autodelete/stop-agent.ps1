# Stops ALL selfbooth-agent processes (booth + print).
# Both modes share process name "selfbooth-agent" - there is no per-mode filter.
$procs = Get-Process -Name "selfbooth-agent" -ErrorAction SilentlyContinue
if (-not $procs) {
    Write-Host "No selfbooth-agent running." -ForegroundColor Yellow
    exit 0
}
$procs | Stop-Process -Force
Write-Host "Stopped $($procs.Count) selfbooth-agent process(es) (booth + print)." -ForegroundColor Green
