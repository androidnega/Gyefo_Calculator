@echo off
echo ========================================
echo Building Test APK for Gyefo Clocking App
echo ========================================

echo.
echo Step 1: Cleaning project...
call flutter clean

echo.
echo Step 2: Getting dependencies...
call flutter pub get

echo.
echo Step 3: Running build_runner...
call dart run build_runner build --delete-conflicting-outputs

echo.
echo Step 4: Building test APK...
call flutter build apk --debug

echo.
echo ========================================
echo Build Complete!
echo ========================================
echo.
echo The debug APK can be found at:
echo build\app\outputs\flutter-apk\app-debug.apk
echo.
echo To install on a connected device, run:
echo flutter install
echo.
pause
