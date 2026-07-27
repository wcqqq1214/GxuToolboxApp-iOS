import {useCallback, useEffect, useMemo, useState} from "react";
import {ActivityIndicator, FlatList, StyleSheet, View} from "react-native";
import {Button, LinearProgress, Text, useTheme} from "@rneui/themed";
import axios from "axios";
import {Color} from "@/shared/color.ts";
import PackageJSON from "@/../package.json";
import {useUserConfig} from "@/hooks/useUserConfig.ts";
import {useDownloadApk} from "@/hooks/useDownloadApk";
import {UnCard, UnPressable} from "@/components/un-ui";
import {ChannelList, Version, VersionRes} from "@/components/UpdateCard";

const CHANNEL_LABELS: Record<ChannelList, string> = {
    [ChannelList.beta]: "Beta 渠道",
    [ChannelList.release]: "Release 渠道",
};

function VersionCard({version}: {version: Version}) {
    const {downloading, progress, download} = useDownloadApk();
    const {theme} = useTheme();
    const {store} = useUserConfig();

    const style = StyleSheet.create({
        card: {
            backgroundColor: Color(theme.colors.background)
                .setAlpha(
                    0.05 + ((theme.mode === "dark" ? 0.6 : 0.7) * store(s => s.theme.bgOpacity)) / 100,
                ).rgbaString,
            borderColor: Color.mix(theme.colors.primary, theme.colors.background, 0.7).rgbaString,
            borderRadius: 5,
            marginHorizontal: 5,
            marginBottom: 10,
            elevation: 0,
            shadowOpacity: 0,
            overflow: "hidden",
        },
        content: {
            paddingHorizontal: "2%",
        },
        descText: {
            fontSize: 14,
            marginBottom: 10,
        },
    });

    return (
        <UnCard style={style.card} title={`${version.versionName} (${version.versionCode})`}>
            <View style={style.content}>
                <Text style={style.descText}>{version.desc}</Text>
                {downloading && (
                    <LinearProgress
                        value={progress}
                        variant="determinate"
                        color={theme.colors.primary}
                        style={{height: 6, borderRadius: 3, marginBottom: 8}}
                    />
                )}
                <Button
                    size="sm"
                    loading={downloading}
                    disabled={downloading}
                    onPress={() => download(version.ori.official!)}>
                    {downloading ? `下载中 ${(progress * 100).toFixed(1)}%` : "下载"}
                </Button>
            </View>
        </UnCard>
    );
}

export function VersionListScreen() {
    const {theme} = useTheme();
    const {store} = useUserConfig();
    const [allData, setAllData] = useState<VersionRes | null>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    const isBeta = PackageJSON.version.indexOf("beta") > -1;
    const [tab, setTab] = useState<ChannelList>(
        isBeta ? ChannelList.beta : ChannelList.release,
    );

    const fetchVersions = useCallback(async () => {
        setLoading(true);
        setError(null);
        try {
            const {data} = await axios.get<VersionRes>(
                `${PackageJSON.versionJsonUrl}?_=${Date.now()}`,
            );
            setAllData(data);
            if (!isBeta || (data.release?.length && !data.beta?.length)) {
                setTab(ChannelList.release);
            }
        } catch (e) {
            console.error("获取版本信息失败:", e);
            setError("获取版本信息失败");
        } finally {
            setLoading(false);
        }
    }, [isBeta]);

    useEffect(() => {
        fetchVersions();
    }, [fetchVersions]);

    const versions = useMemo(() => allData?.[tab] ?? [], [allData, tab]);

    const bgOpacity = store(s => s.theme.bgOpacity);
    const tabBgColor = Color(theme.colors.background)
        .setAlpha(((theme.mode === "dark" ? 0.7 : 0.9) * bgOpacity) / 100)
        .rgbaString;

    const style = StyleSheet.create({
        tabBar: {
            flexDirection: "row",
            marginHorizontal: 12,
            marginTop: 8,
            marginBottom: 4,
            borderRadius: 6,
            overflow: "hidden",
        },
        tab: {
            flex: 1,
            paddingVertical: 10,
            alignItems: "center",
            justifyContent: "center",
        },
        tabActive: {
            backgroundColor: theme.colors.primary,
        },
        tabInactive: {
            backgroundColor: tabBgColor,
        },
        tabText: {
            fontSize: 14,
            fontWeight: "600",
        },
        centerContainer: {
            flex: 1,
            justifyContent: "center",
            alignItems: "center",
            paddingTop: 100,
        },
        emptyText: {
            padding: 30,
            textAlign: "center",
            color: theme.colors.grey3,
            fontSize: 15,
        },
    });

    if (loading) {
        return (
            <View style={style.centerContainer}>
                <ActivityIndicator size="large" color={theme.colors.primary} />
                <Text style={{marginTop: 12, color: theme.colors.grey3}}>加载中...</Text>
            </View>
        );
    }

    if (error) {
        return (
            <View style={style.centerContainer}>
                <Text style={{marginBottom: 16, color: theme.colors.error}}>{error}</Text>
                <Button onPress={fetchVersions}>重试</Button>
            </View>
        );
    }

    return (
        <FlatList
            data={versions}
            keyExtractor={(item, index) => `${item.versionCode}-${index}`}
            contentContainerStyle={{padding: 12}}
            renderItem={({item}) => <VersionCard version={item} />}
            ListHeaderComponent={
                isBeta ? (
                    <View style={style.tabBar}>
                        {[ChannelList.beta, ChannelList.release].map(channel => (
                            <UnPressable
                                key={channel}
                                onPress={() => setTab(channel)}
                                style={[
                                    style.tab,
                                    tab === channel ? style.tabActive : style.tabInactive,
                                ]}>
                                <Text
                                    style={[
                                        style.tabText,
                                        {color: tab === channel ? "#fff" : theme.colors.grey3},
                                    ]}>
                                    {CHANNEL_LABELS[channel]}
                                </Text>
                            </UnPressable>
                        ))}
                    </View>
                ) : null
            }
            ListEmptyComponent={<Text style={style.emptyText}>暂无版本</Text>}
        />
    );
}
