/**
 * @format
 */

import {AppRegistry} from "react-native";
import App from "./App";
import {name as appName} from "./app.json";
import {widgetTaskHandler} from "@/features/widget/widgetTaskHandler";
import {registerCourseScheduleWidgetUpdates} from "@/features/widget/widgetUpdater";
import {registerWidgetTaskHandler} from "react-native-android-widget";

AppRegistry.registerComponent(appName, () => App);
registerWidgetTaskHandler(widgetTaskHandler);
registerCourseScheduleWidgetUpdates();
