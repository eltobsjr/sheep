package dev.elto.sheep

import android.webkit.CookieManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val cookieChannel = "sheep/cookies"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, cookieChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCookies" -> {
                        val url = call.argument<String>("url")
                        if (url == null) {
                            result.error("INVALID_ARG", "url is required", null)
                        } else {
                            // Returns the full cookie string for the URL,
                            // including HttpOnly cookies that JS cannot read.
                            val cookies = CookieManager.getInstance().getCookie(url)
                            result.success(cookies)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
