import {Button, Text, useTheme} from "@rneui/themed";
import {useEffect, useMemo, useRef, useState} from "react";
import {Image, StyleSheet, View} from "react-native";
import {useSafeAreaInsets} from "react-native-safe-area-context";
import {Icon} from "@/components/un-ui/Icon.tsx";
import {UnBottomSheet, UnPressable} from "@/components/un-ui";

export type MapPickerApp = "amap" | "baidu";

export type MapPickerOption = {
    app: MapPickerApp;
    label: string;
};

type MapPickerRequest = {
    title: string;
    message?: string;
    options: MapPickerOption[];
};

type MapPickerResolver = (value: MapPickerApp | null) => void;
type MapPickerHandler = (request: MapPickerRequest) => Promise<MapPickerApp | null>;

let mapPickerHandler: MapPickerHandler | null = null;
const mapAppIcons = {
    amap: require("@/pictures/gaode.png"),
    baidu: require("@/pictures/baidu.png"),
} as const;

export function requestMapPicker(request: MapPickerRequest): Promise<MapPickerApp | null> | undefined {
    return mapPickerHandler?.(request);
}

export function MapPickerHost() {
    const {theme} = useTheme();
    const insets = useSafeAreaInsets();
    const [request, setRequest] = useState<MapPickerRequest | null>(null);
    const resolverRef = useRef<MapPickerResolver | null>(null);

    useEffect(() => {
        mapPickerHandler = nextRequest => {
            return new Promise(resolve => {
                resolverRef.current = resolve;
                setRequest(nextRequest);
            });
        };

        return () => {
            mapPickerHandler = null;
        };
    }, []);

    const styles = useMemo(() => StyleSheet.create({
        sheetPanel: {
            borderTopLeftRadius: 24,
            borderTopRightRadius: 24,
            borderBottomLeftRadius: 0,
            borderBottomRightRadius: 0,
            paddingTop: 10,
            backgroundColor: theme.colors.grey5,
        },
        handleRow: {
            flexDirection: "row",
            alignItems: "center",
            justifyContent: "space-between",
            paddingHorizontal: 17,
            paddingBottom: 8,
        },
        handleIconWrap: {
            width: 28,
            height: 28,
            borderRadius: 14,
            alignItems: "center",
            justifyContent: "center",
            backgroundColor: theme.colors.grey4,
        },
        handleSpacer: {
            width: 28,
            height: 28,
        },
        title: {
            fontSize: 17,
            fontWeight: "300",
            color: theme.colors.black,
            textAlign: "center",
        },
        message: {
            marginTop: 2,
            fontSize: 13,
            color: theme.colors.black,
            opacity: 0.7,
            textAlign: "center",
        },
        optionList: {
            marginTop: 9,
            marginHorizontal: 12,
            borderRadius: 16,
            overflow: "hidden",
            backgroundColor: theme.colors.white,
        },
        optionButton: {
            flexDirection: "row",
            alignItems: "center",
            paddingHorizontal: 15,
            paddingVertical:10,
        },
        optionButtonPressed: {
            backgroundColor: theme.colors.white,
        },
        optionDivider: {
            height: StyleSheet.hairlineWidth,
            backgroundColor: theme.colors.divider,
            marginLeft: 64,
        },
        appIconOuter: {
            width: 32,
            height: 32,
            borderRadius: 9,
            alignItems: "center",
            justifyContent: "center",
            marginRight: 12,
            overflow: "hidden",
        },
        appIconImage: {
            width: 28,
            height: 28,
            borderRadius: 8,
        },
        optionLabel: {
            flex: 1,
            fontSize: 16,
            fontWeight: "500",
            color: theme.colors.black,
        },
        footer: {
            paddingHorizontal: 12,
            paddingTop: 10,
            paddingBottom: 0,
        },
        cancelButton: {
            minHeight: 54,
            borderRadius: 16,
            backgroundColor: theme.colors.white,
            borderColor: "transparent",
        },
        cancelTitle: {
            color: theme.colors.black,
            fontWeight: "600",
        },
    }), [theme]);

    function close(value: MapPickerApp | null) {
        const resolver = resolverRef.current;
        resolverRef.current = null;
        setRequest(null);
        resolver?.(value);
    }

    function renderMapAppIcon(app: MapPickerApp) {
        return (
            <View style={styles.appIconOuter}>
                <Image source={mapAppIcons[app]} style={styles.appIconImage} resizeMode="cover" />
            </View>
        );
    }

    if (!request) {
        return null;
    }

    return (
        <UnBottomSheet
            isVisible
            onBackdropPress={() => close(null)}
            useDefaultContainer={false}
            containerStyle={[styles.sheetPanel, {paddingBottom: insets.bottom}]}>
            <View style={styles.handleRow}>
                <UnPressable style={styles.handleIconWrap} onPress={function() { return close(null); }}>
                    <Icon name="chevron-down" size={18} color={theme.colors.black} />
                </UnPressable>
                <View style={{flex: 1, paddingHorizontal: 12}}>
                    <Text style={styles.title}>{request.title}</Text>
                    {!!request.message && <Text style={styles.message}>{request.message}</Text>}
                </View>
                <View style={styles.handleSpacer} />
            </View>

            <View style={styles.optionList}>
                {request.options.map((option, index) => (
                    <View key={option.app}>
                        {index > 0 && <View style={styles.optionDivider} />}
                        <UnPressable
                            onPress={function() { return close(option.app); }}
                            style={function(pressed) { return [styles.optionButton, pressed && styles.optionButtonPressed]; }}>
                            {renderMapAppIcon(option.app)}
                            <Text style={styles.optionLabel}>{option.label}</Text>
                        </UnPressable>
                    </View>
                ))}
            </View>

            <View style={styles.footer}>
                <Button
                    title="取消"
                    type="outline"
                    buttonStyle={styles.cancelButton}
                    titleStyle={styles.cancelTitle}
                    onPress={() => close(null)}
                />
            </View>
        </UnBottomSheet>
    );
}
