package com.relayshell.relayshell

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Adds the one piece of screen protection Flutter cannot express (SPEC 19).
 *
 * FLAG_SECURE stops Android from putting the window into the recent-apps
 * thumbnail and blocks screenshots, which is what keeps terminal output off the
 * app switcher while the app is locked. It is toggled from Dart rather than set
 * permanently, because users who have not enabled the app lock should still be
 * able to screenshot their own terminal.
 */
class MainActivity : FlutterActivity() {
    private companion object {
        const val CHANNEL = "relayshell/window"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        val secure = call.argument<Boolean>("secure") ?: false
                        runOnUiThread {
                            if (secure) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            }
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
