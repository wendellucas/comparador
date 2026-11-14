package com.comparadorhash.comparador_hash

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Activity principal responsável por expor o seletor nativo do Android (SAF)
 * via MethodChannel, permitindo escolher 1 ou vários arquivos de qualquer tipo
 * tanto no modo celular quanto em janelas do Samsung DeX.
 */
class MainActivity : FlutterActivity() {
    companion object {
        private const val FILE_PICKER_CHANNEL = "com.comparadorhash/file_picker"
        private const val REQUEST_PICK_FILES = 4102
    }

    private var pendingPickerResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILE_PICKER_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "pickFiles") {
                    openDocumentPicker(result)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun openDocumentPicker(result: MethodChannel.Result) {
        if (pendingPickerResult != null) {
            result.error("PICKER_BUSY", "Já existe uma seleção de arquivos em andamento.", null)
            return
        }

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        pendingPickerResult = result
        @Suppress("DEPRECATION")
        startActivityForResult(intent, REQUEST_PICK_FILES)
    }

    @Deprecated("Necessário para compatibilidade direta com FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_PICK_FILES) {
            val result = pendingPickerResult ?: return
            pendingPickerResult = null

            if (resultCode != Activity.RESULT_OK || data == null) {
                result.success(emptyList<String>())
                return
            }

            val uris = mutableListOf<String>()
            val clipData = data.clipData
            if (clipData != null) {
                for (index in 0 until clipData.itemCount) {
                    val uri = clipData.getItemAt(index).uri
                    tryGrantPersistableRead(uri)
                    uris.add(uri.toString())
                }
            } else {
                data.data?.let { uri ->
                    tryGrantPersistableRead(uri)
                    uris.add(uri.toString())
                }
            }

            result.success(uris)
            return
        }

        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun tryGrantPersistableRead(uri: android.net.Uri) {
        // Nem todos os provedores virtuais permitem permissão persistente; ignoramos com segurança se recusarem.
        runCatching {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
        }
    }
}
