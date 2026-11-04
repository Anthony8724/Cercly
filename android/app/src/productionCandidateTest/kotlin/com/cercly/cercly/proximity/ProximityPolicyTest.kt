package com.cercly.cercly.proximity

import org.junit.Assert.*
import org.junit.Test

class ProximityPolicyTest {
    private val time = 100_000_000L
    @Test fun freshSlotAllowed() { assertNull(ProximityPolicy.cooldown(time, 0, 0, emptyList())) }
    @Test fun duplicatePromotionBlocked() { assertEquals("promotion_cooldown", ProximityPolicy.cooldown(time, time - 1, 0, emptyList())) }
    @Test fun globalCooldownShared() { assertEquals("global_cooldown", ProximityPolicy.cooldown(time, 0, time - 1, emptyList())) }
    @Test fun dailyQuotaBlocksFourth() { assertEquals("daily_limit", ProximityPolicy.cooldown(time, 0, 0, listOf(time-1, time-2, time-3))) }
    @Test fun oldHistoryExpires() { assertNull(ProximityPolicy.cooldown(time, time-8_000_000, time-1_000_000, listOf(1,2,3))) }
    @Test fun clockRollbackFailsClosed() { assertNotNull(ProximityPolicy.cooldown(time, time+1, 0, emptyList())) }
    @Test fun expiredPromotionRejected() { assertFalse(ProximityPolicy.eligible(true,true,true,1,time,time)) }
    @Test fun unpublishedPromotionRejected() { assertFalse(ProximityPolicy.eligible(true,true,false,1,time+1,time)) }
    @Test fun unapprovedPromotionRejected() { assertFalse(ProximityPolicy.eligible(true,false,true,1,time+1,time)) }
    @Test fun futureOrInactiveRejected() {
        assertFalse(ProximityPolicy.eligible(true,true,true,time+1,time+2,time))
        assertFalse(ProximityPolicy.eligible(false,true,true,1,time+1,time))
    }
    @Test fun validPromotionAccepted() { assertTrue(ProximityPolicy.eligible(true,true,true,1,time+1,time)) }
    @Test fun uncertainLocationRejected() {
        assertFalse(ProximityPolicy.inRange(10.0,1000.0,1,5000.0))
        assertFalse(ProximityPolicy.inRange(10.0,1.0,300001,5000.0))
        assertFalse(ProximityPolicy.inRange(10.0,Double.NaN,1,5000.0))
    }
    @Test fun radiusAndPrecisionCheckedTogether() {
        assertFalse(ProximityPolicy.inRange(4990.0,20.0,1,5000.0))
        assertTrue(ProximityPolicy.inRange(100.0,20.0,1,5000.0))
    }
    @Test fun physicalCoordinatesChecked() {
        assertFalse(ProximityPolicy.positionValid(91.0,1.0))
        assertFalse(ProximityPolicy.positionValid(Double.NaN,1.0))
        assertTrue(ProximityPolicy.positionValid(0.0,0.0))
    }
    @Test fun distanceForKnownGeography() {
        assertEquals(111194.9, ProximityPolicy.distance(0.0,0.0,1.0,0.0),1.0)
    }
    @Test fun identifiersValidated() {
        assertTrue(ProximityPolicy.uuid("12345678-abcd-abcd-abcd-123456789abc"))
        assertFalse(ProximityPolicy.uuid("------------------------------------"))
    }
}
