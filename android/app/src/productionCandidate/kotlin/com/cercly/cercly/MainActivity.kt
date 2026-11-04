package com.cercly.cercly

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.cercly.cercly.proximity.ProductionGeofencing as Engine

class MainActivity : FlutterActivity() {
    private var pendingId: String? = null
    private var channel: MethodChannel? = null
    override fun onCreate(state: android.os.Bundle?) {
        pendingId = intent?.getStringExtra(Engine.EXTRA_ID)
        super.onCreate(state)
    }
    override fun onResume() { super.onResume(); Engine.reconcile(this) }
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, "cercly/production_proximity").also { c ->
            c.setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(Engine.status(this))
                    "setConsent" -> result.success(Engine.consent(this, call.argument<Boolean>("enabled") == true))
                    "importHistory" -> result.success(Engine.importHistory(this, call.argument<Map<String, Number>>("last") ?: emptyMap(), call.argument<List<Number>>("recent") ?: emptyList()))
                    "register" -> Engine.register(this, call.argument<String>("zones") ?: "[]") { result.success(it) }
                    "remove" -> { Engine.remove(this); result.success(null) }
                    "reserveForegroundSlot" -> result.success(Engine.reserveForeground(this, call.argument<String>("promotionId") ?: ""))
                    "openAppSettings" -> {
                        try { startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))); result.success(true) }
                        catch (_: Exception) { result.success(false) }
                    }
                    "consumePendingNotification" -> { result.success(pendingId); pendingId = null }
                    else -> result.notImplemented()
                }
            }
        }
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent); setIntent(intent)
        val id = intent.getStringExtra(Engine.EXTRA_ID) ?: return
        if (channel == null) pendingId = id else channel?.invokeMethod("notificationOpened", id)
    }
}
