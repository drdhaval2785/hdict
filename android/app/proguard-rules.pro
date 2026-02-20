# Keep sqflite and its FFI implementation
-keep class com.tekartik.** { *; }

# Keep sqlite3_flutter_libs and its native interface
-keep class org.sqlite.** { *; }
-keep class sqlite3.** { *; }

# Prevent stripping of native libraries (.so files)
-keepclassmembers class * {
    native <methods>;
}

# Keep Flutter plugin registry and related classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep common Flutter plugin interfaces
-keep class * extends io.flutter.plugin.common.MethodCallHandler
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin

# Ignore missing Google Play Core classes (referenced by Flutter embedding)
-dontwarn com.google.android.play.core.**
