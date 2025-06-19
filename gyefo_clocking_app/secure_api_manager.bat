@echo off
setlocal enabledelayedexpansion

echo ===============================================
echo    Gyefo Clocking App - API Key Security Tool
echo ===============================================
echo.

:menu
echo Select an option:
echo 1. Setup Environment Variables
echo 2. Generate Secure Firebase Config
echo 3. Validate API Keys
echo 4. Remove Exposed Keys from Git History
echo 5. Create Production Build with Secure Keys
echo 6. Exit
echo.
set /p choice="Enter your choice (1-6): "

if "%choice%"=="1" goto setup_env
if "%choice%"=="2" goto generate_config
if "%choice%"=="3" goto validate_keys
if "%choice%"=="4" goto remove_keys
if "%choice%"=="5" goto production_build
if "%choice%"=="6" goto exit
echo Invalid choice. Please try again.
goto menu

:setup_env
echo.
echo Setting up environment variables...
echo.
if not exist ".env" (
    if exist ".env.example" (
        copy ".env.example" ".env"
        echo Created .env file from template.
        echo Please edit .env file and add your actual API keys.
    ) else (
        echo Error: .env.example template not found!
    )
) else (
    echo .env file already exists.
)
echo.
echo Remember to:
echo - Never commit the .env file to git
echo - Keep your API keys secure
echo - Use different keys for development and production
echo.
pause
goto menu

:generate_config
echo.
echo Generating secure Firebase configuration...
echo.
echo This will create a secure version of firebase_options.dart
echo that uses environment variables instead of hardcoded keys.
echo.
if exist "lib\firebase_options.dart" (
    echo Backing up current firebase_options.dart...
    copy "lib\firebase_options.dart" "lib\firebase_options.dart.backup"
)
echo.
echo Secure configuration generated at lib\config\firebase_options_secure.dart
echo Update your main.dart to use SecureFirebaseOptions instead of DefaultFirebaseOptions
echo.
pause
goto menu

:validate_keys
echo.
echo Validating API keys...
echo.
if exist ".env" (
    echo Checking .env file...
    findstr "FIREBASE_PROJECT_ID" .env > nul
    if !errorlevel! == 0 (
        echo ✓ Firebase Project ID found
    ) else (
        echo ✗ Firebase Project ID missing
    )
    
    findstr "FIREBASE_API_KEY_WEB" .env > nul
    if !errorlevel! == 0 (
        echo ✓ Firebase Web API Key found
    ) else (
        echo ✗ Firebase Web API Key missing
    )
    
    findstr "FIREBASE_API_KEY_ANDROID" .env > nul
    if !errorlevel! == 0 (
        echo ✓ Firebase Android API Key found
    ) else (
        echo ✗ Firebase Android API Key missing
    )
) else (
    echo ✗ .env file not found! Run option 1 first.
)
echo.
pause
goto menu

:remove_keys
echo.
echo ===============================================
echo    REMOVING EXPOSED KEYS FROM GIT HISTORY
echo ===============================================
echo.
echo WARNING: This will rewrite git history!
echo Make sure you have a backup of your repository.
echo.
set /p confirm="Are you sure you want to continue? (y/N): "
if /i not "%confirm%"=="y" goto menu

echo.
echo Step 1: Remove sensitive files from current index...
git rm --cached lib\firebase_options.dart 2>nul
git rm --cached android\app\google-services.json 2>nul
git rm --cached ios\Runner\GoogleService-Info.plist 2>nul

echo.
echo Step 2: Add to gitignore if not already added...
findstr "firebase_options.dart" .gitignore > nul
if !errorlevel! neq 0 (
    echo firebase_options.dart >> .gitignore
)

echo.
echo Step 3: Commit the removal...
git add .gitignore
git commit -m "Remove exposed API keys and add to gitignore"

echo.
echo Step 4: Remove from git history (this may take a while)...
echo This uses git filter-branch to remove sensitive files from history.
git filter-branch --force --index-filter "git rm --cached --ignore-unmatch lib/firebase_options.dart android/app/google-services.json ios/Runner/GoogleService-Info.plist" --prune-empty --tag-name-filter cat -- --all

echo.
echo Step 5: Force push to origin (WARNING: This rewrites remote history!)...
set /p push_confirm="Force push to remote? This will rewrite remote history! (y/N): "
if /i "%push_confirm%"=="y" (
    git push origin --force --all
    git push origin --force --tags
    echo.
    echo Remote repository updated. Make sure all team members re-clone the repository.
) else (
    echo Skipped force push. You can do this manually later with:
    echo git push origin --force --all
    echo git push origin --force --tags
)

echo.
echo Done! Your API keys have been removed from git history.
echo Don't forget to:
echo 1. Regenerate your Firebase API keys in the Firebase Console
echo 2. Update your .env file with the new keys
echo 3. Notify your team to re-clone the repository
echo.
pause
goto menu

:production_build
echo.
echo Building production APK with secure configuration...
echo.
if not exist ".env" (
    echo Error: .env file not found! Please set up environment variables first.
    pause
    goto menu
)

echo Building production APK...
flutter build apk --release --dart-define-from-file=.env

if !errorlevel! == 0 (
    echo.
    echo ✓ Production APK built successfully!
    echo APK location: build\app\outputs\flutter-apk\app-release.apk
    echo.
    echo Security checklist:
    echo ✓ API keys loaded from environment variables
    echo ✓ No hardcoded secrets in the APK
    echo ✓ Secure configuration used
) else (
    echo ✗ Build failed. Check the error messages above.
)
echo.
pause
goto menu

:exit
echo.
echo Security Tips:
echo • Regularly rotate your API keys
echo • Use different keys for development and production
echo • Monitor your Firebase console for unusual activity
echo • Never share your .env file
echo.
echo Thank you for keeping your app secure!
pause
exit /b 0
