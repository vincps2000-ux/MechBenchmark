#!/usr/bin/env pwsh
# run_tests.ps1 — Run GUT tests from the command line (agent-friendly)
# Usage: .\run_tests.ps1 [-Filter "test_name"] [-Unit] [-Integration]

param(
    [string]$Filter = "",
    [switch]$Unit,
    [switch]$Integration,
    [switch]$Verbose
)

$godot = "godot"
$baseArgs = @("--headless", "--path", ".", "-s", "addons/gut/gut_cmdln.gd")

# Determine which test dirs to run
$dirs = @()
if ($Unit) { $dirs += "res://tests/unit" }
if ($Integration) { $dirs += "res://tests/integration" }
if ($dirs.Count -eq 0) { $dirs = @("res://tests/unit", "res://tests/integration") }

$dirArgs = ($dirs | ForEach-Object { "-gdir=$_" })

$allArgs = $baseArgs + $dirArgs
if ($Filter) { $allArgs += "-gselect=$Filter" }
if ($Verbose) { $allArgs += "-glog=3" }

Write-Host "Running: $godot $($allArgs -join ' ')" -ForegroundColor Cyan
& $godot @allArgs
$exitCode = $LASTEXITCODE

if ($exitCode -eq 0) {
    Write-Host "`n[PASS] All tests passed!" -ForegroundColor Green
} else {
    Write-Host "`n[FAIL] Some tests failed (exit code: $exitCode)" -ForegroundColor Red
}
exit $exitCode
