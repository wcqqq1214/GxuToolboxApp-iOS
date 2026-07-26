package com.gxu_tool_app

import android.app.Application
import com.facebook.react.PackageList
import com.facebook.react.ReactApplication
import com.facebook.react.ReactHost
import com.facebook.react.ReactNativeApplicationEntryPoint.loadReactNative
import com.facebook.react.defaults.DefaultReactHost.getDefaultReactHost
import java.io.File

class MainApplication : Application(), ReactApplication {

    override val reactHost: ReactHost by lazy {
        getDefaultReactHost(
            context = applicationContext,
            packageList =
                PackageList(this).packages.apply {
                    add(OpenWithPackage())
                },
            jsBundleFilePath = getOTABundlePath(),
        )
    }

    override fun onCreate() {
        super.onCreate()
        loadReactNative(this)
    }

    private fun getOTABundlePath(): String? {
        return try {
            val versionFile = File(filesDir, "ota_version")
            if (!versionFile.exists()) return null
            val versionCode = versionFile.readText().trim()
            val bundleFile = File(filesDir, "ota/$versionCode/index.android.bundle")
            if (bundleFile.exists()) bundleFile.absolutePath else null
        } catch (e: Exception) {
            null
        }
    }
}
