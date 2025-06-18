@echo off
echo Building Gyefo Clocking App APK...
echo.

echo Step 1: Cleaning project...
call flutter clean

echo.
echo Step 2: Getting dependencies...
call flutter pub get

echo.
echo Step 3: Building debug APK...
call flutter build apk --debug

echo.
echo Step 4: Checking for APK files...
if exist "build\app\outputs\flutter-apk\app-debug.apk" (
    echo Success! APK built at: build\app\outputs\flutter-apk\app-debug.apk
    echo File size:
    dir "build\app\outputs\flutter-apk\app-debug.apk" | findstr "app-debug.apk"
) else (
    echo APK not found. Checking for other APK files...
    if exist "build\app\outputs\flutter-apk\" (
        dir "build\app\outputs\flutter-apk\*.apk"
    ) else (
        echo No APK output directory found.
    )
)

echo.
echo Build process completed.
pause
