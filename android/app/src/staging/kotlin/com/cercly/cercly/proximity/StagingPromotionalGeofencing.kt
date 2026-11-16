package com.cercly.cercly.proximity

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.cercly.cercly.BuildConfig
import com.cercly.cercly.MainActivity
import com.cercly.cercly.R
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.location.*
import com.google.android.gms.tasks.Tasks
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import com.google.android.gms.tasks.CancellationTokenSource

/** Private Staging-only promotions geofencing; no production endpoint or fixed coordinates. */
object StagingPromotionalGeofencing {
    const val EXTRA_ESTABLISHMENT_ID = "cercly_establishment_id"
    const val EXTRA_PROMOTION_ID = "cercly_promotion_id"
    const val ACTION = "com.cercly.cercly.STAGING_PROMOTION_GEOFENCE"
    private const val CHANNEL = "promociones_cercanas"
    private const val PREFS = "cercly_staging_promotion_geofencing_v1"
    private val executor = Executors.newSingleThreadExecutor()
    // Serializes registration/removal callbacks, including consent revocation while GMS is busy.
    private var registrationBusy = false
    private var generation = 0L
    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private fun foreground(c: Context) = c.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    private fun granted(c: Context, p: String) = ContextCompat.checkSelfPermission(c, p) == PackageManager.PERMISSION_GRANTED
    private fun now() = System.currentTimeMillis()
    private fun result(c: Context, value: String) {
        prefs(c).edit().putString("result", value).putLong("checkedAt", now()).apply()
    }
    private fun allowed(c: Context): Boolean {
        val s = status(c)
        return prefs(c).getString("userId", null) != null &&
            listOf("consent", "foregroundAlerts", "precise", "background", "notifications", "location", "gms")
            .all { s[it] == true }
    }
    fun status(c: Context): Map<String, Any> {
        val p = prefs(c)
        val manager = c.getSystemService(NotificationManager::class.java)
        val channel = if (Build.VERSION.SDK_INT >= 26) manager.getNotificationChannel(CHANNEL) else null
        return mapOf(
            "consent" to p.getBoolean("consent", false),
            "foregroundAlerts" to foreground(c).getBoolean("flutter.cercly.alertas_proximidad.activas.v1", false),
            "precise" to granted(c, Manifest.permission.ACCESS_FINE_LOCATION),
            "background" to (Build.VERSION.SDK_INT < 29 || granted(c, Manifest.permission.ACCESS_BACKGROUND_LOCATION)),
            "notifications" to (NotificationManagerCompat.from(c).areNotificationsEnabled() &&
                (Build.VERSION.SDK_INT < 33 || granted(c, Manifest.permission.POST_NOTIFICATIONS)) &&
                (channel == null || channel.importance != NotificationManager.IMPORTANCE_NONE)),
            "location" to androidx.core.location.LocationManagerCompat.isLocationEnabled(
                c.getSystemService(Context.LOCATION_SERVICE) as LocationManager),
            "gms" to (GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(c) == ConnectionResult.SUCCESS),
            // Acceptance is historical; the GMS API cannot enumerate active registrations.
            "acceptedAt" to p.getLong("acceptedAt", 0),
            "zoneCount" to zones(c).count { it.getLong("expires") > now() },
            "registration" to p.getString("registration", "not_registered").orEmpty(),
            "result" to p.getString("result", "not_checked").orEmpty(),
            "checkedAt" to p.getLong("checkedAt", 0),
            "enterAt" to p.getLong("enterAt", 0), "exitAt" to p.getLong("exitAt", 0),
            "notificationAt" to p.getLong("notificationAt", 0),
            "eventDeliveryAt" to p.getLong("eventDeliveryAt", 0),
            "eventSampleAt" to p.getLong("eventSampleAt", 0),
            "eventSampleAgeMs" to p.getLong("eventSampleAgeMs", -1),
            "eventSampleWallAgeMs" to p.getLong("eventSampleWallAgeMs", -1),
        )
    }
    @Synchronized fun consent(c: Context, enabled: Boolean): Boolean {
        val saved = prefs(c).edit().putBoolean("consent", enabled).commit()
        if (!enabled || !saved) remove(c)
        return saved
    }
    @Synchronized fun accountChanged(c: Context, userId: String?) {
        val p = prefs(c)
        if (p.getString("userId", null) == userId) return
        remove(c)
        p.edit().clear().putString("userId", userId).putBoolean("consent", false).commit()
    }
    @Synchronized fun importHistory(c: Context, userId: String, last: Map<String, Number>, business: Map<String, Number>, recent: List<Number>, dailyLimit: Int, quietStart: Int?, quietEnd: Int?): Boolean {
        if (!BuildConfig.CERCLY_STAGING || BuildConfig.STAGING_SUPABASE_URL != "https://dlajxviqhkdcqnmczhvr.supabase.co" ||
            !userId.matches(Regex("[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}"))) return false
        val p = prefs(c)
        val previousUser = p.getString("userId", null)
        if (previousUser != userId) {
            // Remove the prior account's fences before clearing its local ledger.
            remove(c)
            p.edit().clear().putString("userId", userId).commit()
        }
        val e = p.edit()
        if (!p.getBoolean("historyImported", false)) {
            last.filterKeys(StagingProximityPolicy::uuid).forEach { (id, time) -> e.putLong("last_promotion_$id", time.toLong()) }
            business.filterKeys(StagingProximityPolicy::uuid).forEach { (id, time) -> e.putLong("last_business_$id", time.toLong()) }
            e.putLong("global", (recent.map { it.toLong() } + last.values.map { it.toLong() }).maxOrNull() ?: 0)
            e.putString("daily", recent.map { it.toLong() }.filter { now() - it in 0..StagingProximityPolicy.DAY }.joinToString(","))
        }
        if (dailyLimit !in listOf(3, 6, 10) || (quietStart == null) != (quietEnd == null) ||
            (quietStart != null && quietStart !in 0..1439) || (quietEnd != null && quietEnd !in 0..1439) ||
            (quietStart != null && quietStart == quietEnd)) return false
        e.putInt("dailyLimit", dailyLimit)
            .putInt("quietStart", quietStart ?: -1)
            .putInt("quietEnd", quietEnd ?: -1)
            .putBoolean("historyImported", true)
        return e.commit()
    }
    @Synchronized fun reserveForeground(c: Context, id: String, businessId: String, userId: String): String {
        if (!StagingProximityPolicy.uuid(id) || !StagingProximityPolicy.uuid(businessId) ||
            prefs(c).getString("userId", null) != userId || !prefs(c).getBoolean("historyImported", false) ||
            status(c)["foregroundAlerts"] != true || status(c)["notifications"] != true) return "blocked"
        return reserve(c, id, businessId) ?: "reserved"
    }
    @Synchronized fun currentUser(c: Context) = prefs(c).getString("userId", null)
    private fun quietNow(p: android.content.SharedPreferences, time: Long): Boolean {
        val start = p.getInt("quietStart", -1); val end = p.getInt("quietEnd", -1)
        val local = Instant.ofEpochMilli(time).atZone(java.time.ZoneId.systemDefault()).toLocalTime()
        return StagingProximityPolicy.inQuietHours(local.hour * 60 + local.minute,
            start.takeIf { it >= 0 }, end.takeIf { it >= 0 })
    }
    private fun reserve(c: Context, id: String, businessId: String): String? {
        if (!StagingProximityPolicy.uuid(id) || !StagingProximityPolicy.uuid(businessId)) return "invalid_candidate"
        val p = prefs(c); val time = now()
        val daily = p.getString("daily", "").orEmpty().split(',').mapNotNull { it.toLongOrNull() }
            .filter { time - it in 0..StagingProximityPolicy.DAY }
        if (quietNow(p, time)) return "quiet_hours"
        StagingProximityPolicy.cooldown(time, p.getLong("last_promotion_$id", 0), p.getLong("last_business_$businessId", 0),
            p.getLong("global", 0), daily, p.getInt("dailyLimit", 6))?.let { return it }
        val e = p.edit()
        if (!e.putLong("last_promotion_$id", time).putLong("last_business_$businessId", time).putLong("global", time)
            .putString("daily", (daily + time).joinToString(",")).commit()) return "storage_error"
        return null
    }
    private fun pending(c: Context) = PendingIntent.getBroadcast(c, 4917,
        Intent(c, StagingPromotionalGeofenceReceiver::class.java).setAction(ACTION),
        PendingIntent.FLAG_UPDATE_CURRENT or if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0)
    private fun zones(c: Context): List<JSONObject> = try {
        val a = JSONArray(prefs(c).getString("zones", "[]"))
        (0 until a.length()).map { a.getJSONObject(it) }
    } catch (_: Exception) { emptyList() }

    @Synchronized fun remove(c: Context) {
        generation++
        prefs(c).edit().putString("zones", "[]").putLong("acceptedAt", 0)
            .putString("registration", "removal_pending").commit()
        try {
            LocationServices.getGeofencingClient(c).removeGeofences(pending(c)).addOnCompleteListener { task ->
                synchronized(this) {
                    if (zones(c).isEmpty()) prefs(c).edit().putString("registration",
                        if (task.isSuccessful) "removed" else "removal_failed").apply()
                }
            }
        } catch (_: Exception) { prefs(c).edit().putString("registration", "removal_failed").apply() }
    }
    @Synchronized fun register(c: Context, json: String, done: (String) -> Unit) {
        if (registrationBusy) { done("registration_busy"); return }
        if (!allowed(c) || !prefs(c).getBoolean("historyImported", false)) { done("authorization_required"); return }
        val p = prefs(c)
        val items = try {
            val array = JSONArray(json)
            require(array.length() <= StagingProximityPolicy.MAX_ZONES)
            (0 until array.length()).map { array.getJSONObject(it) }.onEach { z ->
                require(StagingProximityPolicy.uuid(z.getString("id")) && StagingProximityPolicy.uuid(z.getString("business")))
                require(z.getString("userId") == p.getString("userId", null))
                require(StagingProximityPolicy.positionValid(z.getDouble("lat"), z.getDouble("lon")))
                require(z.getDouble("radius") in 100.0..5000.0)
                require(z.getLong("expires") > now())
                z.put("expires", minOf(z.getLong("expires"), now() + 7 * StagingProximityPolicy.DAY))
            }.also { require(it.map { z -> z.getString("id") }.distinct().size == it.size) }
        } catch (_: Exception) { done("invalid_zones"); return }
        if (items.isEmpty()) { remove(c); done("no_eligible_zones"); return }
        registrationBusy = true
        val revision = ++generation
        p.edit().putString("registration", "registration_pending").putLong("acceptedAt", 0).apply()
        val client = LocationServices.getGeofencingClient(c)
        fun finish(value: String) { registrationBusy = false; p.edit().putString("registration", value).apply(); done(value) }
        try {
            client.removeGeofences(pending(c)).addOnCompleteListener { removed ->
                synchronized(this) {
                    if (!removed.isSuccessful) { finish("removal_failed"); return@addOnCompleteListener }
                    p.edit().putString("zones", "[]").commit()
                    if (revision != generation || !allowed(c)) { finish("authorization_changed"); return@addOnCompleteListener }
                    try {
            val fences = items.map { z -> Geofence.Builder().setRequestId(z.getString("id"))
                            .setCircularRegion(z.getDouble("lat"), z.getDouble("lon"), z.getDouble("radius").toFloat())
                            .setExpirationDuration((z.getLong("expires") - now()).coerceAtLeast(1))
                            .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT).build() }
                        val request = GeofencingRequest.Builder().setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
                            .addGeofences(fences).build()
                        // Save geometry before GMS can deliver an initial transition.
                        if (!p.edit().putString("zones", JSONArray(items).toString()).commit()) { finish("storage_error"); return@addOnCompleteListener }
                        client.addGeofences(request, pending(c)).addOnCompleteListener { added ->
                            synchronized(this) {
                                if (revision != generation || !allowed(c)) { remove(c); finish("authorization_changed") }
                                else if (added.isSuccessful) {
                                    p.edit().putLong("acceptedAt", now()).apply(); finish("accepted_by_gms")
                                } else { p.edit().putString("zones", "[]").commit(); finish("registration_failed") }
                            }
                        }
                    } catch (_: Exception) { p.edit().putString("zones", "[]").commit(); finish("registration_failed") }
                }
            }
        } catch (_: Exception) { finish("removal_failed") }
    }
    fun restore(c: Context, done: () -> Unit) {
        if (!allowed(c)) { remove(c); done(); return }
        val fresh = zones(c).filter { it.getLong("expires") > now() }
        register(c, JSONArray(fresh).toString()) { done() }
    }
    fun reconcile(c: Context) {
        if (!allowed(c)) {
            if (zones(c).isNotEmpty()) remove(c)
        }
    }
    fun receive(c: Context, intent: Intent, finish: () -> Unit) {
        if (intent.action != ACTION) { finish(); return }
        val event = GeofencingEvent.fromIntent(intent)
        if (event == null || event.hasError()) { result(c, "gms_error_${event?.errorCode ?: -1}"); finish(); return }
        val transition = event.geofenceTransition
        if (transition != Geofence.GEOFENCE_TRANSITION_ENTER && transition != Geofence.GEOFENCE_TRANSITION_EXIT) { finish(); return }
        prefs(c).edit().putLong(if (transition == Geofence.GEOFENCE_TRANSITION_ENTER) "enterAt" else "exitAt", now()).commit()
        if (transition == Geofence.GEOFENCE_TRANSITION_EXIT) { result(c, "gms_exit"); finish(); return }
        if (!allowed(c)) { result(c, "authorization_required"); remove(c); finish(); return }
        val ids = event.triggeringGeofences.orEmpty().map { it.requestId }.filter(StagingProximityPolicy::uuid).take(StagingProximityPolicy.MAX_ZONES)
        val location = event.triggeringLocation
        if (location == null || ids.isEmpty()) { result(c, "missing_event_location_or_id"); finish(); return }
        // GeofencingEvent does not expose a transition-detection timestamp. Preserve
        // the delivered sample time and receiver-delivery time separately; elapsed
        // realtime is authoritative for age within this boot session.
        val deliveredAtWall = now()
        val deliveredAtElapsedNanos = SystemClock.elapsedRealtimeNanos()
        val eventAgeAtDelivery = if (location.elapsedRealtimeNanos > 0L &&
            deliveredAtElapsedNanos >= location.elapsedRealtimeNanos)
            (deliveredAtElapsedNanos - location.elapsedRealtimeNanos) / 1_000_000L else Long.MAX_VALUE
        val eventWallAgeAtDelivery = deliveredAtWall - location.time
        prefs(c).edit().putLong("eventDeliveryAt", deliveredAtWall)
            .putLong("eventSampleAt", location.time)
            .putLong("eventSampleAgeMs", eventAgeAtDelivery)
            .putLong("eventSampleWallAgeMs", eventWallAgeAtDelivery).commit()
        if (!location.hasAccuracy() || !StagingProximityPolicy.eventTimesValid(eventAgeAtDelivery, eventWallAgeAtDelivery) ||
            !StagingProximityPolicy.nativeEventEvidenceValid(
                0.0, location.accuracy.toDouble(), eventAgeAtDelivery, 5_000.0)) {
            result(c, "invalid_or_stale_transition_sample"); finish(); return
        }
        // Drop overlapping work rather than queue receivers beyond their execution window.
        if (!processing.compareAndSet(false, true)) { result(c, "event_busy"); finish(); return }
        executor.execute {
            try {
                val rows = fetch(ids)
                var outcome = "promotion_unavailable"
                val currentLocation = currentLocation(c)
                for (row in rows) {
                    val zone = zones(c).firstOrNull { it.getString("id") == row.getString("id") } ?: continue
                    outcome = validateAndNotify(c, zone, row, location, currentLocation, deliveredAtWall, deliveredAtElapsedNanos)
                    if (outcome == "native_notification_posted") break
                }
                result(c, outcome)
            } catch (_: Exception) { result(c, "query_or_delivery_error") }
            finally { processing.set(false); finish() }
        }
    }
    private val processing = java.util.concurrent.atomic.AtomicBoolean(false)
    /** One-shot confirmation after the network lookup; no continuous background GPS. */
    private fun currentLocation(c: Context): Location? {
        if (!allowed(c)) return null
        val cancellation = CancellationTokenSource()
        return try {
            Tasks.await(
                LocationServices.getFusedLocationProviderClient(c)
                    .getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, cancellation.token),
                2_500, TimeUnit.MILLISECONDS,
            )
        } catch (_: Exception) { null }
        finally { cancellation.cancel() }
    }
    private fun fetch(ids: List<String>): List<JSONObject> {
        require(BuildConfig.CERCLY_STAGING && BuildConfig.STAGING_SUPABASE_URL == "https://dlajxviqhkdcqnmczhvr.supabase.co")
        require(BuildConfig.STAGING_SUPABASE_PUBLISHABLE_KEY.startsWith("sb_publishable_"))
        val url = URL(BuildConfig.STAGING_SUPABASE_URL + "/rest/v1/promociones?id=in.(${ids.joinToString(",")})&select=id,titulo,activa,fecha_inicio,fecha_fin,radio_alerta_metros,establecimientos!inner(id,nombre,estado,publicable,latitud,longitud)")
        val connection = url.openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "GET"; connection.connectTimeout = 2000; connection.readTimeout = 2500
            connection.instanceFollowRedirects = false
            connection.setRequestProperty("apikey", BuildConfig.STAGING_SUPABASE_PUBLISHABLE_KEY)
            require(connection.responseCode == 200)
            val body = connection.inputStream.use { input ->
                val output = java.io.ByteArrayOutputStream()
                val buffer = ByteArray(4096)
                val deadline = SystemClock.elapsedRealtime() + 3000
                while (true) {
                    require(SystemClock.elapsedRealtime() < deadline)
                    val read = input.read(buffer)
                    if (read < 0) break
                    output.write(buffer, 0, read)
                    require(output.size() <= 131072)
                }
                output.toByteArray()
            }
            val a = JSONArray(String(body, Charsets.UTF_8))
            return (0 until a.length()).map { a.getJSONObject(it) }
        } finally { connection.disconnect() }
    }
    @Synchronized private fun validateAndNotify(
        c: Context, z: JSONObject, row: JSONObject, eventLocation: Location,
        currentLocation: Location?, deliveredAtWall: Long, deliveredAtElapsedNanos: Long,
    ): String {
        if (!allowed(c) || !prefs(c).getBoolean("historyImported", false)) return "authorization_required"
        // Recheck persisted generation/zone after the network request and before reserving a slot.
        if (zones(c).none { it.toString() == z.toString() } ||
            z.optString("userId") != prefs(c).getString("userId", null)) return "zone_removed_or_account_changed"
        val time = now(); val business = row.getJSONObject("establecimientos")
        if (z.getLong("expires") <= time || !StagingProximityPolicy.eligible(row.getBoolean("activa"),
                business.getString("estado") == "aprobado", business.getBoolean("publicable"),
                Instant.parse(row.getString("fecha_inicio")).toEpochMilli(),
                Instant.parse(row.getString("fecha_fin")).toEpochMilli(), time)) return "promotion_not_eligible"
        if (business.getString("id") != z.getString("business") ||
            business.getDouble("latitud") != z.getDouble("lat") || business.getDouble("longitud") != z.getDouble("lon")) return "zone_changed"
        val userRadius = foreground(c).getLong("flutter.cercly.alertas_proximidad.radio_metros.v1", 5000L).toDouble()
        val radius = minOf(z.getDouble("radius"), row.getDouble("radio_alerta_metros"), userRadius)
        val eventAge = if (eventLocation.elapsedRealtimeNanos > 0L && deliveredAtElapsedNanos >= eventLocation.elapsedRealtimeNanos)
            (deliveredAtElapsedNanos - eventLocation.elapsedRealtimeNanos) / 1_000_000L else Long.MAX_VALUE
        val eventDistance = StagingProximityPolicy.distance(eventLocation.latitude, eventLocation.longitude, z.getDouble("lat"), z.getDouble("lon"))
        if (!eventLocation.hasAccuracy() || !StagingProximityPolicy.nativeEventEvidenceValid(
                eventDistance, eventLocation.accuracy.toDouble(), eventAge, radius)) return "transition_evidence_outside_or_uncertain"
        val current = currentLocation ?: return "fresh_location_unavailable"
        val currentAge = if (current.elapsedRealtimeNanos > 0L && SystemClock.elapsedRealtimeNanos() >= current.elapsedRealtimeNanos)
            (SystemClock.elapsedRealtimeNanos() - current.elapsedRealtimeNanos) / 1_000_000L else Long.MAX_VALUE
        val currentDistance = StagingProximityPolicy.distance(current.latitude, current.longitude, z.getDouble("lat"), z.getDouble("lon"))
        if (!current.hasAccuracy() || !StagingProximityPolicy.inRange(currentDistance, current.accuracy.toDouble(), currentAge, radius))
            return "current_location_outside_or_uncertain"
        reserve(c, row.getString("id"), business.getString("id"))?.let { return it }
        return try {
            val manager = c.getSystemService(NotificationManager::class.java)
            if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel(CHANNEL, "Promociones cercanas", NotificationManager.IMPORTANCE_HIGH))
            val intent = Intent(c, MainActivity::class.java)
                .putExtra(EXTRA_ESTABLISHMENT_ID, business.getString("id"))
                .putExtra(EXTRA_PROMOTION_ID, row.getString("id"))
                .setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            val pending = PendingIntent.getActivity(c, 4918, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val notification = NotificationCompat.Builder(c, CHANNEL).setSmallIcon(R.drawable.ic_notification)
                .setContentTitle("Promoción cerca de ti")
                .setContentText("${row.getString("titulo").take(100)} en ${business.getString("nombre").take(100)}")
                .setContentIntent(pending).setAutoCancel(true).setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setDefaults(NotificationCompat.DEFAULT_SOUND or NotificationCompat.DEFAULT_VIBRATE).build()
            manager.notify(4819, notification)
            prefs(c).edit().putLong("notificationAt", time).apply()
            "native_notification_posted"
        } catch (_: Exception) { "delivery_error" } // Reservation remains: fail closed rather than flood retries.
    }
}

class StagingPromotionalGeofenceReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        try { StagingPromotionalGeofencing.receive(context.applicationContext, intent) { pending.finish() } }
        catch (_: Exception) { pending.finish() }
    }
}
class StagingPromotionalGeofenceRestoreReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            val pending = goAsync()
            try { StagingPromotionalGeofencing.restore(context.applicationContext) { pending.finish() } }
            catch (_: Exception) { pending.finish() }
        }
    }
}
