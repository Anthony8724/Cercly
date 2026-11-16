package com.cercly.cercly.proximity

import kotlin.math.*

/** Pure policy: no device location or credentials persisted here. */
object StagingProximityPolicy {
    const val DAY = 86_400_000L
    const val MAX_ZONES = 20
    // Android may defer geofence delivery; the transition sample is evidence only,
    // never sufficient by itself to publish a notification.
    const val MAX_NATIVE_EVENT_SAMPLE_AGE_MS = 600_000L
    const val MAX_CURRENT_SAMPLE_AGE_MS = 120_000L
    fun uuid(value: String) = value.matches(Regex("[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}"))
    fun distance(a: Double, b: Double, c: Double, d: Double): Double {
        val x = sin(Math.toRadians(c - a) / 2).pow(2) + cos(Math.toRadians(a)) *
            cos(Math.toRadians(c)) * sin(Math.toRadians(d - b) / 2).pow(2)
        return 6371000 * 2 * asin(sqrt(x.coerceIn(0.0, 1.0)))
    }
    fun positionValid(lat: Double, lon: Double) = lat.isFinite() && lon.isFinite() &&
        lat in -90.0..90.0 && lon in -180.0..180.0
    fun inRange(distance: Double, accuracy: Double, age: Long, radius: Double) =
        distance.isFinite() && accuracy.isFinite() && accuracy in 0.0..minOf(100.0, radius / 2) &&
            age in 0L..MAX_CURRENT_SAMPLE_AGE_MS && distance + accuracy <= radius
    fun nativeEventEvidenceValid(distance: Double, accuracy: Double, sampleAge: Long, radius: Double) =
        distance.isFinite() && accuracy.isFinite() && accuracy in 0.0..minOf(100.0, radius / 2) &&
            sampleAge in 0L..MAX_NATIVE_EVENT_SAMPLE_AGE_MS && distance + accuracy <= radius
    fun eventTimesValid(monotonicAge: Long, wallAge: Long) =
        monotonicAge in 0L..MAX_NATIVE_EVENT_SAMPLE_AGE_MS &&
            wallAge in 0L..MAX_NATIVE_EVENT_SAMPLE_AGE_MS &&
            kotlin.math.abs(monotonicAge - wallAge) <= 120_000L
    fun inQuietHours(localMinute: Int, start: Int?, end: Int?): Boolean {
        if (start == null || end == null || start !in 0..1439 || end !in 0..1439 || start == end) return false
        return if (start < end) localMinute in start until end else localMinute >= start || localMinute < end
    }
    fun cooldown(now: Long, lastPromotion: Long, lastBusiness: Long, lastGlobal: Long, recent: List<Long>, dailyLimit: Int): String? = when {
        lastPromotion > 0 -> "promotion_already_notified"
        lastBusiness > 0 && now - lastBusiness < 14_400_000 -> "business_cooldown"
        lastGlobal > 0 && now - lastGlobal < 900_000 -> "global_cooldown"
        recent.count { now - it in 0..DAY } >= dailyLimit -> "daily_limit"
        else -> null
    }
    fun eligible(active: Boolean, approved: Boolean, published: Boolean, start: Long, end: Long, now: Long) =
        active && approved && published && start <= now && now < end
}
