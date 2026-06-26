$flutterSdk = "C:\flutter\bin\flutter.bat"
$adb = "C:\Users\lee\android-sdk\platform-tools\adb.exe"
$androidHome = "C:\Users\lee\android-sdk"
$aipDir = "C:\Users\lee\Desktop\lee\aip"
$appDir = "C:\Users\lee\Desktop\lee\aip\aip_app"
$serverDir = "C:\Users\lee\Desktop\lee\aip\server-go"
$apkPath = "$appDir\build\app\outputs\flutter-apk\app-debug.apk"
$packageName = "com.aip.aip_app"
$pubspecPath = "$appDir\pubspec.yaml"
$uploadGoPath = "$serverDir\handlers\upload.go"

$env:ANDROID_HOME = $androidHome
$env:ANDROID_SDK_ROOT = $androidHome

Write-Host "=== AIP Deploy ===" -ForegroundColor Cyan

# Auto increment version
Write-Host "[0/6] Bump version..." -ForegroundColor Yellow
$pubspecContent = Get-Content $pubspecPath -Raw
if ($pubspecContent -match 'version:\s+(\d+)\.(\d+)\.(\d+)\+(\d+)') {
    $major = [int]$Matches[1]
    $minor = [int]$Matches[2]
    $patch = [int]$Matches[3] + 1
    $build = [int]$Matches[4] + 1
    $newVersion = "$major.$minor.$patch"
    $newBuild = "$major.$minor.$patch+$build"
    $pubspecContent = $pubspecContent -replace "version:\s+\d+\.\d+\.\d+\+\d+", "version: $newBuild"
    Set-Content $pubspecPath $pubspecContent -NoNewline

    $uploadContent = Get-Content $uploadGoPath -Encoding UTF8
    $uploadContent = $uploadContent -replace 'appVersion = "[^"]*"', "appVersion = `"$newVersion`""
    [System.IO.File]::WriteAllText($uploadGoPath, ($uploadContent -join "`n"), [System.Text.UTF8Encoding]::new($false))

    Write-Host "  Version: $newVersion (build $build)" -ForegroundColor Green
} else {
    Write-Host "  Could not parse version, skipping" -ForegroundColor Yellow
}

Write-Host "[1/6] Go server..." -ForegroundColor Yellow
Set-Location $serverDir
$goProc = Start-Process -FilePath "go" -ArgumentList "build","-o","aip-server.exe","." -WorkingDirectory $serverDir -Wait -PassThru -NoNewWindow
if ($goProc.ExitCode -ne 0) {
    Write-Host "  Go build FAILED!" -ForegroundColor Red
    exit 1
}
Write-Host "  OK" -ForegroundColor Green

Write-Host "[2/6] Flutter APK..." -ForegroundColor Yellow
Set-Location $appDir
$proc = Start-Process -FilePath $flutterSdk -ArgumentList "build","apk","--debug" -WorkingDirectory $appDir -Wait -PassThru -NoNewWindow
if ($proc.ExitCode -ne 0 -and !(Test-Path $apkPath)) {
    Write-Host "  FAILED!" -ForegroundColor Red
    exit 1
}
Write-Host "  OK" -ForegroundColor Green

Write-Host "[3/6] Copy APK..." -ForegroundColor Yellow
Copy-Item $apkPath "$serverDir\uploads\aip-debug.apk" -Force
Write-Host "  OK" -ForegroundColor Green

Write-Host "[4/6] Install..." -ForegroundColor Yellow
Set-Location "$aipDir"
$hasDevice = & $adb devices 2>&1 | Select-String "device$"
if ($hasDevice) {
    & $adb shell am force-stop $packageName 2>&1 | Out-Null
    & $adb install -r $apkPath 2>&1 | Out-Null
    Write-Host "  OK" -ForegroundColor Green
} else {
    Write-Host "  No device" -ForegroundColor Yellow
}

Write-Host "[5/6] Server + Launch..." -ForegroundColor Yellow
$existing = Get-Process -Name "aip-server" -ErrorAction SilentlyContinue
if ($existing) {
    taskkill /F /IM aip-server.exe 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Start-Process powershell -ArgumentList "-NoProfile -Command `"Stop-Process -Name 'aip-server' -Force`"" -Verb RunAs -Wait
    }
    Start-Sleep -Seconds 2
}
Start-Process "$serverDir\aip-server.exe" -WorkingDirectory $serverDir -WindowStyle Normal
Start-Sleep -Seconds 3
$hasDevice = & $adb devices 2>&1 | Select-String "device$"
if ($hasDevice) {
    & $adb shell monkey -p $packageName -c android.intent.category.LAUNCHER 1 2>&1 | Out-Null
    Write-Host "  Launched!" -ForegroundColor Green
}

Write-Host "=== Done ===" -ForegroundColor Cyan
