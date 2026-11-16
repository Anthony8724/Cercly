package com.cercly.cercly.proximity

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.google.android.gms.location.LocationServices

/**
 * Best-effort removal of the PendingIntent identity used by the retired QA
 * geofence. It deliberately has no receiver, event handler, coordinates, or
 * notification path.
 */
internal object LegacyGeofenceCleanup {
    private const val LEGACY_ACTION = "com.cercly.cercly.STAGING_GEOFENCE"
    private const val LEGACY_RECEIVER =
        "com.cercly.cercly.proximity.GeofenceBroadcastReceiver"
    private const val REQUEST_CODE = 4817

    fun remove(context: Context) {
        try {
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0
            val identity = PendingIntent.getBroadcast(
                context,
                REQUEST_CODE,
                Intent().setClassName(context.packageName, LEGACY_RECEIVER)
                    .setAction(LEGACY_ACTION),
                flags,
            )
            LocationServices.getGeofencingClient(context).removeGeofences(identity)
        } catch (_: Exception) {
            // Cleanup is best effort; current Staging registration remains independent.
        }
    }
}
