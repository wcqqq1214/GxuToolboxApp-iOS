package com.gxu_tool_app.widget

import com.facebook.react.ReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.uimanager.ViewManager

class WidgetRefreshModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    override fun getName(): String = "WidgetRefreshScheduler"

    @ReactMethod
    fun schedule(triggerAtMillis: Double) {
        WidgetRefreshScheduler.schedule(reactApplicationContext, triggerAtMillis.toLong())
    }

    @ReactMethod
    fun cancel() {
        WidgetRefreshScheduler.cancel(reactApplicationContext)
    }
}

@Suppress("DEPRECATION")
class WidgetRefreshPackage : ReactPackage {
    override fun createNativeModules(reactContext: ReactApplicationContext): List<NativeModule> =
        listOf(WidgetRefreshModule(reactContext))

    override fun createViewManagers(reactContext: ReactApplicationContext): List<ViewManager<*, *>> =
        emptyList()
}
