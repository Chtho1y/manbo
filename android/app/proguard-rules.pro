# Flutter的核心类和方法保持不变
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# 保留应用的所有类，防止混淆
-keep class com.aiqwq.manbo.** { *; }

# 保留 Play Core 库的所有类
-keep class com.google.android.play.core.** { *; }
-keep interface com.google.android.play.core.** { *; }

# 保留使用SharedPreferences的类
-keep class androidx.preference.** { *; }

# 保留sqflite的类
-keep class com.tekartik.sqflite.** { *; }

# 保留 Flutter 插件相关的类
-keep class io.flutter.plugins.** { *; }

# 保留path_provider的类
# -keep class io.flutter.plugins.pathprovider.** { *; }

# 保留image_picker的类
# -keep class io.flutter.plugins.imagepicker.** { *; }

# 保留webview_flutter的类
# -keep class io.flutter.plugins.webviewflutter.** { *; }

# 保留dio相关的类
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# 保留flutter_svg的类
-keep class com.caverock.androidsvg.** { *; }

# 保留uuid库的类
-keep class com.benasher44.uuid.** { *; }

# 保留所有注解
-keepattributes *Annotation*

# 保留所有枚举类的values和valueOf方法
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# 保留Gson库（如果使用了Dio的序列化功能）
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# 保留Flutter生成的R类
-keep class **.R$* { *; }

# 保留任何使用反射的类（根据需要添加）
# 如果您的应用或依赖库使用了反射，请在此添加相应的保留规则

# 示例：如果使用了某些特定库需要保留
# -keep class com.example.library.** { *; }

# 防止混淆Flutter的JNI桥接类
-keep class io.flutter.embedding.engine.FlutterJNI { *; }

# 保留Flutter的MainActivity
-keep class com.aiqwq.manbo.MainActivity { *; }

# 保留Flutter插件注册相关的类
-keep class io.flutter.plugins.** { *; }

# Please add these rules to your existing keep rules in order to suppress warnings.
# This is generated automatically by the Android Gradle plugin.
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
