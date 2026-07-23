import {ActivityIndicator, View} from "react-native";
import {useEffect, useState} from "react";
import WebView from "react-native-webview";
import {useTheme} from "@rneui/themed";
import {oaApi} from "@/features/documents/api/oaApi.ts";
import {UnText} from "@/components/un-ui";

/**
 * 当前 WebView 用的是新OA返回的 HTML ，文件的 id 好像是相同的，旧系统的接口也能渲染文件（接口在"@/js/wjxt/api.ts"）
 * @param route 参数为文件 id
 * @constructor
 **/

// @ts-ignore
export function FileScreen({route}) {
    const {fileId} = route.params;
    const {theme} = useTheme();
    const [html, setHtml] = useState<string | null>(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        oaApi.getFileDetail(fileId).then(res => {
            if (res?.code === 200) {
                const body = res.result.fileBody;
                if (body) {
                    setHtml(body);
                }
            }
            setLoading(false);
        });
    }, [fileId]);

    if (loading) {
        return (
            <View style={{flex: 1, justifyContent: "center", alignItems: "center"}}>
                <ActivityIndicator size="large" color={theme.colors.primary} />
            </View>
        );
    }

    if (!html) {
        return (
            <View style={{flex: 1, justifyContent: "center", alignItems: "center"}}>
                <UnText size={16} color={theme.colors.grey3}>
                    暂无内容
                </UnText>
            </View>
        );
    }

    return (
        <View style={{flex: 1}}>
            <WebView
                source={{html}}
                originWhitelist={["*"]}
            />
        </View>
    );
}
