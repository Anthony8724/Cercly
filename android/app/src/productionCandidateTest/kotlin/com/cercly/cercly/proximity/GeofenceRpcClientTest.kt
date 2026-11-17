package com.cercly.cercly.proximity

import org.junit.Assert.*
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.net.ServerSocket
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class GeofenceRpcClientTest {
    private val base = "https://aimubazregckmjchnszf.supabase.co"
    private class Fake(url: URL, private val status: Int, private val response: String) : HttpURLConnection(url) {
        val headers = mutableMapOf<String, String>()
        val sent = ByteArrayOutputStream()
        var closed = false
        override fun setRequestProperty(key: String, value: String) { headers[key] = value }
        override fun getOutputStream() = sent
        override fun getResponseCode() = status
        override fun getInputStream() = ByteArrayInputStream(response.toByteArray())
        override fun disconnect() { closed = true }
        override fun usingProxy() = false
        override fun connect() {}
    }
    @Test fun authenticatedReservationUsesPostAndBearer() {
        lateinit var fake: Fake
        val client = GeofenceRpcClient(base, "sb_publishable_test") { url -> Fake(url, 200, "[{}]").also { fake = it } }
        assertEquals("[{}]", client.post("reservar_promocion_geofencing", "{\"p_event_id\":\"event\"}", "jwt"))
        assertEquals("Bearer jwt", fake.headers["Authorization"])
        assertEquals("sb_publishable_test", fake.headers["apikey"])
        assertEquals("POST", fake.requestMethod)
        assertEquals("{\"p_event_id\":\"event\"}", fake.sent.toString("UTF-8"))
        assertFalse(fake.instanceFollowRedirects)
        assertTrue(fake.closed)
    }
    @Test fun finalizeUsesSeparateRpc() {
        lateinit var fake: Fake
        val client = GeofenceRpcClient(base, "sb_publishable_test") { url -> Fake(url, 204, "").also { fake = it } }
        assertEquals("", client.post("finalizar_reserva_geofencing", "{}", "jwt"))
        assertTrue(fake.url.path.endsWith("/finalizar_reserva_geofencing"))
    }
    @Test fun rejectedOrUnavailableNeverReturnsSuccess() {
        for (status in listOf(401, 403, 500)) {
            val client = GeofenceRpcClient(base, "sb_publishable_test") { Fake(it, status, "") }
            assertThrows(IllegalArgumentException::class.java) { client.post("reservar_promocion_geofencing", "{}", "jwt") }
        }
    }
    @Test fun sendsActualHttpRequestToLocalServer() {
        ServerSocket(0, 1, java.net.InetAddress.getLoopbackAddress()).use { server ->
            server.soTimeout = 5000
            val worker = Executors.newSingleThreadExecutor()
            try {
                val captured = worker.submit<List<String>> {
                    server.accept().use { socket ->
                        socket.soTimeout = 5000
                        val input = socket.getInputStream().bufferedReader(Charsets.UTF_8)
                        val headers = mutableListOf<String>()
                        while (true) {
                            val line = input.readLine() ?: error("truncated request")
                            if (line.isEmpty()) break
                            headers.add(line)
                        }
                        val length = headers.first { it.startsWith("Content-Length:", true) }.substringAfter(':').trim().toInt()
                        val body = CharArray(length)
                        var count = 0
                        while (count < length) {
                            val n = input.read(body, count, length - count)
                            check(n > 0); count += n
                        }
                        val bodyOut = "[{\"reservation_id\":\"accepted\"}]"
                        socket.getOutputStream().write(("HTTP/1.1 200 OK\r\nContent-Length: ${bodyOut.toByteArray().size}\r\nConnection: close\r\n\r\n" + bodyOut).toByteArray())
                        headers + String(body)
                    }
                }
                val client = GeofenceRpcClient(base, "sb_publishable_test") { target ->
                    URL("http://127.0.0.1:${server.localPort}${target.path}").openConnection() as HttpURLConnection
                }
                val result = client.post("reservar_promocion_geofencing", "{\"event\":1}", "synthetic-jwt")
                assertTrue(result.contains("accepted"))
                val request = captured.get(5, TimeUnit.SECONDS)
                assertTrue(request.first().startsWith("POST /rest/v1/rpc/reservar_promocion_geofencing "))
                assertTrue(request.any { it.equals("Authorization: Bearer synthetic-jwt", true) })
                assertEquals("{\"event\":1}", request.last())
            } finally { worker.shutdownNow() }
        }
    }
    @Test fun refusesOtherBackendSecretKeyAndUnknownRpc() {
        assertThrows(IllegalArgumentException::class.java) { GeofenceRpcClient("https://evil.example", "sb_publishable_test").post("reservar_promocion_geofencing", "{}", "jwt") }
        assertThrows(IllegalArgumentException::class.java) { GeofenceRpcClient(base, "sb_secret_test").post("reservar_promocion_geofencing", "{}", "jwt") }
        assertThrows(IllegalArgumentException::class.java) { GeofenceRpcClient(base, "sb_publishable_test").post("other", "{}", "jwt") }
    }
}
