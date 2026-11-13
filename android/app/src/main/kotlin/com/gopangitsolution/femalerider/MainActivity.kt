package com.gopangitsolution.femalerider

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Lets Dart know whether a Google Maps key is configured, so the app can show a
        // graceful placeholder instead of an empty/broken map when it is missing.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.gopangitsolution.femalerider/platform")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isMapsConfigured" -> {
                        val key = try {
                            val info = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
                            info.metaData?.getString("com.google.android.geo.API_KEY") ?: ""
                        } catch (e: Exception) {
                            ""
                        }
                        result.success(key.isNotBlank())
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
