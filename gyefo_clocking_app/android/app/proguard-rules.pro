# Flutter and Firebase ProGuard rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase rules
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firestore rules
-keep class com.google.firestore.** { *; }
-dontwarn com.google.firestore.**

# Auth rules
-keep class com.google.firebase.auth.** { *; }
-dontwarn com.google.firebase.auth.**

# Messaging rules
-keep class com.google.firebase.messaging.** { *; }
-dontwarn com.google.firebase.messaging.**

# Google Maps rules
-keep class com.google.android.gms.maps.** { *; }
-dontwarn com.google.android.gms.maps.**

# Location rules
-keep class com.google.android.gms.location.** { *; }
-dontwarn com.google.android.gms.location.**

# Prevent stripping of native methods
-keepclasseswithmembernames class * {
    native <methods>;
}
