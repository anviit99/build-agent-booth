# Booth agent kit (Windows) - AUTODELETE variant, self-contained folder
#
# Layout:
#   run-agent.ps1
#   .env.agent | env.agent | env   (first match wins)
#   selfbooth-agent.exe
#
# Same behaviour as booth-hdmi-xacquire, plus: agent deletes the source JPG in
# WATCH_DIR after the API accepted it (AGENT_DELETE_AFTER_UPLOAD in .env.agent).
# Forces AGENT_MODE=booth after loading env file.
# Run:  .\run-agent.ps1
# Or double-click: run-agent.cmd
# Optional: .\run-agent.ps1 -EnvFile "D:\other\.env.agent"
#
# Encoding: UTF-8 with BOM + CRLF (Windows PowerShell 5.1).

param(
    [string]$EnvFile = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ParentDir = Split-Path -Parent $ScriptDir
$InSetupKit = ((Split-Path -Leaf $ParentDir) -eq "setup")
$RepoRoot = if ($InSetupKit) { Split-Path -Parent $ParentDir } else { $null }
$Backend = $null
if ($RepoRoot) {
    foreach ($name in @("harrords-backend", "selfbooth-backend")) {
        $candidate = Join-Path $RepoRoot $name
        if (Test-Path -LiteralPath (Join-Path $candidate "cmd\agent")) {
            $Backend = $candidate
            break
        }
    }
}

# Priority beside script: .env.agent (Admin) -> env.agent (print-kit alias) -> env
$envCandidates = @(
    (Join-Path $ScriptDir ".env.agent"),
    (Join-Path $ScriptDir "env.agent"),
    (Join-Path $ScriptDir "env")
)

if (-not $EnvFile) {
    foreach ($cand in $envCandidates) {
        if (Test-Path -LiteralPath $cand) {
            $EnvFile = $cand
            break
        }
    }
}

if (-not $EnvFile -or -not (Test-Path -LiteralPath $EnvFile)) {
    Write-Host "Missing env file next to this script (tried .env.agent, env.agent, env):" -ForegroundColor Red
    foreach ($cand in $envCandidates) {
        Write-Host "  $cand" -ForegroundColor Yellow
    }
    Write-Host "Copy .env.agent.example to .env.agent, set WATCH_DIR / SERVICE_TOKEN / ROOM_ID." -ForegroundColor Yellow
    Write-Host "Or: .\run-agent.ps1 -EnvFile `"D:\path\to\env`"" -ForegroundColor Yellow
    exit 1
}

$agentEnv = $EnvFile
Get-Content -LiteralPath $agentEnv | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith([char]0x23)) { return }
    $eq = $line.IndexOf([char]0x3D)
    if ($eq -gt 0) {
        $key = $line.Substring(0, $eq).Trim()
        $val = $line.Substring($eq + 1).Trim()
        Set-Item -Path ("env:" + $key) -Value $val
    }
}

# Booth kit always - after env load so .env.agent cannot leave mode as all/print.
$env:AGENT_MODE = "booth"
$env:AGENT_NO_PAUSE = "1"

# Relative AGENT_LOG_FILE must land in this kit folder, not the caller's cwd.
if ($env:AGENT_LOG_FILE -and -not [System.IO.Path]::IsPathRooted($env:AGENT_LOG_FILE)) {
    $env:AGENT_LOG_FILE = Join-Path $ScriptDir $env:AGENT_LOG_FILE
}
if ($env:AGENT_LOG_FILE) {
    $logDir = Split-Path -Parent $env:AGENT_LOG_FILE
    if ($logDir -and -not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
}

$agentExe = Join-Path $ScriptDir "selfbooth-agent.exe"
if (-not (Test-Path -LiteralPath $agentExe) -and $Backend) {
    $backendExe = Join-Path $Backend "selfbooth-agent.exe"
    if (Test-Path -LiteralPath $backendExe) {
        Copy-Item -LiteralPath $backendExe -Destination $agentExe -Force
        Write-Host "Copied agent from selfbooth-backend\" -ForegroundColor Green
    }
}

if (-not (Test-Path -LiteralPath $agentExe)) {
    $canBuild = $Backend -and (Test-Path (Join-Path $Backend "cmd\agent"))
    if (-not $canBuild) {
        Write-Host "Missing $agentExe" -ForegroundColor Red
        Write-Host "Run build-agent.ps1 from the repo, or copy selfbooth-agent.exe into this folder." -ForegroundColor Yellow
        exit 1
    }
    if (Get-Command go -ErrorAction SilentlyContinue) {
        Write-Host "Building selfbooth-agent.exe with Go ..." -ForegroundColor Cyan
        Push-Location $Backend
        go build -o $agentExe ./cmd/agent
        Pop-Location
    }
    else {
        Write-Host "Missing $agentExe" -ForegroundColor Red
        Write-Host "Install Go or copy the binary into this kit folder." -ForegroundColor Yellow
        exit 1
    }
}

$deleteKnob = if ($env:AGENT_DELETE_AFTER_UPLOAD) { $env:AGENT_DELETE_AFTER_UPLOAD } else { "false (kit goc behaviour)" }
Write-Host "Env:    $agentEnv" -ForegroundColor DarkGray
Write-Host "Exe:    $agentExe" -ForegroundColor DarkGray
Write-Host "Mode:   booth" -ForegroundColor DarkGray
Write-Host "Watch:  $($env:WATCH_DIR)" -ForegroundColor DarkGray
$photoCap = if ($env:AGENT_MAX_PHOTO_BYTES) { $env:AGENT_MAX_PHOTO_BYTES } else { "0 (off)" }
$photoEdge = if ($env:AGENT_MAX_PHOTO_EDGE) { $env:AGENT_MAX_PHOTO_EDGE } else { "0 (off)" }
Write-Host "Upload: AGENT_MAX_PHOTO_BYTES=$photoCap  AGENT_MAX_PHOTO_EDGE=$photoEdge px" -ForegroundColor DarkGray
Write-Host "Delete: AGENT_DELETE_AFTER_UPLOAD=$deleteKnob" -ForegroundColor Yellow
if ($env:AGENT_LOG_FILE) {
    Write-Host "Log:    $($env:AGENT_LOG_FILE)" -ForegroundColor DarkGray
}

# Logon + unlock triggers can arrive close together. Do not start a second
# copy from this same kit; Task Scheduler also uses IgnoreNew as a second guard.
$agentExePath = [System.IO.Path]::GetFullPath($agentExe)
$sameKitProcess = Get-Process -Name "selfbooth-agent" -ErrorAction SilentlyContinue |
    Where-Object {
        try {
            [string]::Equals(
                [System.IO.Path]::GetFullPath($_.Path),
                $agentExePath,
                [System.StringComparison]::OrdinalIgnoreCase
            )
        }
        catch {
            $false
        }
    } |
    Select-Object -First 1

if ($sameKitProcess) {
    Write-Host "Agent is already running from this kit (PID $($sameKitProcess.Id))." -ForegroundColor Yellow
    exit 0
}

Write-Host "=== Selfbooth Agent (autodelete) ===" -ForegroundColor Cyan
& $agentExe -env $agentEnv
