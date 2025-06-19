@echo off
echo 🔍 Scanning for exposed API keys in GitHub repository...
echo.

REM Check for common API key patterns
echo Checking for potential API keys in commit history...
git log --all --full-history --source -- "*.dart" "*.json" "*.js" "*.ts" | findstr /i "api_key\|apikey\|secret\|token\|firebase\|google" > api_scan_results.txt

echo.
echo 📋 Scan complete! Check api_scan_results.txt for results.
echo.

REM Display immediate GitHub security recommendations
echo 🛡️  GITHUB SECURITY CHECKLIST:
echo.
echo 1. ✅ Remove sensitive files from repository
echo 2. ✅ Update .gitignore to prevent future exposure  
echo 3. 🔄 Rotate all exposed API keys immediately
echo 4. 🔄 Enable GitHub secret scanning
echo 5. 🔄 Set up GitHub repository security alerts
echo.

echo 🚨 IMMEDIATE ACTIONS REQUIRED:
echo.
echo 1. Go to your Firebase Console ^& regenerate API keys
echo 2. Go to GitHub Settings ^> Security ^& Analysis
echo 3. Enable "Dependency graph", "Dependabot alerts", ^& "Secret scanning"
echo 4. Add rotated keys to your .env file (not in git)
echo.

echo 💡 To rotate Firebase keys:
echo    - Visit: https://console.firebase.google.com/project/your-project/settings/general
echo    - Go to "Your apps" section
echo    - Delete current app configuration
echo    - Add new app configuration with fresh keys
echo    - Update your .env file with new keys
echo.

pause
