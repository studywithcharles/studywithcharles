# Flutter Android Build Fix Script
# Run this from your project root: C:\flutter_projects\studywithcharles

Write-Host "Flutter Android Build Fix Script" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green

# Step 1: Ensure MainActivity.kt is in the correct location
Write-Host "`nStep 1: Fixing MainActivity.kt location..." -ForegroundColor Yellow

$correctPath = "android\app\src\main\kotlin\com\swcaiagent\studywithcharles"
$incorrectPath = "android\app\src\main\kotlin\com\example\studywithcharles"

# Create the correct directory structure
if (!(Test-Path $correctPath)) {
    Write-Host "Creating correct directory structure..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $correctPath -Force | Out-Null
}

# Check if MainActivity.kt exists in the wrong location
if (Test-Path "$incorrectPath\MainActivity.kt") {
    Write-Host "Moving MainActivity.kt from incorrect location..." -ForegroundColor Cyan
    Move-Item -Path "$incorrectPath\MainActivity.kt" -Destination "$correctPath\MainActivity.kt" -Force
    
    # Clean up the old directory
    if (Test-Path "android\app\src\main\kotlin\com\example") {
        Remove-Item -Recurse -Force "android\app\src\main\kotlin\com\example"
    }
} elseif (!(Test-Path "$correctPath\MainActivity.kt")) {
    Write-Host "MainActivity.kt not found, creating it..." -ForegroundColor Cyan
    # Create MainActivity.kt if it doesn't exist
    @"
package com.swcaiagent.studywithcharles

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
"@ | Out-File -FilePath "$correctPath\MainActivity.kt" -Encoding UTF8
}

Write-Host "MainActivity.kt is now in the correct location!" -ForegroundColor Green

# Step 2: Clean the project
Write-Host "`nStep 2: Cleaning the project..." -ForegroundColor Yellow
flutter clean
flutter pub get

# Step 3: Stop Gradle daemons
Write-Host "`nStep 3: Stopping Gradle daemons..." -ForegroundColor Yellow
Set-Location android
.\gradlew --stop
Set-Location ..

# Step 4: Clear Gradle caches
Write-Host "`nStep 4: Clearing Gradle caches..." -ForegroundColor Yellow
$gradleCache = "$env:USERPROFILE\.gradle\caches"
if (Test-Path $gradleCache) {
    Write-Host "Clearing Gradle build cache..." -ForegroundColor Cyan
    Remove-Item -Recurse -Force "$gradleCache\build-cache-1" -ErrorAction SilentlyContinue
}

# Step 5: Verify file locations
Write-Host "`nStep 5: Verifying file structure..." -ForegroundColor Yellow
Write-Host "Checking critical files:" -ForegroundColor Cyan

$filesToCheck = @(
    "android\settings.gradle.kts",
    "android\app\build.gradle.kts",
    "android\app\src\main\kotlin\com\swcaiagent\studywithcharles\MainActivity.kt",
    "android\app\src\main\AndroidManifest.xml"
)

foreach ($file in $filesToCheck) {
    if (Test-Path $file) {
        Write-Host "  ✓ $file" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $file - MISSING!" -ForegroundColor Red
    }
}

# Step 6: Build the project
Write-Host "`nStep 6: Building the project..." -ForegroundColor Yellow
Set-Location android

Write-Host "Running Gradle build with full diagnostics..." -ForegroundColor Cyan
.\gradlew assembleDebug --refresh-dependencies --no-build-cache --stacktrace

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ BUILD SUCCESSFUL!" -ForegroundColor Green
    Set-Location ..
    
    Write-Host "`nBuilding Flutter APK..." -ForegroundColor Yellow
    flutter build apk --debug --target-platform android-arm64,android-arm
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✅ FLUTTER BUILD SUCCESSFUL!" -ForegroundColor Green
        Write-Host "APK location: build\app\outputs\flutter-apk\app-debug.apk" -ForegroundColor Cyan
    }
} else {
    Write-Host "`n❌ BUILD FAILED" -ForegroundColor Red
    Write-Host "Please check the error messages above." -ForegroundColor Yellow
    Set-Location ..
}

Write-Host "`nScript completed!" -ForegroundColor Green