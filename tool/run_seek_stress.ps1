param(
    [string]$DeviceId = ""
)

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " HiveTube: Seek Stress Integration Test Runner" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

flutter devices

if ([string]::IsNullOrEmpty($DeviceId)) {
    Write-Host "`nUsage: .\tool\run_seek_stress.ps1 -DeviceId <device-id>" -ForegroundColor Yellow
    Write-Host "Example: .\tool\run_seek_stress.ps1 -DeviceId android" -ForegroundColor Yellow
    Write-Host "Running on the default available device..." -ForegroundColor Green
    flutter test integration_test/seek_stress_test.dart
} else {
    Write-Host "Running integration test on device: $DeviceId" -ForegroundColor Green
    flutter test -d $DeviceId integration_test/seek_stress_test.dart
}

