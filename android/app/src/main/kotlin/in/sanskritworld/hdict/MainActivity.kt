package `in`.sanskritworld.hdict

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.net.Uri
import android.content.Intent

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.drdhaval2785.hdict/bookmarks"
    private var pendingResult: MethodChannel.Result? = null
    private val PICK_DIRECTORY_REQUEST_CODE = 1001
    private val PICK_FILES_REQUEST_CODE = 1002

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // Opens the system folder picker. The intent is launched with
                // FLAG_GRANT_PERSISTABLE_URI_PERMISSION so that we can call
                // takePersistableUriPermission in onActivityResult.
                "pickDirectory" -> {
                    pendingResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                        addFlags(
                            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
                        )
                    }
                    startActivityForResult(intent, PICK_DIRECTORY_REQUEST_CODE)
                }
                // Opens the system file picker for multiple files with persistable grants.
                "pickFiles" -> {
                    pendingResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addFlags(
                            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
                        )
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                        putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                    }
                    startActivityForResult(intent, PICK_FILES_REQUEST_CODE)
                }
                // Attempt to take a persistable permission on a URI. This only works if
                // the URI was previously offered with FLAG_GRANT_PERSISTABLE_URI_PERMISSION.
                "takePersistablePermission" -> {
                    val uriString = call.argument<String>("path")
                    if (uriString != null) {
                        try {
                            val uri = Uri.parse(uriString)
                            contentResolver.takePersistableUriPermission(
                                uri,
                                Intent.FLAG_GRANT_READ_URI_PERMISSION
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("PERMISSION_ERROR", e.localizedMessage, null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "Path is required", null)
                    }
                }
                "getFileMetadata" -> {
                    val uriString = call.argument<String>("uri")
                    if (uriString != null) {
                        try {
                            val uri = Uri.parse(uriString)
                            // Querying with null projection returns all available columns
                            val cursor = contentResolver.query(uri, null, null, null, null)
                            cursor?.use {
                                if (it.moveToFirst()) {
                                    // Try OpenableColumns.DISPLAY_NAME (standard)
                                    val nameIndex = it.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                                    val name = if (nameIndex != -1) it.getString(nameIndex) else uri.lastPathSegment ?: "unknown"
                                    
                                    // Try OpenableColumns.SIZE (standard) then fallback to "size"
                                    var sizeIndex = it.getColumnIndex(android.provider.OpenableColumns.SIZE)
                                    if (sizeIndex == -1) {
                                        sizeIndex = it.getColumnIndex("size") // Alternative name used by some providers
                                    }
                                    
                                    val size = if (sizeIndex != -1) it.getLong(sizeIndex) else 0L
                                    
                                    result.success(mapOf("name" to name, "size" to size))
                                } else {
                                    result.error("NOT_FOUND", "File metadata not found", null)
                                }
                            } ?: result.error("QUERY_FAILED", "Failed to query metadata", null)
                        } catch (e: Exception) {
                            result.error("METADATA_ERROR", e.localizedMessage, null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "Uri is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        when (requestCode) {
            PICK_DIRECTORY_REQUEST_CODE -> {
                if (resultCode == RESULT_OK && data?.data != null) {
                    val uri = data.data!!
                    // This succeeds because the intent had FLAG_GRANT_PERSISTABLE_URI_PERMISSION
                    contentResolver.takePersistableUriPermission(
                        uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION
                    )
                    pendingResult?.success(uri.toString())
                } else {
                    pendingResult?.success(null)
                }
                pendingResult = null
            }
            PICK_FILES_REQUEST_CODE -> {
                if (resultCode == RESULT_OK && data != null) {
                    val uris = mutableListOf<String>()
                    val clipData = data.clipData
                    if (clipData != null) {
                        for (i in 0 until clipData.itemCount) {
                            clipData.getItemAt(i).uri?.let { uri ->
                                contentResolver.takePersistableUriPermission(
                                    uri,
                                    Intent.FLAG_GRANT_READ_URI_PERMISSION
                                )
                                uris.add(uri.toString())
                            }
                        }
                    } else if (data.data != null) {
                        val uri = data.data!!
                        contentResolver.takePersistableUriPermission(
                            uri,
                            Intent.FLAG_GRANT_READ_URI_PERMISSION
                        )
                        uris.add(uri.toString())
                    }
                    pendingResult?.success(uris)
                } else {
                    pendingResult?.success(null)
                }
                pendingResult = null
            }
        }
    }
}
