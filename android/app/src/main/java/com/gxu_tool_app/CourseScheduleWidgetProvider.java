package com.gxu_tool_app;

import android.content.Context;

import com.gxu_tool_app.widget.WidgetRefreshScheduler;
import com.reactnativeandroidwidget.RNWidgetProvider;

public class CourseScheduleWidgetProvider extends RNWidgetProvider {

    @Override
    public void onDisabled(Context context) {
        super.onDisabled(context);
        WidgetRefreshScheduler.cancel(context);
    }
}
