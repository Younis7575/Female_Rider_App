# Flutter / plugins keep rules (R8)
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.**
