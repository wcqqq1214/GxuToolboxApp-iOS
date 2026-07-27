import {useState} from "react";
import {Alert, Linking} from "react-native";
import ReactNativeBlobUtil from "react-native-blob-util";
import Clipboard from "@react-native-clipboard/clipboard";

export function useDownloadApk() {
    const [downloading, setDownloading] = useState(false);
    const [progress, setProgress] = useState(0);

    const download = async (url: string) => {
        setDownloading(true);
        setProgress(0);
        try {
            const res = await ReactNativeBlobUtil.config({
                fileCache: true,
                path: `${ReactNativeBlobUtil.fs.dirs.CacheDir}/gxu_tool_update.apk`,
            })
                .fetch("GET", url)
                .progress((received, total) => {
                    setProgress(Number(received) / Number(total));
                });

            await ReactNativeBlobUtil.android.actionViewIntent(res.path(), "application/vnd.android.package-archive");
        } catch (error) {
            console.error("应用内下载失败，尝试打开浏览器:", error);
            try {
                await Linking.openURL(url);
            } catch {
                console.error("打开浏览器也失败了");
                Alert.alert("下载失败", `无法自动下载，请手动复制链接到浏览器打开：\n${url}`, [
                    {text: "复制链接", onPress: () => Clipboard.setString(url)},
                    {text: "确定"},
                ]);
            }
        } finally {
            setDownloading(false);
            setProgress(0);
        }
    };

    return {downloading, progress, download};
}
