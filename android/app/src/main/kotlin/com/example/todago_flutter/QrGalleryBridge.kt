package com.example.todago_flutter

import android.Manifest
import android.app.Activity
import android.content.ContentValues
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

/** Saves only the verified, user-requested QR image in the phone's Photos. */
class QrGalleryBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private data class Download(val bytes: ByteArray, val name: String, val result: MethodChannel.Result)
    private var pending: Download? = null
    private val permissionRequest = 4427

    init {
        MethodChannel(messenger, "todago/qr_gallery").setMethodCallHandler { call, result ->
            if (call.method != "saveQr") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val bytes = call.argument<ByteArray>("bytes")
            val name = call.argument<String>("fileName")
            if (bytes == null || bytes.size !in 4..2000000 || name == null ||
                !Regex("^TodaGo-qr_[a-z0-9]{24}\\.jpg$").matches(name)) {
                result.error("INVALID_IMAGE", "A valid QR image is required", null)
                return@setMethodCallHandler
            }
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0 || bounds.outMimeType != "image/jpeg" ||
                bounds.outWidth.toLong() * bounds.outHeight > 12000000) {
                result.error("INVALID_IMAGE", "The QR image could not be read", null)
                return@setMethodCallHandler
            }
            val download = Download(bytes, name, result)
            if (Build.VERSION.SDK_INT in 23..28 && activity.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                if (pending != null) {
                    result.error("BUSY", "A download is already in progress", null)
                } else {
                    pending = download
                    activity.requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), permissionRequest)
                }
            } else save(download)
        }
    }

    fun onPermissionResult(requestCode: Int, grants: IntArray) {
        if (requestCode != permissionRequest) return
        val download = pending ?: return
        pending = null
        if (grants.firstOrNull() == PackageManager.PERMISSION_GRANTED) save(download)
        else download.result.error("PERMISSION_DENIED", "Allow saving the QR to Photos", null)
    }

    private fun save(download: Download) {
        Thread({
            try {
                if (Build.VERSION.SDK_INT >= 29) {
                    val values = ContentValues().apply {
                        put(MediaStore.Images.Media.DISPLAY_NAME, download.name)
                        put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                        put(MediaStore.Images.Media.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/TodaGo")
                        put(MediaStore.Images.Media.IS_PENDING, 1)
                    }
                    val resolver = activity.contentResolver
                    val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                        ?: throw IOException("Photos is unavailable")
                    try {
                        val stream = resolver.openOutputStream(uri) ?: throw IOException("Photos could not be written")
                        stream.use { it.write(download.bytes) }
                        values.clear()
                        values.put(MediaStore.Images.Media.IS_PENDING, 0)
                        resolver.update(uri, values, null, null)
                    } catch (cause: Exception) {
                        resolver.delete(uri, null, null)
                        throw cause
                    }
                    activity.runOnUiThread { download.result.success(uri.toString()) }
                } else {
                    @Suppress("DEPRECATION")
                    val folder = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), "TodaGo")
                    if (!folder.exists() && !folder.mkdirs()) throw IOException("Photos is unavailable")
                    val file = File(folder, download.name.removeSuffix(".jpg") + "-${System.currentTimeMillis()}.jpg")
                    try { file.outputStream().use { it.write(download.bytes) } }
                    catch (cause: Exception) { file.delete(); throw cause }
                    MediaScannerConnection.scanFile(activity, arrayOf(file.absolutePath), arrayOf("image/jpeg")) { _, uri ->
                        activity.runOnUiThread { download.result.success(uri?.toString() ?: file.absolutePath) }
                    }
                }
            } catch (_: Exception) {
                activity.runOnUiThread { download.result.error("SAVE_FAILED", "The QR could not be saved to Photos", null) }
            }
        }, "todago-qr-download").start()
    }
}
