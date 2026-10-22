package com.example.listenfy

import android.Manifest
import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.NetworkInfo
import android.net.wifi.p2p.WifiP2pConfig
import android.net.wifi.p2p.WifiP2pManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.*
import java.math.BigInteger
import java.net.InetSocketAddress
import java.security.*
import java.security.cert.X509Certificate
import java.util.Date
import java.util.UUID
import java.util.concurrent.*
import java.util.concurrent.atomic.AtomicBoolean
import javax.net.ssl.*
import javax.security.auth.x500.X500Principal

/** Instantiate on the main thread; close() detaches the engine, channel close ends a session. */
class WifiDirectTransferBridge(private val activity: Activity, engine: FlutterEngine) {
    private val methods = MethodChannel(engine.dartExecutor.binaryMessenger, "listenfy/wifi_direct")
    private val events = EventChannel(engine.dartExecutor.binaryMessenger, "listenfy/wifi_direct/events")
    @Volatile private var sink: EventChannel.EventSink? = null
    private var current: Session? = null
    private var p2pOwner: Session? = null
    private var disposed = false
    private class Failure(val code: String) : IOException(code)
    init {
        methods.setMethodCallHandler { call, result ->
            if (disposed) result.error("closed", "closed", null)
            else {
                if (current == null || current!!.dead.get()) current = Session()
                current!!.dispatch(call, result)
            }
        }
        events.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) { sink = eventSink }
            override fun onCancel(arguments: Any?) { sink = null }
        })
    }
    fun close() {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            Handler(Looper.getMainLooper()).post { close() }; return
        }
        if (disposed) return
        disposed = true
        current?.close()
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        Handler(Looper.getMainLooper()).post { sink = null }
    }
    private inner class Session {
    private val main = Handler(Looper.getMainLooper())
    private val workers = Executors.newCachedThreadPool()
    private val writer = Executors.newSingleThreadExecutor()
    private val timer = Executors.newSingleThreadScheduledExecutor()
    val dead = AtomicBoolean(false)
    private val manager = activity.getSystemService(Context.WIFI_P2P_SERVICE) as? WifiP2pManager
    private var channel: WifiP2pManager.Channel? = null
    private var registered = false
    private var state = "idle"
    private var owned = false
    private var established = false
    private var attempts = 0
    private var joinExpiresAt = 0L
    private var joinRetry: Runnable? = null
    private var deadline: ScheduledFuture<*>? = null
    private var heartbeat: ScheduledFuture<*>? = null
    private val alias = "listenfy-wfd-${UUID.randomUUID()}"
    @Volatile private var session = ""
    private var secret = ByteArray(0)
    private var network = ""
    private var password = ""
    private var pin = ""
    private var hostContext: SSLContext? = null
    @Volatile private var server: SSLServerSocket? = null
    @Volatile private var socket: SSLSocket? = null
    @Volatile private var authenticated = false
    @Volatile private var lastRead = System.nanoTime()
    @Volatile private var lastWrite = System.nanoTime()
    private val writeLock = Any()
    private val pendingSent = ConcurrentHashMap.newKeySet<Long>()
    private val pendingReceived = ConcurrentHashMap.newKeySet<Long>()
    private val incomingIds = ConcurrentHashMap.newKeySet<Long>()
    private val partials = ConcurrentHashMap.newKeySet<File>()
    private val pendingResults = ConcurrentHashMap.newKeySet<Reply>()

    private inner class Reply(private val result: MethodChannel.Result) {
        private val done = AtomicBoolean(false)
        init { pendingResults.add(this) }
        fun success(value: Any? = null) = finish { result.success(value) }
        fun error(code: String) = finish { result.error(code, code, null) }
        private fun finish(block: () -> Unit) {
            if (done.compareAndSet(false, true)) {
                pendingResults.remove(this)
                main.post(block)
            }
        }
    }
    private fun requireThat(ok: Boolean, code: String) { if (!ok) throw Failure(code) }
    private fun code(e: Throwable) = when (e) {
        is Failure -> e.code
        is SecurityException -> "permission_denied"
        is SSLException -> "tls_failed"
        is java.net.SocketTimeoutException -> "timeout"
        else -> "transport_failed"
    }
    private fun emit(type: String, vararg fields: Pair<String, Any?>) {
        val event = mapOf("type" to type, "sessionId" to session, *fields)
        main.post { sink?.success(event) }
    }
    private fun fail(e: Throwable) {
        main.post { if (!dead.get()) { emit("error", "code" to code(e)); close() } }
    }
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (dead.get() || intent.action != WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION) return
            @Suppress("DEPRECATION")
            val info = intent.getParcelableExtra<NetworkInfo>(WifiP2pManager.EXTRA_NETWORK_INFO)
            if (info?.isConnected == true) pollConnection()
            else if (established) fail(Failure("group_lost"))
        }
    }
    fun dispatch(call: MethodCall, result: MethodChannel.Result) {
            val reply = Reply(result)
            try { handle(call, reply) } catch (e: Exception) { reply.error(code(e)) }
    }
    private fun gate() {
        requireThat(!dead.get(), "closed")
        requireThat(Build.VERSION.SDK_INT >= 29, "unsupported_android")
        requireThat(activity.packageManager.hasSystemFeature(PackageManager.FEATURE_WIFI_DIRECT) && manager != null, "wifi_direct_unavailable")
        val permissions = mutableListOf(Manifest.permission.ACCESS_WIFI_STATE, Manifest.permission.CHANGE_WIFI_STATE, Manifest.permission.INTERNET)
        permissions.add(if (Build.VERSION.SDK_INT >= 33 && activity.applicationInfo.targetSdkVersion >= 33) "android.permission.NEARBY_WIFI_DEVICES" else Manifest.permission.ACCESS_FINE_LOCATION)
        requireThat(permissions.all { activity.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }, "permission_denied")
        if (channel == null) {
            channel = manager!!.initialize(activity, main.looper) { fail(Failure("channel_lost")) }
            val filter = IntentFilter(WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION)
            if (Build.VERSION.SDK_INT >= 33) activity.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            else activity.registerReceiver(receiver, filter)
            registered = true
        }
    }
    private fun text(args: Map<*, *>, name: String): String = (args[name] as? String)?.also {
        requireThat(it.isNotEmpty() && it.length <= 4096, "invalid_arguments")
    } ?: throw Failure("invalid_arguments")
    private fun credentials(args: Map<*, *>) {
        val s = text(args, "sessionId")
        val key = try { Base64.decode(text(args, "secret"), Base64.URL_SAFE or Base64.NO_WRAP) } catch (_: Exception) { throw Failure("invalid_secret") }
        val n = text(args, "networkName")
        val p = text(args, "passphrase")
        requireThat(s.length <= 128 && key.size == 32, "invalid_credentials")
        requireThat(n.matches(Regex("DIRECT-LF-[A-Za-z0-9_-]+")) && n.toByteArray(Charsets.UTF_8).size <= 32, "invalid_network_name")
        requireThat(p.length in 16..63 && p.all { it.code in 32..126 }, "invalid_passphrase")
        session = s; secret = key; network = n; password = p
    }
    private fun handle(call: MethodCall, reply: Reply) {
        if (call.method == "close") { reply.success(); close(); return }
        gate()
        val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
        when (call.method) {
            "prepare" -> {
                requireThat(state == "idle", "invalid_state")
                credentials(args); state = "preparing"
                workers.execute {
                    try {
                        val fingerprint = makeIdentity()
                        main.post { if (!dead.get()) { state = "prepared"; reply.success(mapOf("fingerprint" to fingerprint)) } }
                    } catch (e: Exception) { reply.error(code(e)); fail(e) }
                }
            }
            "startHost", "join" -> {
                val hosting = call.method == "startHost"
                requireThat(if (hosting) state == "prepared" else state == "idle" || state == "prepared", "invalid_state")
                requireThat(p2pOwner == null || p2pOwner === this, "p2p_cleanup_pending")
                if (!hosting) {
                    credentials(args); pin = text(args, "fingerprint").lowercase()
                    requireThat(pin.matches(Regex("[0-9a-f]{64}")), "invalid_fingerprint")
                }
                state = if (hosting) "hosting" else "joining"
                p2pOwner = this
                joinExpiresAt = android.os.SystemClock.elapsedRealtime() + 60000
                deadline = timer.schedule({
                    reply.error("connection_timeout")
                    fail(Failure("connection_timeout"))
                }, 60, TimeUnit.SECONDS)
                // Never adopt/remove a group that predates this operation.
                manager!!.requestGroupInfo(channel!!) { existing ->
                    if (!dead.get()) {
                        if (existing != null) { deadline?.cancel(false); p2pOwner = null; state = if (hostContext != null) "prepared" else "idle"; reply.error("existing_group") }
                        else try {
                            val config = WifiP2pConfig.Builder().setNetworkName(network).setPassphrase(password).enablePersistentMode(false).build()
                            config.groupOwnerIntent = if (hosting) 15 else 0
                            submitGroupRequest(config, hosting, reply, 0)
                        } catch (e: Exception) { p2pRequestPending = false; reply.error(code(e)); fail(e) }
                    } else {
                        if (p2pOwner === this@Session) p2pOwner = null
                        channel?.close()
                    }
                }
            }
            "send" -> {
                requireThat(authenticated, "not_connected")
                val file = File(text(args, "path"))
                val descriptor = JSONObject(args["descriptor"] as? Map<*, *> ?: throw Failure("invalid_descriptor"))
                val metadata = validateDescriptor(descriptor)
                requireThat(file.isFile && file.length() == metadata.second, "invalid_file")
                requireThat(pendingSent.add(metadata.first), "duplicate_payload")
                writer.execute {
                    try {
                        synchronized(writeLock) {
                            val output = output()
                            writeHeader(output, JSONObject().put("type", "file").put("descriptor", descriptor).put("sessionId", session))
                            val digest = MessageDigest.getInstance("SHA-256")
                            FileInputStream(file).use { input -> transfer(input, output, metadata.second, metadata.first, "sent", digest) }
                            requireThat(hex(digest.digest()) == descriptor.getString("sha256").lowercase(), "source_hash_mismatch")
                            output.flush()
                        }
                        reply.success()
                    } catch (e: Exception) { reply.error(code(e)); fail(e) }
                }
            }
            "confirm" -> {
                val id = integer(args["payloadId"])
                requireThat(authenticated && pendingReceived.remove(id), "unknown_payload")
                writer.execute {
                    try { control("ack", "payloadId", id); reply.success() }
                    catch (e: Exception) { reply.error(code(e)); fail(e) }
                }
            }
            else -> reply.error("not_implemented")
        }
    }
    private fun submitGroupRequest(config: WifiP2pConfig, hosting: Boolean, reply: Reply, retry: Int) {
        if (dead.get() || established || p2pOwner !== this) return
        if (android.os.SystemClock.elapsedRealtime() >= joinExpiresAt) {
            reply.error("connection_timeout"); fail(Failure("connection_timeout")); return
        }
        p2pRequestPending = true
        val listener = object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                p2pRequestPending = false
                owned = true
                if (dead.get()) { removeOwnedGroup(); return }
                reply.success()
                pollConnection()
            }
            override fun onFailure(reason: Int) {
                p2pRequestPending = false
                if (dead.get()) { releaseChannel(); return }
                if (established) return
                val remaining = joinExpiresAt - android.os.SystemClock.elapsedRealtime()
                if (!hosting && retry < 40 && remaining > 1000 &&
                    (reason == WifiP2pManager.BUSY || reason == WifiP2pManager.ERROR)) {
                    // SSID/passphrase connect locates the existing owner without a MAC.
                    // Discovery helps devices whose P2P scan state has not settled after Nearby.
                    try {
                        manager!!.discoverPeers(channel!!, null)
                        val task = Runnable {
                            joinRetry = null
                            if (!dead.get() && !established && p2pOwner === this@Session) {
                                try { submitGroupRequest(config, false, reply, retry + 1) }
                                catch (e: Exception) { p2pRequestPending = false; reply.error(code(e)); fail(e) }
                            }
                        }
                        joinRetry = task
                        main.postDelayed(task, 1000)
                    } catch (e: Exception) { reply.error(code(e)); fail(e) }
                    return
                }
                reply.error("p2p_$reason"); fail(Failure("p2p_$reason"))
            }
        }
        if (hosting) manager!!.createGroup(channel!!, config, listener)
        else manager!!.connect(channel!!, config, listener)
    }
    private fun makeIdentity(): String = synchronized(alias.intern()) {
        requireThat(!dead.get(), "closed")
        val generator = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_RSA, "AndroidKeyStore")
        val now = System.currentTimeMillis()
        generator.initialize(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY)
            .setKeySize(2048).setDigests(KeyProperties.DIGEST_SHA256, KeyProperties.DIGEST_SHA384, KeyProperties.DIGEST_SHA512)
            .setSignaturePaddings(KeyProperties.SIGNATURE_PADDING_RSA_PKCS1, KeyProperties.SIGNATURE_PADDING_RSA_PSS)
            .setCertificateSubject(X500Principal("CN=Listenfy ephemeral WiFi Direct"))
            .setCertificateSerialNumber(BigInteger(128, SecureRandom()).add(BigInteger.ONE))
            .setCertificateNotBefore(Date(now - 300000)).setCertificateNotAfter(Date(now + 86400000))
            .setUserAuthenticationRequired(false).build())
        generator.generateKeyPair()
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val cert = store.getCertificate(alias) as X509Certificate
        cert.checkValidity(); cert.verify(cert.publicKey)
        val privateKey = store.getKey(alias, null) as PrivateKey
        val keys = object : X509ExtendedKeyManager() {
            override fun getPrivateKey(name: String?): PrivateKey? = if (name == alias) privateKey else null
            override fun getCertificateChain(name: String?): Array<X509Certificate>? = if (name == alias) arrayOf(cert) else null
            override fun getClientAliases(type: String?, issuers: Array<java.security.Principal>?): Array<String>? = null
            override fun chooseClientAlias(types: Array<String>?, issuers: Array<java.security.Principal>?, socket: java.net.Socket?): String? = null
            override fun getServerAliases(type: String?, issuers: Array<java.security.Principal>?): Array<String>? = if (type == "RSA") arrayOf(alias) else null
            override fun chooseServerAlias(type: String?, issuers: Array<java.security.Principal>?, socket: java.net.Socket?): String? = if (type == "RSA") alias else null
        }
        hostContext = SSLContext.getInstance("TLS").apply { init(arrayOf<KeyManager>(keys), null, SecureRandom()) }
        hex(MessageDigest.getInstance("SHA-256").digest(cert.encoded))
    }
    private fun pollConnection() {
        if (dead.get() || established || state !in listOf("hosting", "joining")) return
        try {
            manager!!.requestConnectionInfo(channel!!) { info ->
                if (!dead.get() && !established) {
                    if (info.groupFormed && info.groupOwnerAddress != null) {
                        val hosting = state == "hosting"
                        if (hosting != info.isGroupOwner) { fail(Failure("unexpected_group_role")); return@requestConnectionInfo }
                        established = true
                        workers.execute { try { if (hosting) acceptPeer() else connectPeer(info.groupOwnerAddress.hostAddress!!) } catch (e: Exception) { fail(e) } }
                    } else if (++attempts <= 40) main.postDelayed({ pollConnection() }, 750)
                    else fail(Failure("group_timeout"))
                }
            }
        } catch (e: Exception) { fail(e) }
    }
    private fun configure(s: SSLSocket) {
        s.enabledProtocols = s.supportedProtocols.filter { it == "TLSv1.2" || it == "TLSv1.3" }.toTypedArray()
        s.soTimeout = 20000
        s.tcpNoDelay = true
    }
    private fun acceptPeer() {
        val listener = hostContext!!.serverSocketFactory.createServerSocket() as SSLServerSocket
        server = listener
        if (dead.get()) { listener.close(); throw Failure("closed") }
        listener.reuseAddress = true; listener.bind(InetSocketAddress(39473)); listener.soTimeout = 45000
        val s = listener.accept() as SSLSocket
        socket = s; listener.close(); configure(s)
        if (dead.get()) { s.close(); throw Failure("closed") }
        s.startHandshake()
        val hello = readHeader(DataInputStream(s.inputStream))
        requireThat(hello.getString("type") == "hello" && hello.getString("sessionId") == session, "authentication_failed")
        val supplied = try { Base64.decode(hello.getString("secret"), Base64.NO_WRAP) } catch (_: Exception) { ByteArray(0) }
        requireThat(MessageDigest.isEqual(secret, supplied), "authentication_failed")
        control("ready")
        connected(s)
    }
    private fun connectPeer(address: String) {
        val trust = object : X509TrustManager {
            override fun getAcceptedIssuers(): Array<X509Certificate> = emptyArray()
            override fun checkClientTrusted(chain: Array<X509Certificate>, authType: String) { throw java.security.cert.CertificateException("client unsupported") }
            override fun checkServerTrusted(chain: Array<X509Certificate>, authType: String) {
                if (chain.isEmpty()) throw java.security.cert.CertificateException("missing certificate")
                chain[0].checkValidity()
                val actual = hex(MessageDigest.getInstance("SHA-256").digest(chain[0].encoded))
                if (!MessageDigest.isEqual(actual.toByteArray(Charsets.US_ASCII), pin.toByteArray(Charsets.US_ASCII))) throw java.security.cert.CertificateException("pin mismatch")
            }
        }
        val context = SSLContext.getInstance("TLS").apply { init(null, arrayOf<TrustManager>(trust), SecureRandom()) }
        var connectedSocket: SSLSocket? = null
        for (attempt in 0 until 8) {
            requireThat(!dead.get(), "closed")
            val s = context.socketFactory.createSocket() as SSLSocket
            socket = s; configure(s)
            if (dead.get()) { s.close(); throw Failure("closed") }
            try { s.connect(InetSocketAddress(address, 39473), 3000); connectedSocket = s; break }
            catch (e: IOException) { s.close(); if (attempt == 7) throw e; Thread.sleep(500) }
        }
        val s = connectedSocket ?: throw Failure("connection_failed")
        s.startHandshake()
        control("hello", "secret", Base64.encodeToString(secret, Base64.NO_WRAP))
        val ready = readHeader(DataInputStream(s.inputStream))
        requireThat(ready.getString("type") == "ready" && ready.getString("sessionId") == session, "authentication_failed")
        connected(s)
    }
    private fun connected(s: SSLSocket) {
        requireThat(!dead.get(), "closed")
        authenticated = true; lastRead = System.nanoTime(); lastWrite = lastRead
        deadline?.cancel(false)
        emit("connected", "sessionId" to session)
        heartbeat = timer.scheduleAtFixedRate({
            if (dead.get()) return@scheduleAtFixedRate
            val now = System.nanoTime()
            if (now - lastRead > TimeUnit.SECONDS.toNanos(45) || now - lastWrite > TimeUnit.SECONDS.toNanos(45)) fail(Failure("peer_timeout"))
            else if (now - lastWrite > TimeUnit.SECONDS.toNanos(5)) writer.execute { try { control("ping") } catch (e: Exception) { fail(e) } }
        }, 5, 5, TimeUnit.SECONDS)
        val input = DataInputStream(s.inputStream)
        while (!dead.get()) {
            val header = readHeader(input)
            requireThat(header.getString("sessionId") == session, "session_mismatch")
            when (header.getString("type")) {
                "file" -> receive(input, header.getJSONObject("descriptor"))
                "ack" -> {
                    val id = integer(header.get("payloadId"))
                    writer.execute {
                        try {
                            requireThat(pendingSent.remove(id), "unexpected_ack")
                            if (!dead.get()) emit("sent", "payloadId" to id)
                        } catch (e: Exception) { fail(e) }
                    }
                }
                "ping" -> writer.execute { try { control("pong") } catch (e: Exception) { fail(e) } }
                "pong" -> Unit
                else -> throw Failure("invalid_frame")
            }
        }
    }
    private fun integer(value: Any?): Long {
        requireThat(value is Int || value is Long, "invalid_integer")
        return (value as Number).toLong()
    }
    private fun validateDescriptor(d: JSONObject): Pair<Long, Long> {
        val id = integer(d.get("payloadId")); val size = integer(d.get("sizeBytes"))
        requireThat(id >= 0 && size in 1..1073741824L, "invalid_descriptor")
        requireThat(d.getString("sessionId") == session, "session_mismatch")
        requireThat(d.getString("sha256").matches(Regex("[a-fA-F0-9]{64}")), "invalid_hash")
        val kind = d.getString("kind").lowercase(); val format = d.getString("format").lowercase().removePrefix(".")
        val allowed = if (kind == "audio") setOf("mp3", "m4a", "aac", "wav", "flac", "ogg", "opus", "aiff", "alac") else if (kind == "video") setOf("mp4", "m4v", "mkv", "webm", "mov", "avi", "3gp") else emptySet()
        requireThat(format in allowed, "unsupported_format")
        requireThat(d.getString("fileName").length in 1..1024, "invalid_descriptor")
        return id to size
    }
    private fun receive(input: DataInputStream, descriptor: JSONObject) {
        val (id, size) = validateDescriptor(descriptor)
        requireThat(incomingIds.add(id), "duplicate_payload")
        val dir = File(activity.cacheDir, "wifi-direct-transfer")
        requireThat((dir.isDirectory || dir.mkdirs()) && dir.canonicalFile.parentFile == activity.cacheDir.canonicalFile, "invalid_cache")
        val file = File.createTempFile("incoming-", ".part", dir)
        partials.add(file)
        try {
            val digest = MessageDigest.getInstance("SHA-256")
            FileOutputStream(file).use { transfer(input, it, size, id, "received", digest) }
            requireThat(file.length() == size && hex(digest.digest()) == descriptor.getString("sha256").lowercase(), "hash_mismatch")
            requireThat(!dead.get(), "closed")
            partials.remove(file)
            pendingReceived.add(id)
            emit("received", "descriptor" to jsonMap(descriptor), "path" to file.absolutePath)
        } finally { if (partials.remove(file)) file.delete() }
    }
    private fun transfer(input: InputStream, output: OutputStream, total: Long, id: Long, direction: String, digest: MessageDigest) {
        val buffer = ByteArray(65536); var bytes = 0L; var reported = 0L
        while (bytes < total) {
            requireThat(!dead.get(), "closed")
            val count = input.read(buffer, 0, minOf(buffer.size.toLong(), total - bytes).toInt())
            requireThat(count > 0, "truncated_file")
            if (direction == "received") lastRead = System.nanoTime()
            output.write(buffer, 0, count)
            if (direction == "sent") lastWrite = System.nanoTime()
            digest.update(buffer, 0, count); bytes += count
            if (bytes == total || bytes - reported >= 262144) {
                emit("progress", "payloadId" to id, "direction" to direction, "bytes" to bytes, "total" to total); reported = bytes
            }
        }
    }
    private fun output(): DataOutputStream {
        requireThat(!dead.get(), "closed")
        return DataOutputStream(socket?.outputStream ?: throw Failure("not_connected"))
    }
    private fun control(type: String, key: String? = null, value: Any? = null) = synchronized(writeLock) {
        val header = JSONObject().put("type", type).put("sessionId", session)
        if (key != null) header.put(key, value)
        val output = output(); writeHeader(output, header); output.flush(); lastWrite = System.nanoTime()
    }
    private fun writeHeader(output: DataOutputStream, header: JSONObject) {
        val bytes = header.toString().toByteArray(Charsets.UTF_8)
        requireThat(bytes.size in 1..262144, "invalid_header_length")
        output.writeInt(bytes.size); output.write(bytes)
    }
    private fun readHeader(input: DataInputStream): JSONObject {
        val size = input.readInt()
        requireThat(size in 1..262144, "invalid_header_length")
        val bytes = ByteArray(size)
        var offset = 0
        while (offset < size) {
            val count = input.read(bytes, offset, size - offset)
            requireThat(count > 0, "truncated_header"); offset += count; lastRead = System.nanoTime()
        }
        val decoded = Charsets.UTF_8.newDecoder().onMalformedInput(java.nio.charset.CodingErrorAction.REPORT).decode(java.nio.ByteBuffer.wrap(bytes)).toString()
        // JSONObject accepts non-JSON syntax; validate strictly before constructing it.
        android.util.JsonReader(StringReader(decoded)).use { reader ->
            reader.isLenient = false
            validateJson(reader, 0)
            requireThat(reader.peek() == android.util.JsonToken.END_DOCUMENT, "invalid_json")
        }
        val tokener = org.json.JSONTokener(decoded)
        val value = tokener.nextValue()
        requireThat(value is JSONObject && tokener.nextClean() == '\u0000', "invalid_json")
        return value as JSONObject
    }
    private fun validateJson(reader: android.util.JsonReader, depth: Int) {
        requireThat(depth <= 32, "invalid_json")
        when (reader.peek()) {
            android.util.JsonToken.BEGIN_OBJECT -> {
                reader.beginObject()
                val names = HashSet<String>()
                while (reader.hasNext()) {
                    requireThat(names.add(reader.nextName()), "invalid_json")
                    validateJson(reader, depth + 1)
                }
                reader.endObject()
            }
            android.util.JsonToken.BEGIN_ARRAY -> {
                reader.beginArray()
                while (reader.hasNext()) validateJson(reader, depth + 1)
                reader.endArray()
            }
            android.util.JsonToken.STRING, android.util.JsonToken.NUMBER -> reader.nextString()
            android.util.JsonToken.BOOLEAN -> reader.nextBoolean()
            android.util.JsonToken.NULL -> reader.nextNull()
            else -> throw Failure("invalid_json")
        }
    }
    private fun jsonMap(json: JSONObject): Map<String, Any?> = json.keys().asSequence().associateWith { key ->
        fun convert(value: Any?): Any? = when (value) {
            JSONObject.NULL -> null
            is JSONObject -> jsonMap(value)
            is org.json.JSONArray -> (0 until value.length()).map { convert(value.get(it)) }
            else -> value
        }
        convert(json.get(key))
    }
    private fun hex(bytes: ByteArray) = bytes.joinToString("") { "%02x".format(it.toInt() and 255) }
    private var p2pRequestPending = false
    private fun releaseChannel() {
        if (p2pOwner === this) p2pOwner = null
        channel?.close()
    }
    private fun removeOwnedGroup() {
        if (p2pRequestPending) return // Late action callback performs this session's cleanup.
        if (owned) {
            owned = false
            try {
                if (state == "joining" && !established) manager?.cancelConnect(channel!!, null)
                manager?.requestGroupInfo(channel!!) { group ->
                    if (group == null || group.networkName != network) releaseChannel()
                    else try {
                        manager.removeGroup(channel!!, object : WifiP2pManager.ActionListener {
                            override fun onSuccess() { releaseChannel() }
                            override fun onFailure(reason: Int) { releaseChannel() }
                        })
                    } catch (_: Exception) { releaseChannel() }
                }
            } catch (_: Exception) { releaseChannel() }
        } else releaseChannel()
    }
    fun close() {
        if (!dead.compareAndSet(false, true)) return
        authenticated = false
        joinRetry?.let { main.removeCallbacks(it) }; joinRetry = null
        deadline?.cancel(true); heartbeat?.cancel(true)
        try { socket?.close() } catch (_: Exception) { }
        try { server?.close() } catch (_: Exception) { }
        writer.shutdownNow(); workers.shutdownNow(); timer.shutdownNow()
        partials.forEach { it.delete() }; partials.clear()
        pendingResults.toList().forEach { it.error("closed") }
        workersCleanupIdentity()
        main.post {
            if (registered) { try { activity.unregisterReceiver(receiver) } catch (_: Exception) { }; registered = false }
            removeOwnedGroup()
            secret.fill(0); password = ""
            sink?.success(mapOf("type" to "closed", "sessionId" to session))
        }
    }
    private fun workersCleanupIdentity() {
        Thread({ synchronized(alias.intern()) {
            try { KeyStore.getInstance("AndroidKeyStore").apply { load(null); deleteEntry(alias) } } catch (_: Exception) { }
        } }, "listenfy-wfd-cleanup").start()
    }
    }
}
