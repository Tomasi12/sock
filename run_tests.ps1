# run_tests.ps1
# Runs all the automatic tests, one after the other.
#   powershell -File run_tests.ps1
# It stops with an error if a test fails, prints a script error, or hangs.

$godot = $env:GODOT
if (-not $godot) {
    $godot = "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
}
if (-not (Test-Path $godot)) {
    Write-Host "Godot not found at: $godot"
    Write-Host 'Set the path first, for example:  $env:GODOT = "C:\Godot\godot.exe"'
    exit 1
}

Set-Location $PSScriptRoot

# Each test: scene, the line it prints when all is fine, and a time limit in seconds.
$tests = @(
    @{ Name = "unit_test";    Pass = "UNIT TEST: ALL PASSED";    Limit = 300 },
    @{ Name = "smoke_test";   Pass = "SMOKE TEST: ALL PASSED";   Limit = 300 },
    @{ Name = "campaign_bot"; Pass = "CAMPAIGN BOT: ALL PASSED"; Limit = 900 }
)

$failed = 0
foreach ($test in $tests) {
    Write-Host ""
    Write-Host "=== $($test.Name) ==="
    $log = Join-Path $env:TEMP "last_sock_$($test.Name).log"
    $process = Start-Process -FilePath $godot -NoNewWindow -PassThru `
        -ArgumentList "--headless", "--fixed-fps", "60", "res://tests/$($test.Name).tscn" `
        -RedirectStandardOutput $log -RedirectStandardError "$log.err"

    if (-not $process.WaitForExit($test.Limit * 1000)) {
        # A script with a typo never finishes: stop it instead of waiting forever.
        Stop-Process -Id $process.Id -Force
        Write-Host "FAILED: no answer after $($test.Limit) seconds (a script error stops the test)"
        Get-Content "$log.err" -ErrorAction SilentlyContinue | Select-Object -First 10
        $failed += 1
        continue
    }

    $text = @(Get-Content $log) + @(Get-Content "$log.err" -ErrorAction SilentlyContinue)
    $problems = $text | Where-Object { $_ -match "FAIL|SCRIPT ERROR|Parse Error" }
    $passed = $text | Where-Object { $_ -like "*$($test.Pass)*" }
    if ($passed -and -not $problems) {
        Write-Host $passed
    } else {
        Write-Host "FAILED:"
        $problems | Select-Object -First 30 | ForEach-Object { Write-Host "  $_" }
        Write-Host "(full output: $log)"
        $failed += 1
    }
}

Write-Host ""
if ($failed -eq 0) {
    Write-Host "ALL TESTS PASSED"
    exit 0
}
Write-Host "$failed TEST(S) FAILED"
exit 1
