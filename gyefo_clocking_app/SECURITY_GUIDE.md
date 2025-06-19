# 🔒 API Security & GitHub Protection Guide

## 🚨 IMMEDIATE ACTION REQUIRED

Your Firebase API keys have been exposed in your GitHub repository. Follow these steps **immediately**:

### 1. **REGENERATE ALL EXPOSED API KEYS** (Critical - Do this first!)

#### Firebase Console (console.firebase.google.com):
1. Go to Project Settings → General → Your apps
2. For each app (Web, Android, iOS):
   - Delete the current app configuration
   - Re-add the app with the same package name/bundle ID
   - Download new configuration files
3. Update Firebase Security Rules if needed
4. Check Firebase Authentication settings

#### Google Cloud Console (console.cloud.google.com):
1. Go to APIs & Services → Credentials
2. Find the API keys related to your project
3. Delete the exposed keys
4. Create new API keys with proper restrictions

### 2. **REMOVE KEYS FROM GIT HISTORY**

Run the security script:
```bash
# Windows
secure_api_manager.bat

# Or manually:
git rm --cached lib/firebase_options.dart
git rm --cached android/app/google-services.json
git commit -m "Remove exposed API keys"
git filter-branch --force --index-filter "git rm --cached --ignore-unmatch lib/firebase_options.dart android/app/google-services.json" --prune-empty --tag-name-filter cat -- --all
git push origin --force --all
```

### 3. **SETUP SECURE ENVIRONMENT**

1. **Copy environment template:**
   ```bash
   cp .env.example .env
   ```

2. **Add your NEW API keys to .env:**
   ```
   FIREBASE_API_KEY_WEB=your-new-web-key
   FIREBASE_API_KEY_ANDROID=your-new-android-key
   FIREBASE_API_KEY_IOS=your-new-ios-key
   FIREBASE_PROJECT_ID=your-project-id
   # ... other keys
   ```

3. **Update your main.dart to use secure configuration:**
   ```dart
   // Replace this:
   import 'firebase_options.dart';
   options: DefaultFirebaseOptions.currentPlatform,
   
   // With this:
   import 'config/firebase_options_secure.dart';
   options: SecureFirebaseOptions.currentPlatform,
   ```

## 🛡️ SECURITY BEST PRACTICES

### Environment Variables Setup

1. **Never commit these files:**
   - `.env`
   - `firebase_options.dart` (if it contains hardcoded keys)
   - `google-services.json`
   - `GoogleService-Info.plist`

2. **Use environment-specific keys:**
   - Development: Limited scope, test data only
   - Staging: Staging environment with restricted access
   - Production: Full production access with all security enabled

3. **Set up proper Firebase Security Rules:**
   ```javascript
   // Firestore Security Rules Example
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       // Only authenticated users can read/write their own data
       match /users/{userId} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
       }
       
       // Managers can access attendance data
       match /attendance/{document} {
         allow read, write: if request.auth != null && 
           get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'manager';
       }
     }
   }
   ```

### GitHub Repository Security

1. **Enable GitHub Security Features:**
   - Go to Settings → Security & Analysis
   - Enable "Dependency graph"
   - Enable "Dependabot alerts"
   - Enable "Dependabot security updates"
   - Enable "Secret scanning"

2. **Add Repository Secrets for CI/CD:**
   - Go to Settings → Secrets and Variables → Actions
   - Add your environment variables as repository secrets
   - Use them in GitHub Actions workflows

3. **Set up Branch Protection:**
   - Require pull request reviews
   - Require status checks to pass
   - Restrict who can push to main branch

### Firebase Security Configuration

1. **API Key Restrictions:**
   ```
   Web Key Restrictions:
   - HTTP referrers: your-domain.com/*
   - APIs: Firebase Auth, Firestore, Storage
   
   Android Key Restrictions:
   - Android apps: com.example.gyefo_clocking_app
   - APIs: Firebase Auth, Firestore, Storage
   
   iOS Key Restrictions:
   - iOS apps: com.example.gyefoClockingApp
   - APIs: Firebase Auth, Firestore, Storage
   ```

2. **Firebase Authentication Rules:**
   - Enable only required sign-in providers
   - Set up proper user validation
   - Implement role-based access control

3. **Firestore Security Rules:**
   - Implement proper user authentication checks
   - Use role-based document access
   - Validate data before writing

## 🚀 PRODUCTION DEPLOYMENT

### Secure Build Process

1. **Environment Variables in CI/CD:**
   ```yaml
   # GitHub Actions example
   - name: Build APK
     run: flutter build apk --release
     env:
       FIREBASE_API_KEY_ANDROID: ${{ secrets.FIREBASE_API_KEY_ANDROID }}
       FIREBASE_PROJECT_ID: ${{ secrets.FIREBASE_PROJECT_ID }}
   ```

2. **Local Secure Build:**
   ```bash
   # Use the secure build script
   secure_api_manager.bat
   # Choose option 5 for production build
   ```

### Monitoring & Alerts

1. **Set up Firebase Monitoring:**
   - Enable Firebase Analytics
   - Set up Firebase Crashlytics
   - Monitor Firebase Authentication usage

2. **GitHub Monitoring:**
   - Watch for secret scanning alerts
   - Monitor dependency vulnerabilities
   - Review access logs regularly

## 📋 SECURITY CHECKLIST

- [ ] Regenerated all exposed Firebase API keys
- [ ] Removed sensitive files from git history
- [ ] Set up .env file with new keys
- [ ] Updated main.dart to use SecureFirebaseOptions
- [ ] Configured Firebase Security Rules
- [ ] Set up API key restrictions in Google Cloud Console
- [ ] Enabled GitHub security features
- [ ] Set up proper CI/CD with secrets
- [ ] Tested app with new secure configuration
- [ ] Updated team on new security practices

## 🆘 EMERGENCY CONTACTS

If you suspect a security breach:

1. **Immediately disable compromised API keys**
2. **Check Firebase Authentication logs for suspicious activity**
3. **Review Firestore access logs**
4. **Rotate all API keys and secrets**
5. **Update all team members**

## 📚 ADDITIONAL RESOURCES

- [Firebase Security Guide](https://firebase.google.com/docs/rules)
- [GitHub Security Features](https://docs.github.com/en/code-security)
- [Google Cloud API Security](https://cloud.google.com/docs/security)
- [Flutter Security Best Practices](https://flutter.dev/docs/deployment/security)

Remember: **Security is not a one-time setup, it's an ongoing process!**
