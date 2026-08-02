package com.gxu_tool_app

import com.facebook.react.ReactActivity
import com.facebook.react.ReactActivityDelegate
import com.facebook.react.defaults.DefaultNewArchitectureEntryPoint.fabricEnabled
import android.os.Bundle
import com.facebook.react.defaults.DefaultReactActivityDelegate

class MainActivity : ReactActivity() {

  override fun onCreate(savedInstanceState: Bundle?) {
    // react-native-screens 不支持 Fragment 恢复，需要在 super.onCreate 之前清除 fragment 状态
    val stripped = savedInstanceState?.apply {
      remove("android:support:fragments")
      remove("androidx.lifecycle.BundlableSavedStateRegistry.key")
    }
    super.onCreate(stripped)
  }

  /**
   * Returns the name of the main component registered from JavaScript. This is used to schedule
   * rendering of the component.
   */
  override fun getMainComponentName(): String = "gxu_tool_app"

    /**
     * Returns the instance of the [ReactActivityDelegate]. We use [DefaultReactActivityDelegate]
     * which allows you to enable New Architecture with a single boolean flags [fabricEnabled]
     */
    override fun createReactActivityDelegate(): ReactActivityDelegate =
        DefaultReactActivityDelegate(this, mainComponentName, fabricEnabled)
}
