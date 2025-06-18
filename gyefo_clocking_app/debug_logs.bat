@echo off
echo Starting Android Debug Bridge (adb) logcat for Gyefo app...
echo Press Ctrl+C to stop monitoring
echo.
echo Looking for Flutter and Firebase related logs:
echo.
adb logcat | findstr /i "flutter firebase gyefo"
