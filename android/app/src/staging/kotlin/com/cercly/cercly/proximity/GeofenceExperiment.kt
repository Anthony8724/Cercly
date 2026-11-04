package com.cercly.cercly.proximity

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.AlarmManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.cercly.cercly.BuildConfig
import com.cercly.cercly.MainActivity
import com.cercly.cercly.R
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant
import java.time.OffsetDateTime
import java.time.format.DateTimeParseException
import java.util.concurrent.Executors

internal object GeofenceExperiment {
    const val CHANNEL = "promociones_cercanas"
    const val ACTION = "com.cercly.cercly.STAGING_GEOFENCE"
    const val QA_ACTION = "com.cercly.cercly.STAGING_GEOFENCE_QA"
    const val SCREEN_LOCK_QA_ACTION = "com.cercly.cercly.STAGING_SCREEN_LOCK_QA"
    const val EXTRA_ESTABLISHMENT_ID = "cercly_establishment_id"
    const val ESTABLISHMENT_ID = "f14a1f14-14b0-4b14-8a14-140000000001"
    const val PROMOTION_ID = "f14a1f14-14b0-4b14-8a14-140000000002"
    private const val PREFS = "cercly_geofence_experiment"
    private const val GEOFENCE_ID = "cercly-staging-upec-test"
    private const val LOG_TAG = "CerclyGeofence"
    private const val MAX_RADIUS_METERS = 5000f
    private val executor = Executors.newSingleThreadExecutor()

    fun active(context: Context): Boolean = BuildConfig.CERCLY_STAGING &&
        BuildConfig.STAGING_SUPABASE_URL == "https://dlajxviqhkdcqnmczhvr.supabase.co" &&
        BuildConfig.STAGING_SUPABASE_PUBLISHABLE_KEY.startsWith("sb_publishable_")

    fun status(context: Context): Map<String, Any?> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        migrateLegacyTransitionTimestamp(prefs)
        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val foregroundAlerts = flutterPrefs.getBoolean("flutter.cercly.alertas_proximidad.activas.v1", false)
        val fine = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val background = Build.VERSION.SDK_INT < 29 || ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED
        val notificationsPermission = Build.VERSION.SDK_INT < 33 || ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        val notificationChannel = if (Build.VERSION.SDK_INT >= 26) context.getSystemService(NotificationManager::class.java).getNotificationChannel(CHANNEL) else null
        val channelEnabled = notificationChannel == null || notificationChannel.importance != NotificationManager.IMPORTANCE_NONE
        val notifications = notificationsPermission && channelEnabled
        val gms = GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(context) == ConnectionResult.SUCCESS
        val locationEnabled = (context.getSystemService(Context.LOCATION_SERVICE) as LocationManager).isLocationEnabled
        val now = Instant.now().toEpochMilli()
        val dailyTimes = prefs.getString("cooldown_daily", "").orEmpty().split(',')
            .mapNotNull { it.toLongOrNull() }.filter { now - it < 24L * 60 * 60 * 1000 }
        val lastPromotion = prefs.getLong("cooldown_$PROMOTION_ID", 0L)
        val lastGlobal = prefs.getLong("cooldown_global", 0L)
        return mapOf(
            "available" to active(context), "foregroundLocation" to (fine || coarse), "preciseLocation" to fine,
            "backgroundLocation" to background, "notifications" to notifications, "googlePlayServices" to gms,
            "notificationChannel" to channelEnabled,
            "locationEnabled" to locationEnabled, "consent" to prefs.getBoolean("consent", false),
            "foregroundAlerts" to foregroundAlerts,
            "registered" to (prefs.getBoolean("registered", false) && prefs.getBoolean("consent", false) && background && fine && prefs.getLong("expires", 0L) > now),
            "expiresAt" to prefs.getLong("expires", 0L),
            "registrationState" to (prefs.getString("registration_state", "not_registered") ?: "not_registered"),
            "promotionCooldownRemainingMs" to (2L * 60 * 60 * 1000 - (now - lastPromotion)).coerceAtLeast(0L),
            "globalCooldownRemainingMs" to (15L * 60 * 1000 - (now - lastGlobal)).coerceAtLeast(0L),
            "dailyNotificationCount" to dailyTimes.size,
            "dailyRemaining" to (3 - dailyTimes.size).coerceAtLeast(0),
            "lastAndroidEventAt" to prefs.getLong("last_android_event_ms", 0L),
            "lastAndroidEventResult" to (prefs.getString("last_android_event_result", "") ?: ""),
            "lastAndroidEnterAt" to prefs.getLong("last_android_enter_ms", 0L),
            "lastAndroidExitAt" to prefs.getLong("last_android_exit_ms", 0L),
            "lastNativeError" to (prefs.getString("last_native_error", "") ?: ""),
            "lastRealEntryNotificationAt" to prefs.getLong("last_real_entry_notification_ms", 0L),
            "lastRealEntryNotificationResult" to (prefs.getString("last_real_entry_notification_result", "") ?: ""),
            "screenLockQaScheduledAt" to prefs.getLong("screenlock_qa_scheduled_ms", 0L),
            "screenLockQaDueAt" to prefs.getLong("screenlock_qa_due_ms", 0L),
            "screenLockQaDeliveredAt" to prefs.getLong("screenlock_qa_delivered_ms", 0L),
            "screenLockQaResult" to (prefs.getString("screenlock_qa_result", "") ?: ""),
            "lastSimulationAt" to prefs.getLong("last_simulation_ms", 0L),
            "lastSimulationResult" to (prefs.getString("last_simulation_result", "") ?: ""),
            "lastQaReceiverSignalAt" to prefs.getLong("last_qa_receiver_signal_ms", 0L),
        )
    }

    /**
     * v0.1.4 persisted the last native transition only in the generic event
     * fields. Keep that real event visible after upgrading to v0.1.5, which
     * added per-transition timestamps, without overwriting newer values.
     */
    private fun migrateLegacyTransitionTimestamp(
        prefs: android.content.SharedPreferences,
    ) {
        val eventAt = prefs.getLong("last_android_event_ms", 0L)
        if (eventAt <= 0L) return

        val eventResult = prefs.getString("last_android_event_result", "")
        val editor = prefs.edit()
        var changed = false
        if (eventResult == "android_enter_received" &&
            prefs.getLong("last_android_enter_ms", 0L) <= 0L
        ) {
            editor.putLong("last_android_enter_ms", eventAt)
            changed = true
        }
        if (eventResult == "android_exit_received" &&
            prefs.getLong("last_android_exit_ms", 0L) <= 0L
        ) {
            editor.putLong("last_android_exit_ms", eventAt)
            changed = true
        }
        if (changed) editor.apply()
    }

    fun setConsent(context: Context, enabled: Boolean) {
        if (!active(context)) return
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean("consent", enabled).apply()
        if (!enabled) remove(context)
    }

    fun reserveForegroundSlot(context: Context, promotionId: String): String {
        if (!active(context)) return "unmanaged"
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (status(context)["foregroundAlerts"] != true) return "blocked"
        if (!promotionId.matches(Regex("[0-9a-fA-F-]{36}"))) return "blocked"
        return if (reserveNotification(context, prefs, Instant.now().toEpochMilli(), promotionId)) "reserved" else "cooldown"
    }

    fun register(context: Context, lat: Double, lon: Double, radius: Float, expirationMillis: Long, establishmentName: String, promotionTitle: String): String {
        if (!active(context)) return "unavailable"
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean("consent", false)) return "consent_required"
        val s = status(context)
        if (s["foregroundLocation"] != true) return "foreground_permission_required"
        if (s["preciseLocation"] != true) return "precise_location_required"
        if (s["backgroundLocation"] != true) return "background_permission_required"
        if (s["notifications"] != true) return "notification_permission_required"
        if (s["googlePlayServices"] != true) return "google_play_services_unavailable"
        if (s["locationEnabled"] != true) return "location_disabled"
        if (!lat.isFinite() || !lon.isFinite() || lat !in -90.0..90.0 || lon !in -180.0..180.0 || radius !in 100f..MAX_RADIUS_METERS) return "invalid_geofence"
        if (kotlin.math.abs(lat - 0.80525) > 0.0001 || kotlin.math.abs(lon + 77.73434) > 0.0001) return "staging_location_not_allowed"
        val expiry = minOf(expirationMillis, Instant.now().toEpochMilli() + 7L * 24 * 60 * 60 * 1000)
        if (expiry <= Instant.now().toEpochMilli()) return "promotion_expired"

        val saved = prefs.edit().putFloat("lat", lat.toFloat()).putFloat("lon", lon.toFloat()).putFloat("radius", radius)
            .putLong("expires", expiry).putString("establishment_name", establishmentName.take(100))
            .putString("promotion_title", promotionTitle.take(100)).putBoolean("registered", false)
            .putString("registration_state", "registration_submitted").commit()
        if (!saved) return "storage_error"
        val geofence = Geofence.Builder().setRequestId(GEOFENCE_ID).setCircularRegion(lat, lon, radius)
            .setExpirationDuration(expiry - Instant.now().toEpochMilli())
            .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT).build()
        val request = GeofencingRequest.Builder().setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER).addGeofence(geofence).build()
        return try {
            LocationServices.getGeofencingClient(context).removeGeofences(pendingIntent(context)).addOnCompleteListener {
                if (it.isSuccessful) LocationServices.getGeofencingClient(context).addGeofences(request, pendingIntent(context))
                    .addOnSuccessListener {
                        prefs.edit().putBoolean("registered", true).putString("registration_state", "confirmed_by_play_services").apply()
                        logStaging(context, "source=gms action=registration geofence_id=$GEOFENCE_ID result=accepted")
                    }
                    .addOnFailureListener { error ->
                        prefs.edit().putBoolean("registered", false).putString("registration_state", "registration_failed").putString("last_native_error", error.javaClass.simpleName.take(80)).apply()
                        logStaging(context, "source=gms action=registration geofence_id=$GEOFENCE_ID result=failed error=${error.javaClass.simpleName.take(80)}")
                    }
            }
            "registration_submitted"
        } catch (_: SecurityException) { "permission_revoked" } catch (_: Exception) { "registration_error" }
    }

    fun remove(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean("registered", false).putString("registration_state", "removal_submitted").apply()
        try { LocationServices.getGeofencingClient(context).removeGeofences(pendingIntent(context)) } catch (_: Exception) { }
    }

    private fun pendingIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context, 4817, Intent(context, GeofenceBroadcastReceiver::class.java).setAction(ACTION),
        PendingIntent.FLAG_UPDATE_CURRENT or if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0,
    )

    fun onEvent(context: Context, intent: Intent?, pending: BroadcastReceiver.PendingResult) {
        if (!active(context) || intent?.action != ACTION) { pending.finish(); return }
        val event = GeofencingEvent.fromIntent(intent) ?: run {
            logStaging(context, "source=gms result=ignored reason=event_parse_failed geofence_id=$GEOFENCE_ID")
            pending.finish()
            return
        }
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val transition = transitionName(event.geofenceTransition)
        val matchesTestGeofence = event.triggeringGeofences?.any { it.requestId == GEOFENCE_ID } == true
        if (event.hasError()) {
            val error = "geofence_error_${event.errorCode}"
            prefs.edit().putLong("last_android_event_ms", Instant.now().toEpochMilli()).putString("last_android_event_result", error).putString("last_native_error", error).apply()
            logStaging(context, "source=gms transition=$transition geofence_id=$GEOFENCE_ID match=$matchesTestGeofence result=error code=${event.errorCode}")
            pending.finish(); return
        }
        if (!matchesTestGeofence) {
            logStaging(context, "source=gms transition=$transition geofence_id=$GEOFENCE_ID match=false result=ignored reason=no_test_geofence")
            pending.finish(); return
        }
        val eventTime = Instant.now().toEpochMilli()
        logStaging(context, "source=gms transition=$transition geofence_id=$GEOFENCE_ID match=true result=received")
        if (event.geofenceTransition == Geofence.GEOFENCE_TRANSITION_EXIT) {
            prefs.edit().putLong("last_android_event_ms", eventTime).putLong("last_android_exit_ms", eventTime).putString("last_android_event_result", "android_exit_received").apply()
            logStaging(context, "source=gms transition=EXIT geofence_id=$GEOFENCE_ID validation=accepted notification=not_applicable")
            pending.finish(); return
        }
        if (event.geofenceTransition != Geofence.GEOFENCE_TRANSITION_ENTER) {
            logStaging(context, "source=gms transition=$transition geofence_id=$GEOFENCE_ID result=ignored reason=unsupported_transition")
            pending.finish(); return
        }
        prefs.edit().putLong("last_android_event_ms", eventTime).putLong("last_android_enter_ms", eventTime).putString("last_android_event_result", "android_enter_received").apply()
        logStaging(context, "source=gms transition=ENTER geofence_id=$GEOFENCE_ID validation=accepted")
        val eventStatus = status(context)
        val missingRequirements = buildList {
            if (!prefs.getBoolean("consent", false)) add("background_consent")
            if (eventStatus["foregroundAlerts"] != true) add("promotion_alerts_consent")
            if (eventStatus["backgroundLocation"] != true) add("background_location_permission")
            if (eventStatus["notifications"] != true) add("notification_permission_or_channel")
        }
        if (missingRequirements.isNotEmpty()) {
            prefs.edit().putString("last_real_entry_notification_result", "omitted_consent_or_permission").apply()
            logStaging(context, "source=gms transition=ENTER geofence_id=$GEOFENCE_ID notification=omitted reason=${missingRequirements.joinToString(",")}")
            remove(context); pending.finish(); return
        }
        executor.execute {
            try {
                val record = fetchPromotion() ?: run {
                    prefs.edit().putString("last_real_entry_notification_result", "omitted_validation_unavailable").apply()
                    logStaging(context, "source=gms transition=ENTER geofence_id=$GEOFENCE_ID notification=omitted reason=staging_validation_unavailable")
                    return@execute
                }
                val now = Instant.now().toEpochMilli()
                val ineligibleReason = ineligibilityReason(record, now, prefs)
                if (ineligibleReason != null) {
                    prefs.edit().putString("last_real_entry_notification_result", "omitted_not_eligible").apply()
                    logStaging(context, "source=gms transition=ENTER geofence_id=$GEOFENCE_ID notification=omitted reason=$ineligibleReason")
                    return@execute
                }
                if (!reserveNotification(context, prefs, now, PROMOTION_ID)) {
                    prefs.edit().putString("last_real_entry_notification_result", "omitted_cooldown").apply()
                    logStaging(context, "source=gms transition=ENTER geofence_id=$GEOFENCE_ID notification=omitted reason=cooldown")
                    return@execute
                }
                if (showNotification(context, record.establishmentName.ifBlank { "Establecimiento cercano" }, record.title)) {
                    prefs.edit().putLong("last_real_entry_notification_ms", now).putString("last_real_entry_notification_result", "delivered_to_notification_manager").apply()
                    logStaging(context, "source=gms transition=ENTER geofence_id=$GEOFENCE_ID notification=posted result=delivered_to_notification_manager")
                } else {
                    prefs.edit().putString("last_real_entry_notification_result", "notification_permission_or_channel_blocked").apply()
                    logStaging(context, "source=gms transition=ENTER geofence_id=$GEOFENCE_ID notification=omitted reason=permission_or_channel_blocked")
                }
            } finally { pending.finish() }
        }
    }

    private fun transitionName(transition: Int): String = when (transition) {
        Geofence.GEOFENCE_TRANSITION_ENTER -> "ENTER"
        Geofence.GEOFENCE_TRANSITION_EXIT -> "EXIT"
        Geofence.GEOFENCE_TRANSITION_DWELL -> "DWELL"
        else -> "UNKNOWN"
    }

    private fun ineligibilityReason(
        promotion: Promotion,
        now: Long,
        prefs: android.content.SharedPreferences,
    ): String? = when {
        !prefs.getBoolean("consent", false) -> "background_consent_revoked"
        prefs.getLong("expires", 0L) <= now -> "geofence_expired"
        promotion.promotionId != PROMOTION_ID -> "promotion_id_mismatch"
        promotion.establishmentId != ESTABLISHMENT_ID -> "establishment_id_mismatch"
        !promotion.active -> "promotion_inactive"
        !promotion.approved -> "establishment_not_approved"
        !promotion.publicable -> "establishment_not_public"
        promotion.start > now -> "promotion_not_started"
        promotion.end < now -> "promotion_expired"
        else -> null
    }

    private fun logStaging(context: Context, message: String) {
        if (!active(context)) return
        Log.i(LOG_TAG, "at=${Instant.now()} $message")
    }

    fun resetQaCooldown(context: Context): Boolean {
        if (!active(context)) return false
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val editor = prefs.edit()
        prefs.all.keys.filter { it.startsWith("cooldown_") }.forEach(editor::remove)
        return editor.commit()
    }

    fun recordSimulationResult(context: Context, result: String) {
        if (!active(context)) return
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putLong("last_simulation_ms", Instant.now().toEpochMilli())
            .putString("last_simulation_result", result.take(80)).apply()
    }

    fun sendQaReceiverSignal(context: Context): Boolean {
        if (!active(context)) return false
        context.sendBroadcast(Intent(context, GeofenceQaReceiver::class.java).setAction(QA_ACTION))
        return true
    }

    fun scheduleScreenLockQa(context: Context): String {
        if (!active(context)) return "unavailable"
        if (status(context)["notifications"] != true) return "notification_permission_denied"
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val pending = screenLockPendingIntent(context, PendingIntent.FLAG_NO_CREATE)
        if (pending != null || prefs.getLong("screenlock_qa_due_ms", 0L) > System.currentTimeMillis()) return "already_scheduled"
        val due = System.currentTimeMillis() + 30_000L
        val alarm = context.getSystemService(AlarmManager::class.java)
        val intent = screenLockPendingIntent(context, PendingIntent.FLAG_UPDATE_CURRENT)
            ?: return "scheduling_error"
        return try {
            alarm.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, SystemClock.elapsedRealtime() + 30_000L, intent)
            val saved = prefs.edit().putLong("screenlock_qa_scheduled_ms", System.currentTimeMillis())
                .putLong("screenlock_qa_due_ms", due).putString("screenlock_qa_result", "scheduled_inexact").commit()
            if (saved) "scheduled_inexact" else { alarm.cancel(intent); intent.cancel(); "storage_error" }
        } catch (_: Exception) { "scheduling_error" }
    }

    fun cancelScreenLockQa(context: Context): Boolean {
        if (!active(context)) return false
        val intent = screenLockPendingIntent(context, PendingIntent.FLAG_NO_CREATE)
        if (intent != null) {
            context.getSystemService(AlarmManager::class.java).cancel(intent)
            intent.cancel()
        }
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putLong("screenlock_qa_due_ms", 0L).putString("screenlock_qa_result", "canceled").commit()
    }

    private fun screenLockPendingIntent(context: Context, flag: Int): PendingIntent? = PendingIntent.getBroadcast(
        context, 4820, Intent(context, ScreenLockQaReceiver::class.java).setAction(SCREEN_LOCK_QA_ACTION),
        flag or PendingIntent.FLAG_IMMUTABLE,
    )

    fun deliverScreenLockQa(context: Context) {
        if (!active(context)) return
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (prefs.getLong("screenlock_qa_due_ms", 0L) == 0L) return
        val now = System.currentTimeMillis()
        screenLockPendingIntent(context, PendingIntent.FLAG_NO_CREATE)?.cancel()
        val published = status(context)["notifications"] == true &&
            showNotification(context, "Prueba con pantalla bloqueada", "Aviso QA programado; no es un evento geográfico", screenLockTest = true)
        prefs.edit().putLong("screenlock_qa_delivered_ms", now).putLong("screenlock_qa_due_ms", 0L)
            .putString("screenlock_qa_result", if (published) "delivered_to_notification_manager" else "notification_permission_or_channel_blocked_at_delivery").apply()
    }

    fun recordQaReceiverSignal(context: Context) {
        if (!active(context)) return
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putLong("last_qa_receiver_signal_ms", Instant.now().toEpochMilli()).apply()
        logStaging(context, "source=qa action=receiver_signal result=recorded_not_gms_geofence")
    }

    private data class Promotion(val title: String, val promotionId: String, val establishmentName: String, val establishmentId: String, val active: Boolean, val start: Long, val end: Long, val approved: Boolean, val publicable: Boolean)

    private fun fetchPromotion(): Promotion? {
        val endpoint = URL(BuildConfig.STAGING_SUPABASE_URL + "/rest/v1/promociones?id=eq.$PROMOTION_ID&select=id,titulo,fecha_inicio,fecha_fin,activa,establecimientos!inner(id,nombre,estado,publicable)")
        val connection = endpoint.openConnection() as HttpURLConnection
        return try {
            connection.requestMethod = "GET"; connection.connectTimeout = 2500; connection.readTimeout = 2500
            connection.setRequestProperty("apikey", BuildConfig.STAGING_SUPABASE_PUBLISHABLE_KEY)
            connection.setRequestProperty("Authorization", "Bearer ${BuildConfig.STAGING_SUPABASE_PUBLISHABLE_KEY}")
            if (connection.responseCode != 200) return null
            val body = connection.inputStream.bufferedReader().use { it.readText() }
            val row = org.json.JSONArray(body).optJSONObject(0) ?: return null
            val establishment = row.optJSONObject("establecimientos") ?: return null
            Promotion(row.optString("titulo"), row.optString("id"), establishment.optString("nombre"), establishment.optString("id"), row.optBoolean("activa"), parseDate(row.optString("fecha_inicio")), parseDate(row.optString("fecha_fin")), establishment.optString("estado") == "aprobado", establishment.optBoolean("publicable"))
        } catch (_: Exception) { null } finally { connection.disconnect() }
    }

    private fun parseDate(value: String): Long = try { OffsetDateTime.parse(value).toInstant().toEpochMilli() } catch (_: DateTimeParseException) { 0L }

    @Synchronized private fun reserveNotification(context: Context, prefs: android.content.SharedPreferences, now: Long, promotionId: String): Boolean {
        val perPromotion = prefs.getLong("cooldown_$promotionId", 0L)
        val global = prefs.getLong("cooldown_global", 0L)
        val times = prefs.getString("cooldown_daily", "").orEmpty().split(',')
            .mapNotNull { it.toLongOrNull() }.filter { now - it < 24L * 60 * 60 * 1000 }
        if (now - perPromotion < 2L * 60 * 60 * 1000 || now - global < 15L * 60 * 1000 || times.size >= 3) return false
        return prefs.edit().putLong("cooldown_$promotionId", now).putLong("cooldown_global", now)
            .putString("cooldown_daily", (times + now).joinToString(",")).commit()
    }

    private fun showNotification(context: Context, business: String, promotion: String, screenLockTest: Boolean = false): Boolean {
        if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false
        val manager = context.getSystemService(NotificationManager::class.java)
        if (!manager.areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT >= 26 && manager.getNotificationChannel(CHANNEL)?.importance == NotificationManager.IMPORTANCE_NONE) return false
        if (Build.VERSION.SDK_INT >= 26) context.getSystemService(NotificationManager::class.java).createNotificationChannel(NotificationChannel(CHANNEL, "Promociones cercanas", NotificationManager.IMPORTANCE_HIGH).apply { description = "Avisos cuando hay una promoción cerca de ti"; enableVibration(true); setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI, android.media.AudioAttributes.Builder().setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION).build()) })
        val launch = Intent(context, MainActivity::class.java).putExtra(EXTRA_ESTABLISHMENT_ID, ESTABLISHMENT_ID).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val tap = PendingIntent.getActivity(context, if (screenLockTest) 4821 else 4818, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = NotificationCompat.Builder(context, CHANNEL).setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(if (screenLockTest) "[PRUEBA PANTALLA BLOQUEADA] Cercly" else "Promoción cerca de ti").setContentText(if (screenLockTest) "$promotion · ID $ESTABLISHMENT_ID" else "$promotion en $business")
            .setStyle(NotificationCompat.BigTextStyle().bigText(if (screenLockTest) "[PRUEBA PANTALLA BLOQUEADA] $promotion · ID $ESTABLISHMENT_ID" else "$promotion en $business"))
            .setAutoCancel(true).setVisibility(NotificationCompat.VISIBILITY_PRIVATE).setContentIntent(tap).build()
        if (screenLockTest) manager.notify(4822, notification) else manager.notify(4819, notification)
        return true
    }

    fun restore(context: Context) {
        if (!active(context)) return
        val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!p.getBoolean("consent", false)) return
        if (p.getLong("expires", 0L) <= Instant.now().toEpochMilli()) { remove(context); return }
        register(context, p.getFloat("lat", 0f).toDouble(), p.getFloat("lon", 0f).toDouble(), p.getFloat("radius", 0f), p.getLong("expires", 0L), p.getString("establishment_name", "") ?: "", p.getString("promotion_title", "") ?: "")
    }
}

class GeofenceBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == GeofenceExperiment.ACTION) GeofenceExperiment.onEvent(context, intent, goAsync())
    }
}

class GeofenceBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) GeofenceExperiment.restore(context)
    }
}

class GeofenceQaReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == GeofenceExperiment.QA_ACTION) GeofenceExperiment.recordQaReceiverSignal(context)
    }
}

class ScreenLockQaReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == GeofenceExperiment.SCREEN_LOCK_QA_ACTION) GeofenceExperiment.deliverScreenLockQa(context)
    }
}
