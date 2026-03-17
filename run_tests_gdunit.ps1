#!/usr/bin/env pwsh
# run_tests_gdunit.ps1 — Run GdUnit4 tests from the command line
# Usage: .\run_tests_gdunit.ps1 [-Filter "test_name"]

param(
    [string]$Filter = ""
)

$godot = "godot"
$baseArgs = @("--headless", "--path", ".", "-s", "addons/gdUnit4/bin/GdUnitCmdTool.gd")

$allArgs = $baseArgs
if ($Filter) { $allArgs += "--add=$Filter" }

Write-Host "Running GdUnit4: $godot $($allArgs -join ' ')" -ForegroundColor Cyan
& $godot @allArgs
$exitCode = $LASTEXITCODE

if ($exitCode -eq 0) {
    Write-Host "`n[PASS] All GdUnit4 tests passed!" -ForegroundColor Green
} else {
    Write-Host "`n[FAIL] Some GdUnit4 tests failed (exit code: $exitCode)" -ForegroundColor Red
}
exit $exitCode
