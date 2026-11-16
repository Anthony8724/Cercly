package com.cercly.cercly.proximity

import org.junit.Assert.*
import org.junit.Test

class StagingProximityPolicyTest {
    @Test fun validPromotionRequiresActiveApprovedPublishedAndCurrentWindow() {
        val now = 1_000_000L
        assertTrue(StagingProximityPolicy.eligible(true, true, true, now, now + 1, now))
        assertFalse(StagingProximityPolicy.eligible(false, true, true, now, now + 1, now))
        assertFalse(StagingProximityPolicy.eligible(true, false, true, now, now + 1, now))
        assertFalse(StagingProximityPolicy.eligible(true, true, false, now, now + 1, now))
        assertFalse(StagingProximityPolicy.eligible(true, true, true, now - 2, now, now))
    }

    @Test fun locationMustBeFreshAndAccurateAndUncertaintyMustFitInsideRadius() {
        assertTrue(StagingProximityPolicy.inRange(1_350.0, 100.0, 120_000, 1_500.0))
        assertFalse(StagingProximityPolicy.inRange(1_401.0, 100.0, 1_000, 1_500.0))
        assertFalse(StagingProximityPolicy.inRange(100.0, 101.0, 1_000, 1_500.0))
        assertFalse(StagingProximityPolicy.inRange(100.0, 10.0, 120_001, 1_500.0))
    }

    @Test fun delayedNativeTransitionNeedsSeparateFreshCurrentPosition() {
        // A delayed transition sample remains plausible evidence up to the documented
        // Android delay window plus margin, but cannot itself authorize notification.
        assertTrue(StagingProximityPolicy.nativeEventEvidenceValid(900.0, 50.0, 6 * 60_000L, 1_500.0))
        assertFalse(StagingProximityPolicy.nativeEventEvidenceValid(900.0, 50.0, 600_001L, 1_500.0))
        assertFalse(StagingProximityPolicy.nativeEventEvidenceValid(1_451.0, 50.0, 1_000L, 1_500.0))
        assertTrue(StagingProximityPolicy.eventTimesValid(360_000L, 361_000L))
        assertFalse(StagingProximityPolicy.eventTimesValid(360_000L, 0L))
        assertFalse(StagingProximityPolicy.eventTimesValid(600_001L, 600_001L))
        assertTrue(StagingProximityPolicy.inRange(900.0, 50.0, 120_000L, 1_500.0))
        assertFalse(StagingProximityPolicy.inRange(900.0, 50.0, 120_001L, 1_500.0))
    }

    @Test fun frequencyCooldownAndPromotionDedupAreSharedByLocalChannels() {
        val now = 100_000_000L
        assertEquals("promotion_already_notified", StagingProximityPolicy.cooldown(now, 1, 0, 0, emptyList(), 6))
        assertEquals("business_cooldown", StagingProximityPolicy.cooldown(now, 0, now - 14_399_999, 0, emptyList(), 6))
        assertNull(StagingProximityPolicy.cooldown(now, 0, now - 14_400_000, now - 900_000, emptyList(), 6))
        assertEquals("global_cooldown", StagingProximityPolicy.cooldown(now, 0, 0, now - 899_999, emptyList(), 6))
        for (limit in listOf(3, 6, 10)) {
            assertEquals("daily_limit", StagingProximityPolicy.cooldown(now, 0, 0, 0, (1..limit).map { now - it }, limit))
        }
    }

    @Test fun quietHoursSupportIntervalsAcrossMidnight() {
        assertTrue(StagingProximityPolicy.inQuietHours(23 * 60, 22 * 60, 6 * 60))
        assertTrue(StagingProximityPolicy.inQuietHours(5 * 60 + 59, 22 * 60, 6 * 60))
        assertFalse(StagingProximityPolicy.inQuietHours(6 * 60, 22 * 60, 6 * 60))
        assertFalse(StagingProximityPolicy.inQuietHours(12 * 60, null, null))
    }
}
