package com.cercly.cercly

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.cercly.cercly.proximity.LegacyGeofenceCleanup
import com.cercly.cercly.proximity.StagingPromotionalGeofencing
import android.Manifest
import android.os.Build
import androidx.core.app.ActivityCompat

class MainActivity : FlutterActivity() {
    private var pendingEstablishmentId: String? = null
    private var pendingPromotionId: String? = null
    private var promotionalChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // Retire registrations made by the legacy QA receiver in earlier private builds.
        LegacyGeofenceCleanup.remove(this)
        pendingEstablishmentId = intent?.getStringExtra(StagingPromotionalGeofencing.EXTRA_ESTABLISHMENT_ID)
        pendingPromotionId = intent?.getStringExtra(StagingPromotionalGeofencing.EXTRA_PROMOTION_ID)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        promotionalChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cercly/staging_promotional_geofencing").also { methodChannel ->
            methodChannel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(StagingPromotionalGeofencing.status(this))
                    "setConsent" -> result.success(StagingPromotionalGeofencing.consent(this, call.argument<Boolean>("enabled") == true))
                    "accountChanged" -> { StagingPromotionalGeofencing.accountChanged(this, call.argument<String>("userId")); result.success(true) }
                    "importHistory" -> {
                        val last = call.argument<Map<String, Number>>("last") ?: emptyMap()
                        val business = call.argument<Map<String, Number>>("business") ?: emptyMap()
                        val recent = call.argument<List<Number>>("recent") ?: emptyList()
                        result.success(StagingPromotionalGeofencing.importHistory(
                            this, call.argument<String>("userId") ?: "", last, business, recent,
                            call.argument<Number>("dailyLimit")?.toInt() ?: 6,
                            call.argument<Number>("quietStart")?.toInt(), call.argument<Number>("quietEnd")?.toInt()))
                    }
                    "register" -> StagingPromotionalGeofencing.register(this, call.argument<String>("zones") ?: "[]") { result.success(it) }
                    "remove" -> { StagingPromotionalGeofencing.remove(this); result.success(null) }
                    "reserveForegroundSlot" -> result.success(StagingPromotionalGeofencing.reserveForeground(
                        this, call.argument<String>("promotionId") ?: "", call.argument<String>("businessId") ?: "",
                        call.argument<String>("userId") ?: ""))
                    "openAppSettings" -> {
                        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                        result.success(true)
                    }
                    "requestForegroundPermissions" -> {
                        val permissions = mutableListOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
                        if (Build.VERSION.SDK_INT >= 33) permissions.add(Manifest.permission.POST_NOTIFICATIONS)
                        ActivityCompat.requestPermissions(this, permissions.toTypedArray(), 9381)
                        result.success(true)
                    }
                    "requestBackgroundPermission" -> {
                        if (Build.VERSION.SDK_INT >= 30) {
                            startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                        } else if (Build.VERSION.SDK_INT >= 29) {
                            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION), 9382)
                        }
                        result.success(true)
                    }
                    "consumePendingNotification" -> {
                        val establishment = pendingEstablishmentId
                        val promotion = pendingPromotionId
                        pendingEstablishmentId = null; pendingPromotionId = null
                        result.success(if (establishment == null || promotion == null) null else mapOf("establishmentId" to establishment, "promotionId" to promotion))
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingEstablishmentId = intent.getStringExtra(StagingPromotionalGeofencing.EXTRA_ESTABLISHMENT_ID)
        pendingPromotionId = intent.getStringExtra(StagingPromotionalGeofencing.EXTRA_PROMOTION_ID)
        if (pendingEstablishmentId != null && pendingPromotionId != null) {
            promotionalChannel?.invokeMethod("notificationOpened", mapOf("establishmentId" to pendingEstablishmentId, "promotionId" to pendingPromotionId))
        }
    }
}
