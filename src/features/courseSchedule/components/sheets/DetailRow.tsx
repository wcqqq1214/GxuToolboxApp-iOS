import {useTheme} from "@rneui/themed";
import {Icon, UnPressable, UnText} from "@/components/un-ui";
import {Color} from "@/shared/color.ts";
import Flex from "../../../../components/un-ui/Flex.tsx";
import {View} from "react-native";
import React from "react";
import {MaterialDesignIconsIconName} from "@react-native-vector-icons/material-design-icons";

interface DetailAction {
    icon: MaterialDesignIconsIconName;
    label: string;
    onPress: () => void;
}

interface DetailRowProps {
    icon: MaterialDesignIconsIconName;
    label: string;
    value: string;
    action?: DetailAction;
}

/** 渲染课程详情中的胶囊按钮，由调用方提供图标、文案和点击行为。 */
export function DetailActionButton({icon, label, onPress}: DetailAction) {
    const {theme} = useTheme();

    return (
        <UnPressable
            accessibilityRole="button"
            onPress={onPress}
            style={{
                flexDirection: "row",
                alignItems: "center",
                gap: 4,
                paddingHorizontal: 8,
                paddingVertical: 6,
                minHeight: 32,
                maxWidth: "100%",
                borderRadius: 999,
                overflow: "hidden",
                backgroundColor: Color(theme.colors.primary).setAlpha(theme.mode === "light" ? 0.12 : 0.22).rgbaString,
            }}>
            <Icon name={icon} color={theme.colors.primary} size={16} />
            <UnText size={13} color={theme.colors.primary} style={{flexShrink: 1}}>
                {label}
            </UnText>
        </UnPressable>
    );
}

/** 统一展示课程信息的图标、标签、内容和可选操作，长内容可在中间列换行。 */
export function DetailRow({icon, label, value, action}: DetailRowProps) {
    const {theme} = useTheme();

    return (
        <Flex inline gap={12}>
            <View
                style={{
                    width: 36,
                    height: 36,
                    alignItems: "center",
                    justifyContent: "center",
                    borderRadius: 10,
                    backgroundColor: theme.colors.grey5,
                }}>
                <Icon name={icon} color={theme.colors.primary} size={20} />
            </View>
            <Flex direction="column" align="flex-start" justify="center" gap={2}>
                <UnText size={12} color={theme.colors.grey2}>
                    {label}
                </UnText>
                <UnText size={15} bold>
                    {value}
                </UnText>
            </Flex>
            {action && <DetailActionButton {...action} />}
        </Flex>
    );
}
