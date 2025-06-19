# Web Platform Setup Guide

This document explains how to properly configure and deploy the Gyefo Clocking App for web platforms.

## Environment Configuration

### Prerequisites
1. Flutter SDK with web support enabled
2. Firebase project with web app configured
3. Google Maps JavaScript API key (if using location features)

### Environment Variables Setup

1. **Copy the environment template:**
   ```bash
   copy .env.template .env
   ```

2. **Configure the following variables in `.env`:**
   ```properties
   # Firebase Web Configuration
   FIREBASE_API_KEY_WEB=your_web_api_key_here
   FIREBASE_APP_ID_WEB=your_web_app_id_here
   FIREBASE_PROJECT_ID=your_project_id_here
   FIREBASE_AUTH_DOMAIN=your_project_id.firebaseapp.com
   FIREBASE_STORAGE_BUCKET=your_project_id.firebasestorage.app
   FIREBASE_MESSAGING_SENDER_ID=your_sender_id_here
   
   # Google Maps API
   GOOGLE_MAPS_API_KEY=your_google_maps_api_key_here
   ```

### Web-Specific Configuration

The app includes web-specific services and configuration:

1. **WebApiService** (`lib/services/web_api_service.dart`)
   - Dynamically loads Google Maps JavaScript API
   - Validates Firebase configuration for web
   - Handles web-specific initialization

2. **Environment-based Firebase Options** (`lib/config/firebase_options_secure.dart`)
   - Uses environment variables instead of hardcoded values
   - Provides platform-specific configurations
   - Includes validation and error handling

## Building for Web

### Automated Setup (Recommended)

1. **Run the web environment setup script:**
   ```bash
   setup_web_env.bat
   ```
   This script will:
   - Validate your `.env` file
   - Update web files with environment variables
   - Configure Google Maps API loading
   - Set up Firebase configuration

2. **Build the web application:**
   ```bash
   flutter build web --dart-define-from-file=.env
   ```

### Manual Setup

If you prefer manual configuration:

1. **Update `web/index.html`** to load Google Maps API:
   ```html
   <script id="google-maps-api" 
           src="https://maps.googleapis.com/maps/api/js?key=YOUR_API_KEY" 
           async defer></script>
   ```

2. **Pass environment variables during build:**
   ```bash
   flutter build web \
     --dart-define=FIREBASE_API_KEY_WEB=your_key \
     --dart-define=FIREBASE_PROJECT_ID=your_project \
     --dart-define=GOOGLE_MAPS_API_KEY=your_maps_key
   ```

## Security Considerations

### API Key Protection

1. **Never commit API keys to version control**
   - The `.env` file is included in `.gitignore`
   - Use environment variables in production
   - Rotate keys regularly

2. **Use domain restrictions** for web API keys:
   - Restrict Google Maps API key to your domain
   - Configure Firebase security rules appropriately
   - Use HTTPS for all production deployments

3. **Environment-specific configurations**:
   - Use different API keys for development/staging/production
   - Configure Firebase projects per environment
   - Implement proper error handling for missing keys

### Firebase Security

1. **Firestore Rules**: Configure appropriate read/write rules
2. **Authentication**: Ensure proper user authentication flows
3. **API Permissions**: Limit API key permissions to required services only

## Deployment

### Firebase Hosting (Recommended)

1. **Install Firebase CLI:**
   ```bash
   npm install -g firebase-tools
   ```

2. **Login and initialize:**
   ```bash
   firebase login
   firebase init hosting
   ```

3. **Build and deploy:**
   ```bash
   setup_web_env.bat
   flutter build web --dart-define-from-file=.env
   firebase deploy
   ```

### Other Hosting Providers

For other hosting providers:

1. Build the web app as described above
2. Upload the contents of `build/web/` to your hosting provider
3. Ensure environment variables are properly configured in your hosting environment
4. Configure HTTPS and domain settings

## Troubleshooting

### Common Issues

1. **Google Maps not loading:**
   - Check API key configuration in `.env`
   - Verify domain restrictions on Google Cloud Console
   - Check browser console for JavaScript errors

2. **Firebase connection issues:**
   - Verify all Firebase environment variables are set
   - Check Firebase project configuration
   - Ensure web app is properly configured in Firebase Console

3. **Environment variables not loading:**
   - Verify `.env` file exists and is properly formatted
   - Check that `setup_web_env.bat` completed successfully
   - Ensure build command includes `--dart-define-from-file=.env`

### Debug Mode

To debug environment configuration:

1. **Check configuration validity:**
   ```dart
   import 'config/env_config.dart';
   
   // In your app initialization
   if (!EnvConfig.validateConfig()) {
     debugPrint('Environment configuration issues detected');
   }
   ```

2. **Test web services:**
   ```dart
   import 'services/web_api_service.dart';
   
   // Test Firebase config
   final isValid = WebApiService.validateWebConfig();
   debugPrint('Web config valid: $isValid');
   ```

## File Structure

```
web/
├── index.html              # Main HTML file with API loading
├── firebase-config.html    # Firebase configuration template
├── manifest.json          # Web app manifest
├── favicon.png            # App icon
└── icons/                 # App icons for different sizes

lib/
├── config/
│   ├── env_config.dart           # Environment variable manager
│   └── firebase_options_secure.dart  # Secure Firebase options
├── services/
│   ├── web_api_service.dart      # Web-specific API service
│   └── web_api_service_stub.dart # Non-web stub
└── main.dart                     # App entry point with web init

setup_web_env.bat           # Web environment setup script
.env                        # Environment variables (not in git)
.env.template              # Environment template
```

## Best Practices

1. **Always use the setup script** before building for web
2. **Test locally** before deploying to production
3. **Use HTTPS** for all production deployments
4. **Monitor API usage** to avoid unexpected costs
5. **Implement proper error handling** for missing configurations
6. **Keep environment variables secure** and never commit them to version control

## Support

For additional help:
- Check Flutter web documentation
- Review Firebase web setup guides
- Consult Google Maps JavaScript API documentation
- Review the app's error logs and debug output
