# Firebase Authentication Setup Instructions

## ⚡ QUICK FIX for 503 Error

1. **RIGHT NOW**: Open [Firebase Console](https://console.firebase.google.com/)
2. Select your project "Gyefo Clocks"
3. Click "Authentication" in left sidebar
4. Click "Get Started" or "Sign-in methods" tab
5. Enable "Email/Password" sign-in method if not enabled
6. **IMPORTANT**: Wait 2-3 minutes for service to initialize
7. Try logging in again

The 503 error usually means Authentication needs to be activated. This should fix it immediately.

## 🔄 Detailed Setup Instructions

1. **Enable Authentication in Firebase Console**
   1. Go to: https://console.firebase.google.com/project/gyefo-clocks/authentication
   2. Click "Get Started" if not already enabled
   3. Enable "Email/Password" authentication method:
      - Click "Sign-in methods" tab
      - Find "Email/Password" in the list
      - Click "Enable"
      - Save changes

2. **Verify Web App Configuration**
   1. Go to: https://console.firebase.google.com/project/gyefo-clocks/settings/general
   2. Under "Your apps", find the web app
   3. Make sure the domain is authorized:
      - Click "Add domain" if localhost is not listed
      - Add: `localhost`
      - Add: `127.0.0.1`

3. **Reset and Test**
   1. Clear browser cache and cookies
   2. Hard refresh the app page (Ctrl+F5)
   3. Try logging in again

## 🔍 Current Configuration
Your Firebase web configuration appears correct:
```javascript
{
    apiKey: 'AIzaSyCFcsbWvFcJtXV7YAvptYRMovPGoLR2MX4',
    appId: '1:791824155693:web:0622266e56fbf3cc8464a4',
    projectId: 'gyefo-clocks',
    authDomain: 'gyefo-clocks.firebaseapp.com'
}
```

## 🛠️ Additional Troubleshooting

If the above steps don't resolve the issue:

1. **Check Firebase Project Status**
   - Visit: https://status.firebase.google.com/
   - Verify there are no ongoing service disruptions

2. **Network Issues**
   - Check if you can reach Firebase services:
   ```powershell
   Test-NetConnection -ComputerName identitytoolkit.googleapis.com -Port 443
   ```

3. **Temporary Workaround**
   If needed, you can create test accounts directly in Firebase Console while debugging:
   1. Go to Authentication > Users
   2. Click "Add User"
   3. Create test accounts manually:
      - Manager: manager@test.com / password123
      - Worker: worker@test.com / password123

## 🔐 Security Note
- Make sure to use environment variables for API keys in production
- Current setup is for development only
- Review Firebase Security Rules before deployment

Need help? Try running:
```powershell
firebase init auth
firebase deploy --only auth
```
