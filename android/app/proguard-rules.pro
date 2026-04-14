# Keep sqflite and its FFI implementation
-keep class com.tekartik.** { *; }

# Keep sqlite3_flutter_libs and its native interface
-keep class org.sqlite.** { *; }
-keep class sqlite3.** { *; }

# Prevent stripping of native libraries (.so files)
-keepclassmembers class * {
    native <methods>;
}


# Ignore missing Google Play Core classes (referenced by Flutter embedding)
-dontwarn com.google.android.play.core.**
