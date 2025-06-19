@echo off
setlocal enabledelayedexpansion

echo ====================================================
echo    GYEFO CLOCKING APP - SECURE API SETUP
echo ====================================================
echo.

echo [1/4] Checking for sensitive files...
if exist "firebase_options.dart" (
    echo WARNING: Original firebase_options.dart found!
    echo This file contains exposed API keys.
    set /p choice="Do you want to move it to backup? (y/n): "
    if /i "!choice!"=="y" (
        move "firebase_options.dart" "firebase_options.backup.dart"
        echo Moved to firebase_options.backup.dart
    )
)

echo.
echo [2/4] Checking environment file...
if not exist ".env" (
    if exist ".env.template" (
        echo Creating .env file from template...
        copy ".env.template" ".env"
        echo.
        echo IMPORTANT: Please edit .env file with your actual API keys!
        echo The file is located at: %CD%\.env
    ) else (
        echo ERROR: .env.template not found!
        exit /b 1
    )
) else (
    echo .env file already exists.
)

echo.
echo [3/4] Checking .gitignore...
if not exist ".gitignore" (
    echo Creating .gitignore file...
    (
        echo # Environment files
        echo .env
        echo .env.local
        echo .env.*.local
        echo.
        echo # Firebase config backups
        echo firebase_options.backup.dart
        echo.
        echo # API keys and secrets
        echo *.key
        echo *.pem
        echo google-services.json
        echo GoogleService-Info.plist
        echo.
        echo # Build outputs
        echo /build/
        echo /android/key.properties
    ) > .gitignore
    echo Created .gitignore
) else (
    echo .gitignore already exists.
)

echo.
echo [4/4] Removing tracked sensitive files from git...
git rm --cached firebase_options.dart 2>nul
git rm --cached android/app/google-services.json 2>nul
git rm --cached ios/Runner/GoogleService-Info.plist 2>nul

echo.
echo ====================================================
echo                    SETUP COMPLETE!
echo ====================================================
echo.
echo NEXT STEPS:
echo 1. Edit .env file with your actual API keys
echo 2. Run: flutter pub get
echo 3. Run: git add . && git commit -m "Secure API configuration"
echo 4. Your API keys are now secure!
echo.
echo WARNING: Never commit .env file to git!
echo ====================================================

pause
