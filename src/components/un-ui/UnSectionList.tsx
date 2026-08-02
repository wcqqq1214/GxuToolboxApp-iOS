import {Linking, SectionList, SectionListProps, StyleSheet, ToastAndroid, View} from "react-native";
import Clipboard from "@react-native-clipboard/clipboard";
import {Color} from "@/shared/color.ts";
import {useNavigation} from "@react-navigation/native";
import {Text, useTheme} from "@rneui/themed";
import {Icon} from "@/components/un-ui/Icon.tsx";
import Flex from "@/components/un-ui/Flex.tsx";
import {UnPressable} from "@/components/un-ui";
import {useUserConfig} from "@/hooks/useUserConfig.ts";

export interface UnListSection {
    title: string;
    data: UnListItem[];
}

interface UnListItem {
    label: string;
    type: "navigation" | "text" | "link" | "any" | "blockAny";
    value: any;
    url?: string;
}

interface Props {}

export function UnSectionList(props: Props & SectionListProps<UnListItem, UnListSection>) {
    const {store} = useUserConfig();
    const navigation = useNavigation();
    const {theme} = useTheme();
    const bgOpacity = store(s => s.theme.bgOpacity);

    const bgColor = Color.mix(
        theme.mode === "light" ? theme.colors.background : theme.colors.grey5,
        theme.colors.primary,
        0.3,
    ).setAlpha(0.1 + ((theme.mode === "light" ? 0.7 : 0.1) * bgOpacity) / 100).rgbaString;
    const borderRadius = 8;
    const span = 8;
    const style = StyleSheet.create({
        settingSectionContainer: {
            paddingBottom: "5%",
            marginBottom: 10,
        },
        settingSectionHeader: {
            backgroundColor: bgColor,
            paddingHorizontal: borderRadius,
            borderTopLeftRadius: borderRadius,
            borderTopRightRadius: borderRadius,
            paddingTop: borderRadius,
            paddingBottom: 4,
        },
        settingSectionFooter: {
            marginBottom: span,
            backgroundColor: bgColor,
            height: borderRadius,
            paddingHorizontal: borderRadius,
            borderBottomLeftRadius: borderRadius,
            borderBottomRightRadius: borderRadius,
            paddingTop: borderRadius,
        },
        settingItemContainer: {
            backgroundColor: bgColor,
            paddingHorizontal: "3%",
        },
        settingItem: {
            flexDirection: "row",
            justifyContent: "space-between",
            paddingVertical: 15,
            paddingHorizontal: 10,
        },
        linkText: {
            borderBottomWidth: 1,
            borderBottomColor: theme.colors.black,
            textAlign: "center",
        },
        labelText: {
            fontSize: 16,
        },
    });

    async function openUrl(url?: string) {
        if (url) {
            Linking.openURL(url).catch(e => {
                console.error(e);
                ToastAndroid.show("打开链接失败，已将链接复制至剪切板", ToastAndroid.LONG);
                Clipboard.setString(url);
            });
        }
    }

    const renderItem = (item: UnListItem, underlined: boolean) => {
        const itemStyle = [
            style.settingItem,
            underlined && {
                borderBottomColor: Color.mix(theme.colors.grey3, theme.colors.primary).setAlpha(0.3).rgbaString,
                borderBottomWidth: 1,
            },
        ];
        switch (item.type) {
            case "navigation":
                return (
                    <UnPressable onPress={() => navigation.navigate(item.value)} style={itemStyle}>
                        <Text style={style.labelText}>{item.label}</Text>
                        <Icon name="chevron-right" size={16} />
                    </UnPressable>
                );
            case "text":
                return (
                    <Flex style={itemStyle} justify="space-between">
                        <Text style={style.labelText}>{item.label}</Text>
                        <Text style={{textAlign: "right"}}>{item.value}</Text>
                    </Flex>
                );
            case "link":
                return (
                    <UnPressable onPress={() => openUrl(item.url)} style={itemStyle}>
                        <Text style={style.labelText}>{item.label}</Text>
                        <Text style={style.linkText}>
                            {item.value ?? item.url} <Icon name="open-in-new" size={12} />
                        </Text>
                    </UnPressable>
                );
            case "any":
                return (
                    <Flex style={itemStyle} justify="space-between">
                        <Text style={style.labelText}>{item.label}</Text>
                        {item.value}
                    </Flex>
                );
            case "blockAny":
                return (
                    <Flex direction="column" align="flex-start" gap={10} style={itemStyle}>
                        <View>
                            <Text style={style.labelText}>{item.label}</Text>
                        </View>
                        {item.value}
                    </Flex>
                );
            default:
                return (
                    <View style={itemStyle}>
                        <Text style={style.labelText}>{item.label}</Text>
                    </View>
                );
        }
    };
    return (
        <SectionList<UnListItem, UnListSection>
            getItemCount={() => 5}
            renderItem={({item, index, section}) => (
                <View style={style.settingItemContainer}>{renderItem(item, index !== section.data.length - 1)}</View>
            )}
            contentContainerStyle={style.settingSectionContainer}
            renderSectionHeader={({section: {title}}) => (
                <View style={style.settingSectionHeader}>
                    <Text h4>{title}</Text>
                </View>
            )}
            renderSectionFooter={() => <View style={style.settingSectionFooter} />}
            {...props}
        />
    );
}
