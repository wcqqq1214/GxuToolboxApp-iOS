import {useCallback, useEffect, useMemo, useState} from "react";
import {ActivityIndicator, FlatList, StyleSheet, Text, View} from "react-native";
import {Button, useTheme} from "@rneui/themed";
import axios from "axios";

import {UnCard, UnPressable} from "@/components/un-ui";
import {Color} from "@/shared/color.ts";
import {useUserConfig} from "@/hooks/useUserConfig.ts";
import PackageJSON from "@/../package.json";
import {ChannelList, VersionRes, Version, OtaItem} from "@/components/UpdateCard";
import {getCurrentOTAVersionCode} from "@/core/ota";

const CHANNEL_LABELS: Record<ChannelList, string> = {
    [ChannelList.beta]: "Beta 渠道",
    [ChannelList.release]: "Release 渠道",
};

function OtaCard({ota, isCurrent}: {ota: OtaItem; isCurrent: boolean}) {
    const {theme} = useTheme();
    const {store} = useUserConfig();
    const bgOpacity = store(s => s.theme.bgOpacity);

    const styles = StyleSheet.create({
        card: {
            backgroundColor: Color(theme.colors.background)
                .setAlpha(
                    0.05 + ((theme.mode === "dark" ? 0.6 : 0.7) * bgOpacity) / 100,
                )
                .rgbaString,
            borderColor: Color.mix(theme.colors.primary, theme.colors.background, 0.7).rgbaString,
            borderRadius: 5,
            marginHorizontal: 5,
            marginVertical: 4,
            elevation: 0,
            shadowOpacity: 0,
            overflow: "hidden",
        },
        headerRow: {
            flexDirection: "row",
            justifyContent: "space-between",
            alignItems: "center",
            marginBottom: 4,
        },
        versionText: {
            fontWeight: "bold",
            fontSize: 14,
            color: Color.mix(theme.colors.primary, theme.colors.black, 0.4).rgbaString,
        },
        badge: {
            backgroundColor: theme.colors.primary,
            paddingHorizontal: 6,
            paddingVertical: 2,
            borderRadius: 4,
        },
        badgeText: {
            color: "#ffffff",
            fontSize: 11,
        },
        descText: {
            fontSize: 13,
            color: theme.colors.grey3,
        },
    });

    return (
        <UnCard style={styles.card}>
            <View style={styles.headerRow}>
                <Text style={styles.versionText}>
                    {ota.versionName} ({ota.versionCode})
                </Text>
                {isCurrent && (
                    <View style={styles.badge}>
                        <Text style={styles.badgeText}>当前版本</Text>
                    </View>
                )}
            </View>
            <Text style={styles.descText}>{ota.desc}</Text>
        </UnCard>
    );
}

interface OtaEntry {
    ota: OtaItem;
    versionName: string;
}

export function OTAListScreen() {
    const {theme} = useTheme();
    const {store} = useUserConfig();
    const bgOpacity = store(s => s.theme.bgOpacity);

    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [allEntries, setAllEntries] = useState<Record<ChannelList, OtaEntry[]>>({
        [ChannelList.beta]: [],
        [ChannelList.release]: [],
    });
    const [currentVersionCode] = useState(() => getCurrentOTAVersionCode());

    const isBeta = PackageJSON.version.indexOf("beta") > -1;
    const [tab, setTab] = useState<ChannelList>(
        isBeta ? ChannelList.beta : ChannelList.release,
    );

    const fetchData = useCallback(async () => {
        setLoading(true);
        setError(null);
        try {
            const {data} = await axios.get<VersionRes>(`${PackageJSON.versionJsonUrl}?_=${Date.now()}`);

            const entries: Record<ChannelList, OtaEntry[]> = {
                [ChannelList.beta]: [],
                [ChannelList.release]: [],
            };

            for (const channel of [ChannelList.beta, ChannelList.release]) {
                const versions: Version[] = data[channel] ?? [];
                for (const version of versions) {
                    if (version.ota && version.ota.length > 0) {
                        for (const ota of version.ota) {
                            entries[channel].push({ota, versionName: version.versionName});
                        }
                    }
                }
            }

            setAllEntries(entries);
            if (!isBeta || (entries[ChannelList.release].length && !entries[ChannelList.beta].length)) {
                setTab(ChannelList.release);
            }
        } catch (e: any) {
            setError(e?.message ?? "加载失败");
        } finally {
            setLoading(false);
        }
    }, [isBeta]);

    useEffect(() => {
        fetchData();
    }, [fetchData]);

    const entries = useMemo(() => allEntries[tab], [allEntries, tab]);

    const tabBgColor = Color(theme.colors.background)
        .setAlpha(((theme.mode === "dark" ? 0.7 : 0.9) * bgOpacity) / 100)
        .rgbaString;

    if (loading) {
        return (
            <View style={centered.container}>
                <ActivityIndicator size="large" color={theme.colors.primary} />
            </View>
        );
    }

    if (error) {
        return (
            <View style={centered.container}>
                <Text style={centered.errorText}>{error}</Text>
                <Button onPress={fetchData}>重试</Button>
            </View>
        );
    }

    if (!isBeta && entries.length === 0) {
        return (
            <View style={centered.container}>
                <Text style={{color: theme.colors.grey3, fontSize: 15}}>暂无 OTA 更新记录</Text>
            </View>
        );
    }

    return (
        <FlatList
            data={entries}
            keyExtractor={(item, index) => `${item.ota.versionCode}-${index}`}
            contentContainerStyle={{padding: "5%"}}
            renderItem={({item}) => (
                <OtaCard ota={item.ota} isCurrent={item.ota.versionCode === currentVersionCode} />
            )}
            ListHeaderComponent={
                isBeta ? (
                    <View style={tabStyles.tabBar}>
                        {[ChannelList.beta, ChannelList.release].map(channel => (
                            <UnPressable
                                key={channel}
                                onPress={() => setTab(channel)}
                                style={[
                                    tabStyles.tab,
                                    tab === channel ? tabStyles.tabActive : tabStyles.tabInactive,
                                    {backgroundColor: tab === channel ? theme.colors.primary : tabBgColor},
                                ]}>
                                <Text
                                    style={[
                                        tabStyles.tabText,
                                        {color: tab === channel ? "#fff" : theme.colors.grey3},
                                    ]}>
                                    {CHANNEL_LABELS[channel]}
                                </Text>
                            </UnPressable>
                        ))}
                    </View>
                ) : null
            }
            ListEmptyComponent={
                <Text style={[centered.emptyText, {color: theme.colors.grey3}]}>暂无 OTA 更新记录</Text>
            }
        />
    );
}

const centered = StyleSheet.create({
    container: {
        flex: 1,
        justifyContent: "center",
        alignItems: "center",
        padding: 20,
    },
    errorText: {
        marginBottom: 16,
        textAlign: "center",
        fontSize: 14,
    },
    emptyText: {
        padding: 30,
        textAlign: "center",
        fontSize: 15,
    },
});

const tabStyles = StyleSheet.create({
    tabBar: {
        flexDirection: "row",
        marginBottom: 12,
        borderRadius: 6,
        overflow: "hidden",
    },
    tab: {
        flex: 1,
        paddingVertical: 10,
        alignItems: "center",
        justifyContent: "center",
    },
    tabActive: {},
    tabInactive: {},
    tabText: {
        fontSize: 14,
        fontWeight: "600",
    },
});
