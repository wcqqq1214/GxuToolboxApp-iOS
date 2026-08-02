/**
 * @format
 */

import {AppRegistry} from "react-native";
import App from "./App";
import {name as appName} from "./app.json";
import {widgetTaskHandler} from "@/widget/widget-task-handler";
import {registerWidgetTaskHandler} from "react-native-android-widget";

AppRegistry.registerComponent(appName, () => App);
registerWidgetTaskHandler(widgetTaskHandler);
