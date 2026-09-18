import React from "react";
import {StyleProp, View, ViewStyle} from "react-native";
import {BottomSheet, BottomSheetProps, useTheme} from "@rneui/themed";
import {Color} from "@/shared/color";

export interface UnBottomSheetProps extends Omit<BottomSheetProps, "containerStyle"> {
    containerStyle?: StyleProp<ViewStyle>;
    useDefaultContainer?: boolean;
    sheetStyle?: BottomSheetProps["containerStyle"];
}

export function UnBottomSheet(props: React.PropsWithChildren<UnBottomSheetProps>) {
    const {containerStyle, sheetStyle, useDefaultContainer = true, children, ...rest} = props;
    const {theme} = useTheme();

    const defaultContainerStyle = {
        backgroundColor: Color.mix(theme.colors.primary, theme.colors.background, 0.8).rgbaString,
        borderTopLeftRadius: 8,
        borderTopRightRadius: 8,
        padding: "2.5%",
    };

    return (
        <BottomSheet {...rest} containerStyle={sheetStyle}>
            <View
                style={
                    useDefaultContainer
                        ? ([defaultContainerStyle, containerStyle] as StyleProp<ViewStyle>)
                        : containerStyle
                }>
                {children}
            </View>
        </BottomSheet>
    );
}
