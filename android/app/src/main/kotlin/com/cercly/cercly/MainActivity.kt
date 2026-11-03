package com.cercly.cercly

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.cercly.cercly.proximity.GeofenceExperiment

class MainActivity : FlutterActivity() {
    private val channelName = "cercly/geofence_experiment"
    private var pendingEstablishmentId: String? = null
    private var channel: MethodChannel? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        pendingEstablishmentId = intent?.getStringExtra(GeofenceExperiment.EXTRA_ESTABLISHMENT_ID)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).also { methodChannel ->
            methodChannel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(GeofenceExperiment.status(this))
                    "setConsent" -> {
                        GeofenceExperiment.setConsent(this, call.argument<Boolean>("enabled") == true)
                        result.success(null)
                    }
                    "register" -> {
                        val status = GeofenceExperiment.status(this)
                        if (status["foregroundAlerts"] != true) {
                            result.success("foreground_alerts_disabled")
                        } else {
                            result.success(GeofenceExperiment.register(
                                this,
                                call.argument<Double>("latitude") ?: Double.NaN,
                                call.argument<Double>("longitude") ?: Double.NaN,
                                (call.argument<Number>("radiusMeters")?.toFloat() ?: 0f),
                                call.argument<Number>("expiresAt")?.toLong() ?: 0L,
                                call.argument<String>("establishmentName") ?: "",
                                call.argument<String>("promotionTitle") ?: "",
                            ))
                        }
                    }
                    "remove" -> { GeofenceExperiment.remove(this); result.success(null) }
                    "openAppSettings" -> {
                        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                        result.success(true)
                    }
                    "reserveForegroundSlot" -> result.success(GeofenceExperiment.reserveForegroundSlot(this, call.argument<String>("promotionId") ?: ""))
                    "resetQaCooldown" -> result.success(GeofenceExperiment.resetQaCooldown(this))
                    "recordSimulationResult" -> {
                        GeofenceExperiment.recordSimulationResult(this, call.argument<String>("result") ?: "unknown")
                        result.success(null)
                    }
                    "sendQaReceiverSignal" -> result.success(GeofenceExperiment.sendQaReceiverSignal(this))
                    "scheduleScreenLockQa" -> result.success(GeofenceExperiment.scheduleScreenLockQa(this))
                    "cancelScreenLockQa" -> result.success(GeofenceExperiment.cancelScreenLockQa(this))
                    "consumePendingNotification" -> {
                        result.success(pendingEstablishmentId)
                        pendingEstablishmentId = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingEstablishmentId = intent.getStringExtra(GeofenceExperiment.EXTRA_ESTABLISHMENT_ID)
        pendingEstablishmentId?.let { channel?.invokeMethod("notificationOpened", it) }
    }
}
