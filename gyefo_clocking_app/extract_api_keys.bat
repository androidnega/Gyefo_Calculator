@echo off
echo ====================================================
echo    EXTRACT API KEYS FROM FIREBASE CONFIG
echo ====================================================
echo.
echo The following API keys were found in your Firebase config:
echo Please copy these to your .env file:
echo.

findstr /i "apiKey" lib\firebase_options.dart
findstr /i "appId" lib\firebase_options.dart  
findstr /i "messagingSenderId" lib\firebase_options.dart
findstr /i "projectId" lib\firebase_options.dart
findstr /i "storageBucket" lib\firebase_options.dart
findstr /i "authDomain" lib\firebase_options.dart

echo.
echo ====================================================
echo Copy these values to your .env file!
echo Then delete lib\firebase_options.dart for security
echo ====================================================
pause
