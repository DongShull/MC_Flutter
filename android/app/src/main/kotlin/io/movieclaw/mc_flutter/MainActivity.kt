package io.movieclaw.mc_flutter

import android.app.Activity
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import org.json.JSONObject

/// 原生下载通道 mc/native/download（契约 = lib/core/platform/download_channel.dart）：
/// probeDownload / getDownloadDirectory / startDownload / pauseDownload / cancelDownload
/// / capacity / delete；每任务进度流 EventChannel 'mc/native/download/progress/<id>'，
/// 事件字段 received / totalBytes / done / error。
/// 续传语义对齐 Dart 保底实现：<savePath>.part + .part.meta（url/received/totalBytes）。
class McDownloadPlugin(private val activity: Activity, private val messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {
    private val pool = Executors.newFixedThreadPool(2)
    private val sinks = ConcurrentHashMap<String, EventChannel.EventSink>()
    private val cancelled = ConcurrentHashMap<String, Boolean>()
    private val paused = ConcurrentHashMap<String, Boolean>()
    private val conns = ConcurrentHashMap<String, HttpURLConnection>()
    private val registeredStreams = ConcurrentHashMap<String, EventChannel>()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "probeDownload" -> result.success("ok")
            "getDownloadDirectory" -> result.success(
                activity.getExternalFilesDir(null)?.absolutePath ?: activity.filesDir.absolutePath)
            "startDownload" -> {
                val id = call.argument<String>("id") ?: return result.error("bad_args", "id required", null)
                val url = call.argument<String>("url") ?: return result.error("bad_args", "url required", null)
                val savePath = call.argument<String>("savePath") ?: return result.error("bad_args", "savePath required", null)
                val headers = call.argument<Map<String, String>>("headers") ?: emptyMap()
                cancelled[id] = false
                paused[id] = false
                ensureStream(id)
                pool.execute { runTask(id, url, savePath, headers) }
                result.success(null)
            }
            "pauseDownload" -> {
                paused[call.argument<String>("id") ?: ""] = true
                result.success(null)
            }
            "cancelDownload" -> {
                val id = call.argument<String>("id") ?: ""
                cancelled[id] = true
                conns[id]?.disconnect()
                result.success(null)
            }
            "capacity" -> {
                val dir = activity.getExternalFilesDir(null) ?: activity.filesDir
                val stat = StatFs(dir.absolutePath)
                result.success(mapOf("freeBytes" to stat.availableBytes, "totalBytes" to stat.totalBytes))
            }
            "delete" -> {
                val path = call.argument<String>("path") ?: ""
                if (path.isBlank()) return result.success(false)
                val f = File(path)
                // 防御：只允许删应用私有目录内的文件。
                val root = activity.getExternalFilesDir(null)?.absolutePath ?: activity.filesDir.absolutePath
                result.success(f.exists() && f.absolutePath.startsWith(root) && f.delete())
            }
            else -> result.notImplemented()
        }
    }

    /// Dart 侧 EventChannel('mc/native/download/progress/<id>') 订阅前原生必须已注册同名通道，
    /// 因此在 startDownload 时即时注册（start 先于 progress 订阅是 Dart 侧的固定次序）。
    private fun ensureStream(id: String) {
        if (registeredStreams.containsKey(id)) return
        val ec = EventChannel(messenger, "mc/native/download/progress/$id")
        ec.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, events: EventChannel.EventSink?) {
                if (events != null) sinks[id] = events
            }
            override fun onCancel(args: Any?) { sinks.remove(id) }
        })
        registeredStreams[id] = ec
    }

    private fun emit(id: String, map: Map<String, Any?>) {
        activity.runOnUiThread {
            sinks[id]?.success(map)
        }
    }

    private fun runTask(id: String, url: String, savePath: String, headers: Map<String, String>) {
        val save = File(savePath)
        save.parentFile?.mkdirs()
        val part = File("$savePath.part")
        val meta = File("$part.meta")
        var received = 0L
        var total: Long? = null
        try {
            if (part.exists() && meta.exists()) {
                try {
                    val m = JSONObject(meta.readText())
                    if (m.optString("url") == url) {
                        received = m.optLong("received", 0L)
                        if (m.has("totalBytes") && !m.isNull("totalBytes")) total = m.getLong("totalBytes")
                    }
                } catch (_: Exception) { received = 0 }
            }
            if (received > 0L && (!part.exists() || part.length() < received)) {
                received = 0; total = null
            }
            val conn = URL(url).openConnection() as HttpURLConnection
            conns[id] = conn
            conn.connectTimeout = 15000
            conn.readTimeout = 30000
            for ((k, v) in headers) conn.setRequestProperty(k, v)
            if (received > 0L) conn.setRequestProperty("Range", "bytes=$received-")
            val code = conn.responseCode
            if (received > 0L && code != 206) { received = 0; total = null }
            if (code >= 400) throw java.io.IOException("HTTP $code for $url")
            val len = conn.contentLengthLong
            if (received == 0L && len > 0L) total = len else if (total == null && len > 0L) total = received + len

            FileOutputStream(part, received > 0L).use { out ->
                conn.inputStream.use { input ->
                    val buf = ByteArray(64 * 1024)
                    while (true) {
                        if (cancelled[id] == true || paused[id] == true) break
                        val n = input.read(buf)
                        if (n <= 0) break
                        out.write(buf, 0, n)
                        received += n
                        emit(id, mapOf("received" to received, "totalBytes" to total,
                            "done" to false, "error" to null))
                    }
                }
            }
            conns.remove(id)
            when {
                cancelled[id] == true -> {
                    part.delete(); meta.delete()
                    emit(id, mapOf("received" to 0, "totalBytes" to null,
                        "done" to true, "error" to "Download was cancelled"))
                }
                paused[id] == true -> writeMeta(meta, url, received, total)
                else -> {
                    meta.delete()
                    if (save.exists()) save.delete()
                    part.renameTo(save)
                    emit(id, mapOf("received" to received, "totalBytes" to (total ?: received),
                        "done" to true, "error" to null))
                }
            }
        } catch (e: Exception) {
            conns.remove(id)
            if (cancelled[id] == true) {
                part.delete(); meta.delete()
                emit(id, mapOf("received" to 0, "totalBytes" to null,
                    "done" to true, "error" to "Download was cancelled"))
            } else {
                if (received > 0L) writeMeta(meta, url, received, total)
                emit(id, mapOf("received" to received, "totalBytes" to total,
                    "done" to false, "error" to (e.message ?: e.toString())))
            }
        } finally {
            sinks.remove(id)
            paused.remove(id)
            cancelled.remove(id)
        }
    }

    private fun writeMeta(meta: File, url: String, received: Long, total: Long?) {
        try {
            val o = JSONObject().put("url", url).put("received", received)
            if (total != null) o.put("totalBytes", total) else o.put("totalBytes", JSONObject.NULL)
            meta.writeText(o.toString())
        } catch (_: Exception) {}
    }

    companion object {
        const val CHANNEL = "mc/native/download"
    }
}

/// MainActivity：注册下载通道。
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val msgr = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(msgr, McDownloadPlugin.CHANNEL)
            .setMethodCallHandler(McDownloadPlugin(this, msgr))
    }
}
