package com.cercly.cercly.proximity

/** Coordinator for one event. Reservation and completion are never retried. */
internal object GeofenceDelivery {
    fun deliver(
        reserve: () -> String?,
        publishIfAuthorized: () -> String,
        finish: (String, String) -> Unit,
    ): String {
        val reservation = try { reserve() } catch (_: Exception) { return "reservation_unavailable" }
        if (reservation == null) return "reservation_denied"
        if (!ProximityPolicy.uuid(reservation)) return "reservation_invalid"
        val outcome = try { publishIfAuthorized() } catch (_: Exception) { "delivery_error" }
        try {
            finish(reservation, if (outcome == "native_notification_posted") "sent" else "failed")
        } catch (_: Exception) {
            // A lost response may already have succeeded. Never retry here.
        }
        return outcome
    }
}
