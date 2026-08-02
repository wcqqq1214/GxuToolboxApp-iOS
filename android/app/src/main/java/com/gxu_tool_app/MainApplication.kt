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
            val content = versionFile.readText().trim()
            // 格式: "otaVersionCode|appVersionCode"，旧格式仅有数字
            val parts = content.split("|")
            if (parts.size != 2) {
                // 旧格式或损坏文件，视为失效 OTA，清理标记文件
                versionFile.delete()
                return null
            }
            val otaCode = parts[0]
            val savedAppVersion = parts[1].toIntOrNull() ?: return null
            if (savedAppVersion != BuildConfig.VERSION_CODE) {
                // OTA 属于旧版本 App，不加载
                versionFile.delete()
                return null
            }
            val bundleFile = File(filesDir, "ota/$otaCode/index.android.bundle")
            if (bundleFile.exists()) bundleFile.absolutePath else null
        } catch (e: Exception) {
            null
        }
    }
}
