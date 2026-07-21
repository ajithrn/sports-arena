package com.sportsarena.sports_arena

import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration
import android.os.SystemClock
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import androidx.webkit.ProxyConfig
import androidx.webkit.ProxyController
import androidx.webkit.WebViewFeature
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executor

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.sportsarena/platform"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isTv" -> {
                        val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
                        val isTv = uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
                        result.success(isTv)
                    }
                    "tapWebViewCenter" -> {
                        val webView = findWebView(window.decorView)
                        if (webView != null) {
                            val x = webView.width / 2f
                            val y = webView.height / 2f
                            val downTime = SystemClock.uptimeMillis()
                            val downEvent = MotionEvent.obtain(
                                downTime, downTime,
                                MotionEvent.ACTION_DOWN, x, y, 0
                            )
                            val upEvent = MotionEvent.obtain(
                                downTime, downTime + 100,
                                MotionEvent.ACTION_UP, x, y, 0
                            )
                            webView.dispatchTouchEvent(downEvent)
                            webView.dispatchTouchEvent(upEvent)
                            downEvent.recycle()
                            upEvent.recycle()
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    "setWebViewProxy" -> {
                        val host = call.argument<String>("host") ?: "localhost"
                        val port = call.argument<Int>("port") ?: 0
                        setProxy(host, port, result)
                    }
                    "clearWebViewProxy" -> {
                        clearProxy(result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun setProxy(host: String, port: Int, result: MethodChannel.Result) {
        if (!WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE)) {
            result.success(false)
            return
        }
        try {
            val proxyConfig = ProxyConfig.Builder()
                .addProxyRule("$host:$port")
                .removeImplicitRules()  // Allow proxy to handle all connections including localhost
                .build()
            val executor = Executor { it.run() }
            ProxyController.getInstance().setProxyOverride(proxyConfig, executor) {
                result.success(true)
            }
        } catch (e: Exception) {
            result.success(false)
        }
    }

    private fun clearProxy(result: MethodChannel.Result) {
        if (!WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE)) {
            result.success(false)
            return
        }
        try {
            val executor = Executor { it.run() }
            ProxyController.getInstance().clearProxyOverride(executor) {
                result.success(true)
            }
        } catch (e: Exception) {
            result.success(false)
        }
    }

    private fun findWebView(view: View): WebView? {
        if (view is WebView) return view
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                val found = findWebView(view.getChildAt(i))
                if (found != null) return found
            }
        }
        return null
    }
}
