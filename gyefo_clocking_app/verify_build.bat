@echo off
echo ==========================================
echo Gyefo App Pre-build Verification Checks
echo ==========================================

echo.
echo 1. Checking Firebase configuration...
if exist "android\app\google-services.json" (
    echo ✅ google-services.json found
) else (
    echo ❌ ERROR: google-services.json not found!
    echo Please ensure google-services.json is in android/app/
    exit /b 1
)

echo.
echo 2. Checking Android permissions...
findstr "INTERNET" "android\app\src\main\AndroidManifest.xml" >nul
if %errorlevel% equ 0 (
    echo ✅ Internet permission found
) else (
    echo ❌ WARNING: Internet permission might be missing!
)

echo.
echo 3. Checking dart compilation...
call dart analyze
if %errorlevel% equ 0 (
    echo ✅ Dart analysis passed
) else (
    echo ⚠️ Dart analysis found issues
)

echo.
echo 4. Checking Firebase initialization...
findstr "Firebase.initializeApp" "lib\main.dart" >nul
if %errorlevel% equ 0 (
    echo ✅ Firebase initialization found
) else (
    echo ❌ WARNING: Firebase initialization might be missing!
)

echo.
echo 5. Checking build configurations...
findstr "isMinifyEnabled = false" "android\app\build.gradle.kts" >nul
if %errorlevel% equ 0 (
    echo ✅ Release configuration looks good
) else (
    echo ⚠️ Warning: Check release configuration in build.gradle
)

echo.
echo ==========================================
echo Verification Complete!
echo ==========================================
echo.
echo To build the test APK, run:
echo build_test_apk.bat
echo.
pause
