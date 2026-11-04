package com.cercly.cercly.proximity

import kotlin.math.*

/** Pure policy: no device location or credentials persisted here. */
object ProximityPolicy {
    const val DAY = 86_400_000L
    const val MAX_ZONES = 20
    fun uuid(value: String) = value.matches(Regex("[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}"))
    fun distance(a: Double, b: Double, c: Double, d: Double): Double {
        val x = sin(Math.toRadians(c - a) / 2).pow(2) + cos(Math.toRadians(a)) *
            cos(Math.toRadians(c)) * sin(Math.toRadians(d - b) / 2).pow(2)
        return 6371000 * 2 * asin(sqrt(x.coerceIn(0.0, 1.0)))
    }
    fun positionValid(lat: Double, lon: Double) = lat.isFinite() && lon.isFinite() &&
        lat in -90.0..90.0 && lon in -180.0..180.0
    fun inRange(distance: Double, accuracy: Double, age: Long, radius: Double) =
        distance.isFinite() && accuracy.isFinite() && accuracy in 0.0..minOf(200.0, radius / 2) &&
            age in 0L..300_000L && distance + accuracy <= radius
    fun cooldown(now: Long, lastPromotion: Long, lastGlobal: Long, recent: List<Long>): String? = when {
        lastPromotion > 0 && now - lastPromotion < 7_200_000 -> "promotion_cooldown"
        lastGlobal > 0 && now - lastGlobal < 900_000 -> "global_cooldown"
        recent.count { now - it < DAY } >= 3 -> "daily_limit"
        else -> null
    }
    fun eligible(active: Boolean, approved: Boolean, published: Boolean, start: Long, end: Long, now: Long) =
        active && approved && published && start <= now && now < end
}
