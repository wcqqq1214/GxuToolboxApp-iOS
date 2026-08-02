import React, {useRef, useState} from "react";
import {NativeModules, StyleSheet, ToastAndroid, View} from "react-native";
import {RouteProp, useRoute} from "@react-navigation/native";
import {Button, Text, useTheme} from "@rneui/themed";
import WebView from "react-native-webview";
import RNFS from "react-native-fs";

const {OpenWithModule} = NativeModules;

const SCHEDULE_TABS = [
    {key: "personal", label: "个人课表", url: "https://jwxt2018.gxu.edu.cn/jwglxt/kbcx/xskbcx_cxXskbcxIndex.html?gnmkdm=N2151&layout=default"},
    {key: "class", label: "班级课表", url: "https://jwxt2018.gxu.edu.cn/jwglxt/kbdy/bjkbdy_cxBjkbdyIndex.html?gnmkdm=N214505&layout=default"},
] as const;

// 获取页面 HTML 的 JS 代码
const GET_HTML_JS = `
(function() {
  var html = document.documentElement.outerHTML;
  window.ReactNativeWebView.postMessage(html);
})();
true;
`;

type TabKey = "personal" | "class";

export function ExportScheduleScreen() {
    const {theme} = useTheme();
    const route = useRoute<RouteProp<{ExportScheduleScreen: {tab?: TabKey}}, "ExportScheduleScreen">>();
    const webViewRef = useRef<any>(null);
    const [activeTab, setActiveTab] = useState<TabKey>(route.params?.tab ?? "personal");
    const [webViewLoaded, setWebViewLoaded] = useState(false);
    const [exporting, setExporting] = useState(false);

    const handleExport = async () => {
        if (!webViewRef.current || exporting) return;

        setExporting(true);
        try {
            webViewRef.current.injectJavaScript(GET_HTML_JS);
        } catch (e) {
            setExporting(false);
            ToastAndroid.show("获取页面失败", ToastAndroid.SHORT);
        }
    };

    const handleMessage = async (event: {nativeEvent: {data: string}}) => {
        const html = event.nativeEvent.data;
        ToastAndroid.show(`已获取页面 HTML（${html.length} 字符）`, ToastAndroid.SHORT);

        const filePath = `${RNFS.CachesDirectoryPath}/export_schedule.html`;
        try {
            await RNFS.writeFile(filePath, html, "utf8");
            await OpenWithModule.openFile(filePath);
        } catch (e) {
            console.log("[ExportSchedule] error:", e);
            ToastAndroid.show("打开失败: " + String(e), ToastAndroid.LONG);
        } finally {
            setExporting(false);
        }
    };

    const currentUrl = SCHEDULE_TABS.find(t => t.key === activeTab)!.url;

    return (
        <View style={styles.container}>
            <View style={styles.tabBar}>
                {SCHEDULE_TABS.map(tab => (
                    <View
                        key={tab.key}
                        style={[
                            styles.tabItem,
                            activeTab === tab.key && {borderBottomColor: theme.colors.primary, borderBottomWidth: 2},
                        ]}>
                        <Text
                            onPress={() => {
                                setActiveTab(tab.key);
                                setWebViewLoaded(false);
                            }}
                            style={[
                                styles.tabText,
                                {color: activeTab === tab.key ? theme.colors.primary : theme.colors.grey3},
                            ]}>
                            {tab.label}
                        </Text>
                    </View>
                ))}
            </View>
            <WebView
                key={activeTab}
                ref={webViewRef}
                source={{uri: currentUrl}}
                onMessage={handleMessage}
                onLoadEnd={() => setWebViewLoaded(true)}
                startInLoadingState={true}
                javaScriptEnabled={true}
                domStorageEnabled={true}
                style={styles.webView}
            />
            <View style={[styles.bottomBar, {backgroundColor: theme.colors.background}]}>
                <Button
                    title={exporting ? "正在导出..." : "导出课表"}
                    onPress={handleExport}
                    disabled={!webViewLoaded || exporting}
                    containerStyle={styles.buttonContainer}
                />
            </View>
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
    },
    tabBar: {
        flexDirection: "row",
        borderBottomWidth: StyleSheet.hairlineWidth,
        borderBottomColor: "#ccc",
    },
    tabItem: {
        flex: 1,
        paddingVertical: 12,
        alignItems: "center",
    },
    tabText: {
        fontSize: 15,
        fontWeight: "600",
    },
    webView: {
        flex: 1,
    },
    bottomBar: {
        padding: 12,
        paddingBottom: 24,
    },
    buttonContainer: {
        width: "100%",
    },
});
