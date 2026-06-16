package com.example.sorta_frontend

import android.media.MediaScannerConnection
import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.atomic.AtomicInteger

class MainActivity : FlutterActivity() {
    private val mediaScannerChannel = "sorta_frontend/media_scanner"
    private val imageExtensions = setOf("jpg", "jpeg", "png", "webp", "heic", "heif")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            mediaScannerChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "scanExternalImageFolders" -> scanExternalImageFolders(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun scanExternalImageFolders(result: MethodChannel.Result) {
        Thread {
            val paths = collectImagePaths()
            if (paths.isEmpty()) {
                runOnUiThread { result.success(null) }
                return@Thread
            }

            val remaining = AtomicInteger(paths.size)
            MediaScannerConnection.scanFile(
                this,
                paths,
                null,
            ) { _, _ ->
                if (remaining.decrementAndGet() == 0) {
                    runOnUiThread { result.success(null) }
                }
            }
        }.start()
    }

    private fun collectImagePaths(): Array<String> {
        val roots = listOf(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM),
        )

        return roots
            .flatMap { root -> imageFilesIn(root) }
            .distinct()
            .toTypedArray()
    }

    private fun imageFilesIn(root: File): List<String> {
        if (!root.exists()) {
            return emptyList()
        }

        return try {
            root.walkTopDown()
                .filter { file ->
                    file.isFile && file.extension.lowercase() in imageExtensions
                }
                .map { file -> file.absolutePath }
                .toList()
        } catch (_: SecurityException) {
            emptyList()
        }
    }
}
