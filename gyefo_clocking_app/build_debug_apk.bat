@echo off
echo Building Gyefo Clocking App Debug APK...
echo.

echo Step 1: Cleaning project...
flutter clean

echo Step 2: Getting dependencies...
flutter pub get

echo Step 3: Building debug APK...
flutter build apk --debug

echo.
if exist "build\app\outputs\flutter-apk\app-debug.apk" (
    echo ✅ SUCCESS: APK built successfully!
    echo Location: build\app\outputs\flutter-apk\app-debug.apk
    echo.
    echo APK size:
    dir "build\app\outputs\flutter-apk\app-debug.apk" /s
) else (
    echo ❌ ERROR: APK build failed!
    echo Check the output above for errors.
)

echo.
pause
