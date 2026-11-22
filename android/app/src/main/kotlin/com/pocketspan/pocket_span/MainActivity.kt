package com.pocketspan.pocket_span

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.pocketspan.pocket_span/export"
        private const val REQUEST_CREATE_DOC = 9101
    }

    private var pendingResult: MethodChannel.Result? = null
    private var pendingContent: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "saveJsonFile") {
                    val fileName = call.argument<String>("fileName") ?: "PocketSpan_backup.json"
                    val content = call.argument<String>("content") ?: ""
                    pendingResult = result
                    pendingContent = content

                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/json"
                        putExtra(Intent.EXTRA_TITLE, fileName)
                    }
                    startActivityForResult(intent, REQUEST_CREATE_DOC)
                } else {
                    result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CREATE_DOC) {
            val res = pendingResult
            val content = pendingContent
            pendingResult = null
            pendingContent = null

            if (res == null) return
            if (resultCode != Activity.RESULT_OK || data?.data == null || content == null) {
                res.success(null)
                return
            }
            try {
                val uri = data.data!!
                contentResolver.openOutputStream(uri)?.use { stream ->
                    stream.write(content.toByteArray(Charsets.UTF_8))
                }
                res.success(uri.toString())
            } catch (e: Exception) {
                res.error("EXPORT_FAILED", e.message, null)
            }
        }
    }
}
