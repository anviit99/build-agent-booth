# Builds selfbooth-agent.exe from the repo into THIS kit folder.
#
# Same source as the booth-hdmi-xacquire kit - the autodelete behaviour is a
# runtime knob (AGENT_DELETE_AFTER_UPLOAD in .env.agent), not a separate build.
#
# Run from anywhere:  .\build-agent.ps1
# Optional:           .\build-agent.ps1 -BackendDir "D:\repo\selfbooth-backend"

param(
    [string]$BackendDir = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not $BackendDir) {
    # Walk up looking for harrords-backend / selfbooth-backend (kit under setup/<kit>).
    $probe = $ScriptDir
    for ($i = 0; $i -lt 6 -and $probe; $i++) {
        foreach ($name in @("harrords-backend", "selfbooth-backend")) {
            $candidate = Join-Path $probe $name
            if (Test-Path -LiteralPath (Join-Path $candidate "cmd\agent")) {
                $BackendDir = $candidate
                break
            }
        }
        if ($BackendDir) { break }
        $probe = Split-Path -Parent $probe
    }
}

if (-not $BackendDir -or -not (Test-Path -LiteralPath (Join-Path $BackendDir "cmd\agent"))) {
    Write-Host "Cannot locate harrords-backend\cmd\agent (or selfbooth-backend)." -ForegroundColor Red
    Write-Host "Pass it explicitly: .\build-agent.ps1 -BackendDir `"C:\repo\harrords-backend`"" -ForegroundColor Yellow
    exit 1
}

if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
    Write-Host "Go toolchain not found in PATH. Install Go, or copy selfbooth-agent.exe here." -ForegroundColor Red
    exit 1
}

$agentExe = Join-Path $ScriptDir "selfbooth-agent.exe"
Write-Host "Backend: $BackendDir" -ForegroundColor DarkGray
Write-Host "Output:  $agentExe" -ForegroundColor DarkGray

Push-Location $BackendDir
try {
    Write-Host "go test ./cmd/agent/ ..." -ForegroundColor Cyan
    go test ./cmd/agent/ -count=1
    if ($LASTEXITCODE -ne 0) { throw "agent tests failed - not building" }

    Write-Host "go build ./cmd/agent ..." -ForegroundColor Cyan
    go build -o $agentExe ./cmd/agent
    if ($LASTEXITCODE -ne 0) { throw "go build failed" }
}
finally {
    Pop-Location
}

Write-Host "Built: $agentExe" -ForegroundColor Green
Write-Host "Next: copy .env.agent.example to .env.agent (AGENT_DELETE_AFTER_UPLOAD=true), then run-agent.cmd" -ForegroundColor Yellow
