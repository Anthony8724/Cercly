package com.cercly.cercly.proximity

import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URL

/** No retries: a lost response may already have created a reservation. */
internal class GeofenceRpcClient(
    private val baseUrl: String,
    private val publicKey: String,
    private val staging: Boolean = false,
    private val connect: (URL) -> HttpURLConnection = { it.openConnection() as HttpURLConnection },
) {
    fun post(name: String, body: String, accessToken: String): String {
        val expected = if (staging) "https://dlajxviqhkdcqnmczhvr.supabase.co"
            else "https://aimubazregckmjchnszf.supabase.co"
        require(baseUrl == expected)
        require(publicKey.startsWith("sb_publishable_"))
        require(name == "reservar_promocion_geofencing" || name == "finalizar_reserva_geofencing")
        require(accessToken.isNotBlank() && '\n' !in accessToken && '\r' !in accessToken)
        val connection = connect(URL("$baseUrl/rest/v1/rpc/$name"))
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 2000
            connection.readTimeout = 2500
            connection.instanceFollowRedirects = false
            connection.doOutput = true
            connection.setRequestProperty("apikey", publicKey)
            connection.setRequestProperty("Authorization", "Bearer $accessToken")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            require(connection.responseCode in 200..299)
            val bytes = connection.inputStream.use { input ->
                val output = ByteArrayOutputStream()
                val buffer = ByteArray(2048)
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    output.write(buffer, 0, count)
                    require(output.size() <= 16384)
                }
                output.toByteArray()
            }
            return String(bytes, Charsets.UTF_8)
        } finally { connection.disconnect() }
    }
}
