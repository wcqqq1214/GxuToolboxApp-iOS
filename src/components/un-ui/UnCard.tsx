import {StyleSheet, View, ViewProps} from "react-native";
import {useTheme} from "@rneui/themed";
import {Color} from "@/shared/color.ts";
import {UnText, UnTextProps} from "@/components/un-ui/UnText.tsx";
import {useUserConfig} from "@/hooks/useUserConfig.ts";

export interface UnCardProps extends ViewProps {
    color?: "primary" | "success" | "secondary" | "warning" | "error" | string;
    disableOpacityBg?: boolean;

    title?: string;
    titleColor?: string;
    titleStyle?: UnTextProps["style"];
}
export function UnCard(props: UnCardProps) {
    const {theme} = useTheme();
    const {store} = useUserConfig();
    const bgOpacity = store(s => s.theme.bgOpacity);

    const mainColor = ["primary", "success", "secondary", "warning", "error", undefined].includes(props.color)
        ? theme.colors[props.color ?? "primary"]
        : props.color;
    const style = StyleSheet.create({
        card: {
            backgroundColor: Color.mix(
                theme.mode === "light" ? theme.colors.background : theme.colors.grey5,
                theme.colors.primary,
                0.3,
            ).setAlpha(0.1 + ((theme.mode === "light" ? 0.7 : 0.1) * bgOpacity) / 100).rgbaString,
            borderRadius: 8,
            padding: 8,
        },
        titleContainer: {
            paddingHorizontal: 8,
            marginBottom: 8,
        },
    });

    return (
        <View {...props} style={[props.style, style.card]}>
            {props.title && (
                <View style={style.titleContainer}>
                    <UnText
                        h4={!props.titleStyle}
                        color={props.titleColor ?? Color.mix(mainColor, theme.colors.black, 0.4).rgbaString}
                        style={props.titleStyle}>
                        {props.title}
                    </UnText>
                </View>
            )}
            {props.children}
        </View>
    );
}
