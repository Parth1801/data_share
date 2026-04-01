package com.example.datatransfer

import android.media.MediaScannerConnection
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Media scanner — notifies gallery after file is received
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "datatransfer/media_scanner")
            .setMethodCallHandler { call, result ->
                if (call.method == "scanFile") {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        MediaScannerConnection.scanFile(this, arrayOf(path), null) { _, _ -> }
                        result.success(null)
                    } else {
                        result.error("INVALID_PATH", "Path is null", null)
                    }
                } else {
                    result.notImplemented()
                }
            }

        // APK path resolver — returns the real .apk file path for a package name
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "datatransfer/apk_path")
            .setMethodCallHandler { call, result ->
                if (call.method == "getApkPath") {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        try {
                            val info = packageManager.getApplicationInfo(packageName, 0)
                            result.success(info.sourceDir)
                        } catch (e: Exception) {
                            result.error("NOT_FOUND", "APK not found for $packageName", null)
                        }
                    } else {
                        result.error("INVALID_PACKAGE", "Package name is null", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
