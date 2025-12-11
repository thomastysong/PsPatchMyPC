# Quick dialog test with short timeout
Set-Location C:\repos\PsPatchMyPC
Import-Module .\PsPatchMyPC -Force

Write-Host "Testing dialog with 30 second timeout..." -ForegroundColor Cyan
Write-Host "Click Defer or Update Now!" -ForegroundColor Yellow
Write-Host ""

$result = Show-DeferralDialog -AppId "Git.Git" -Timeout 30

Write-Host ""
Write-Host "Dialog result: $result" -ForegroundColor Green
