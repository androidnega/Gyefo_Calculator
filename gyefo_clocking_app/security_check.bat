@echo off
REM Security Verification Script
REM Checks that no sensitive files are committed to git repository

echo ================================
echo Security Verification Report
echo ================================
echo.

echo Checking for sensitive files in git repository...
echo.

REM Check for .env files
git ls-files | findstr /C:".env" >nul
if %errorlevel% equ 0 (
    echo ❌ WARNING: .env files found in git repository!
    git ls-files | findstr /C:".env"
) else (
    echo ✅ .env files properly excluded from git
)

REM Check for API key files
git ls-files | findstr /C:"api_key" >nul
if %errorlevel% equ 0 (
    echo ❌ WARNING: API key files found in git repository!
    git ls-files | findstr /C:"api_key"
) else (
    echo ✅ API key files properly excluded from git
)

REM Check for Firebase config files
git ls-files | findstr /C:"google-services.json" >nul
if %errorlevel% equ 0 (
    echo ❌ WARNING: google-services.json found in git repository!
    git ls-files | findstr /C:"google-services.json"
) else (
    echo ✅ google-services.json properly excluded from git
)

REM Check for certificate files
git ls-files | findstr /E:".p12 .jks .keystore .pem" >nul
if %errorlevel% equ 0 (
    echo ❌ WARNING: Certificate files found in git repository!
    git ls-files | findstr /E:".p12 .jks .keystore .pem"
) else (
    echo ✅ Certificate files properly excluded from git
)

echo.
echo ================================
echo Git Status:
echo ================================
git status --porcelain

echo.
echo ================================
echo Recent Commits:
echo ================================
git log --oneline -3

echo.
echo ================================
echo Security Check Complete
echo ================================
