import {useEffect, useState} from "react";
import {Button, LinearProgress, Text, useTheme} from "@rneui/themed";
import axios from "axios";
import {StyleSheet} from "react-native";
import Flex from "./un-ui/Flex";
import {Color} from "@/shared/color.ts";
import PackageJSON from "@/../package.json";
import {useUserConfig} from "@/hooks/useUserConfig.ts";
import {useDownloadApk} from "@/hooks/useDownloadApk.ts";
import {UnCard} from "@/components/un-ui";

export enum ChannelList {
    beta = "beta",
    release = "release",
}

export type VersionRes = {
    [c in ChannelList]: Version[];
};

export interface OtaItem {
    versionName: string;
    versionCode: number;
    desc: string;
    bundleUrl: string;
}

export interface Version {
    versionName: string;
    versionCode: number;
    desc: string;
    dependency: string;
    ori: Record<string, string>;
    ota?: OtaItem[];
}

export function UpdateCard() {
    const {theme} = useTheme();
    const {store} = useUserConfig();
    const [channel, setChannel] = useState<ChannelList>(
        PackageJSON.version.indexOf("beta") > -1 ? ChannelList.beta : ChannelList.release,
    );
    const [version, setVersion] = useState<Version>();
    const [visible, setVisible] = useState(false);
    useEffect(() => {
        init();
    }, []);

    const style = StyleSheet.create({
        card: {
            backgroundColor: Color(theme.colors.background).setAlpha(
                0.05 + ((theme.mode === "dark" ? 0.6 : 0.7) * store(s => s.theme.bgOpacity)) / 100,
            ).rgbaString,
            borderColor: Color.mix(theme.colors.primary, theme.colors.background, 0.7).rgbaString,
            borderRadius: 5,
            paddingHorizontal: 0,
            marginHorizontal: 5,
            elevation: 0, // Android 去除阴影
            shadowOpacity: 0, // iOS 去除阴影
            overflow: "hidden",
        },
    });

    async function init() {
        const {data} = await axios.get<VersionRes>(`${PackageJSON.versionJsonUrl}?_=${Date.now()}`);
        const newVersion = data[channel].find(version => version.versionCode > PackageJSON.versionCode);
        if (newVersion) {
            setVisible(true);
            setVersion(newVersion);
        }
    }

    const {downloading, progress, download: handleUpdate} = useDownloadApk();

    return visible ? (
        <UnCard style={style.card} title="发现新版本~">
            <Flex direction="column" gap={10} align="flex-start" inline style={{paddingHorizontal: "2%"}}>
                {/*<Text>可以在设置关闭更新提示</Text>*/}
                <Text style={{fontSize: 14}}>
                    版本号：{version?.versionName}（{version?.versionCode}）
                </Text>
                <Text style={{fontSize: 14}}>更新信息：</Text>
                <Text style={{fontSize: 14}}>{version?.desc}</Text>
                {downloading && (
                    <LinearProgress
                        value={progress}
                        variant="determinate"
                        color={theme.colors.primary}
                        style={{height: 6, borderRadius: 3, width: "100%"}}
                    />
                )}
                <Flex gap={10} justify="flex-end" style={{width: "100%"}}>
                    <Button
                        size="sm"
                        loading={downloading}
                        disabled={downloading}
                        onPress={() => handleUpdate(version?.ori.official!)}>
                        {downloading ? `下载中 ${(progress * 100).toFixed(1)}%` : "获取更新"}
                    </Button>
                </Flex>
            </Flex>
        </UnCard>
    ) : (
        <></>
    );
}
