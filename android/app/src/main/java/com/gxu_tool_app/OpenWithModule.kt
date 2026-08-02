package com.gxu_tool_app

import android.content.Intent
import androidx.core.content.FileProvider
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.Promise
import java.io.File

class OpenWithModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    override fun getName(): String = "OpenWithModule"

    @ReactMethod
    fun openFile(filePath: String, promise: Promise) {
        try {
            val file = File(filePath)
            val context = reactApplicationContext
            val authority = "${context.packageName}.provider"
            val contentUri = FileProvider.getUriForFile(context, authority, file)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(contentUri, "*/*")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            val chooser = Intent.createChooser(intent, "用其他应用打开")
            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(chooser)
            promise.resolve(true)
        } catch (e: Exception) {
            promise.reject("OPEN_ERROR", e.message, e)
        }
    }
}
