package com.cercly.cercly.proximity

import org.junit.Assert.*
import org.junit.Test
import java.io.IOException

class GeofenceDeliveryTest {
    private val id = "12345678-abcd-4abc-8abc-123456789abc"

    @Test fun confirmedReservationPublishesOnceAndFinalizes() {
        val calls = mutableListOf<String>()
        val outcome = GeofenceDelivery.deliver(
            reserve = { calls.add("reserve"); id },
            publishIfAuthorized = { calls.add("notify"); "native_notification_posted" },
            finish = { reservation, status -> calls.add("finish:$reservation:$status") },
        )
        assertEquals("native_notification_posted", outcome)
        assertEquals(listOf("reserve", "notify", "finish:$id:sent"), calls)
    }
    @Test fun deniedReservationNeverPublishesOrFinalizes() {
        var calls = 0
        val result = GeofenceDelivery.deliver({ null }, { calls++; "native_notification_posted" }, { _, _ -> calls++ })
        assertEquals("reservation_denied", result)
        assertEquals(0, calls)
    }
    @Test fun offlineDoesNotPublish() {
        var calls = 0
        val result = GeofenceDelivery.deliver({ throw IOException("offline") }, { calls++; "native_notification_posted" }, { _, _ -> calls++ })
        assertEquals("reservation_unavailable", result)
        assertEquals(0, calls)
    }
    @Test fun accountChangeOrExpiredTokenDoesNotPublishAndFinalizesFailed() {
        val statuses = mutableListOf<String>()
        val result = GeofenceDelivery.deliver({ id }, { "authorization_changed" }, { _, status -> statuses.add(status) })
        assertEquals("authorization_changed", result)
        assertEquals(listOf("failed"), statuses)
    }
    @Test fun invalidReservationNeverPublishes() {
        var called = false
        assertEquals("reservation_invalid", GeofenceDelivery.deliver({ "bad" }, { called = true; "native_notification_posted" }, { _, _ -> called = true }))
        assertFalse(called)
    }
    @Test fun duplicateRejectedByBackendCannotNotifyTwice() {
        var reserved = false
        var notifications = 0
        fun run() = GeofenceDelivery.deliver(
            reserve = { if (reserved) null else id.also { reserved = true } },
            publishIfAuthorized = { notifications++; "native_notification_posted" },
            finish = { _, _ -> },
        )
        assertEquals("native_notification_posted", run())
        assertEquals("reservation_denied", run())
        assertEquals(1, notifications)
    }
    @Test fun uncertainFinalizationIsNotRetried() {
        var attempts = 0
        val result = GeofenceDelivery.deliver({ id }, { "native_notification_posted" }, { _, _ -> attempts++; throw IOException("timeout") })
        assertEquals("native_notification_posted", result)
        assertEquals(1, attempts)
    }
}
