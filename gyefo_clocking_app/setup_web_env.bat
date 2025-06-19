@echo off
REM Web Build Environment Configuration Script
REM This script replaces environment variable placeholders in web files with actual values
echo Setting up web environment configuration...

REM Check if .env file exists
if not exist ".env" (
    echo Error: .env file not found!
    echo Please copy .env.template to .env and configure your values.
    pause
    exit /b 1
)

REM Load environment variables from .env file
for /f "usebackq tokens=1,2 delims==" %%a in (".env") do (
    set "%%a=%%b"
)

echo Found environment variables:
echo - FIREBASE_PROJECT_ID: %FIREBASE_PROJECT_ID%
echo - FIREBASE_API_KEY_WEB: %FIREBASE_API_KEY_WEB%
echo - GOOGLE_MAPS_API_KEY: %GOOGLE_MAPS_API_KEY%

REM Create web directory if it doesn't exist
if not exist "web" mkdir web

REM Update web/index.html with Google Maps API key
if exist "web\index.html" (
    echo Updating Google Maps API in web/index.html...
    powershell -Command "(Get-Content 'web\index.html') -replace 'id=\"google-maps-api\" async defer></script>', 'id=\"google-maps-api\" src=\"https://maps.googleapis.com/maps/api/js?key=%GOOGLE_MAPS_API_KEY%\" async defer></script>' | Set-Content 'web\index.html'"
)

REM Update firebase-config.html with actual values
if exist "web\firebase-config.html" (
    echo Updating Firebase config in web/firebase-config.html...
    powershell -Command "(Get-Content 'web\firebase-config.html') -replace '{{FIREBASE_API_KEY_WEB}}', '%FIREBASE_API_KEY_WEB%' | Set-Content 'web\firebase-config.html'"
    powershell -Command "(Get-Content 'web\firebase-config.html') -replace '{{FIREBASE_AUTH_DOMAIN}}', '%FIREBASE_AUTH_DOMAIN%' | Set-Content 'web\firebase-config.html'"
    powershell -Command "(Get-Content 'web\firebase-config.html') -replace '{{FIREBASE_PROJECT_ID}}', '%FIREBASE_PROJECT_ID%' | Set-Content 'web\firebase-config.html'"
    powershell -Command "(Get-Content 'web\firebase-config.html') -replace '{{FIREBASE_STORAGE_BUCKET}}', '%FIREBASE_STORAGE_BUCKET%' | Set-Content 'web\firebase-config.html'"
    powershell -Command "(Get-Content 'web\firebase-config.html') -replace '{{FIREBASE_MESSAGING_SENDER_ID}}', '%FIREBASE_MESSAGING_SENDER_ID%' | Set-Content 'web\firebase-config.html'"
    powershell -Command "(Get-Content 'web\firebase-config.html') -replace '{{FIREBASE_APP_ID_WEB}}', '%FIREBASE_APP_ID_WEB%' | Set-Content 'web\firebase-config.html'"
)

echo Web environment configuration completed!
echo.
echo Next steps:
echo 1. Run 'flutter build web' to build for web platform
echo 2. Environment variables are now properly configured for web deployment
echo.
pause
