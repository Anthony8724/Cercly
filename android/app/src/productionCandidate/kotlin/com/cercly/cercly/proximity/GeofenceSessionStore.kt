package com.cercly.cercly.proximity

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONObject
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Only the short-lived access token is shared with the receiver; Flutter owns refresh. */
internal object GeofenceSessionStore {
    private const val ALIAS = "cercly.geofence.access.v1"
    private const val PREFS = "cercly_geofence_secure_v1"
    data class Snapshot(val userId: String, val sessionId: String, val token: String, val expiresAt: Long)
    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").run {
            init(KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
            generateKey()
        }
    }
    @Synchronized fun clear(c: Context): Boolean = prefs(c).edit().clear().commit()
    @Synchronized fun save(c: Context, userId: String, token: String): Boolean = try {
        val parts = token.split('.')
        require(parts.size == 3)
        val claims = JSONObject(String(Base64.decode(parts[1], Base64.URL_SAFE or Base64.NO_WRAP), Charsets.UTF_8))
        require(claims.getString("sub") == userId && ProximityPolicy.uuid(userId))
        require(ProximityPolicy.uuid(claims.getString("session_id")))
        require(claims.getLong("exp") * 1000 > System.currentTimeMillis() + 15_000)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val ciphertext = cipher.doFinal(token.toByteArray(Charsets.UTF_8))
        prefs(c).edit().putString("iv", Base64.encodeToString(cipher.iv, Base64.NO_WRAP))
            .putString("ciphertext", Base64.encodeToString(ciphertext, Base64.NO_WRAP)).commit()
    } catch (_: Exception) { clear(c); false }
    @Synchronized fun load(c: Context): Snapshot? { return try {
        val p = prefs(c)
        val iv = Base64.decode(p.getString("iv", null) ?: return null, Base64.NO_WRAP)
        val bytes = Base64.decode(p.getString("ciphertext", null) ?: return null, Base64.NO_WRAP)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, iv))
        val token = String(cipher.doFinal(bytes), Charsets.UTF_8)
        val claims = JSONObject(String(Base64.decode(token.split('.')[1], Base64.URL_SAFE or Base64.NO_WRAP), Charsets.UTF_8))
        val snapshot = Snapshot(claims.getString("sub"), claims.getString("session_id"), token, claims.getLong("exp") * 1000)
        if (snapshot.expiresAt <= System.currentTimeMillis() + 15_000 || !ProximityPolicy.uuid(snapshot.userId) || !ProximityPolicy.uuid(snapshot.sessionId)) null else snapshot
    } catch (_: Exception) { null } }
}
