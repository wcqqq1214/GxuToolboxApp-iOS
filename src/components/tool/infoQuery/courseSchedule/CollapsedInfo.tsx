import {StyleSheet, View} from "react-native";
import {useTheme} from "@rneui/themed";
import {Flex, Icon, UnPressable, UnText} from "@/components/un-ui";
import React, {useState} from "react";

interface Props {
    key?: any;
    label: string;
    isCollapsed?: Boolean;
    onClick?: () => void | boolean;
}

export function CollapsedInfo(props: React.PropsWithChildren<Props>) {
    const {theme} = useTheme();
    const [collapse, setCollapse] = useState(props.isCollapsed ?? true);
    const style = StyleSheet.create({
        rowContainer: {
            flexDirection: "row",
            gap: 10,
        },
        columContainer: {
            flexDirection: "column",
            gap: 6,
        },
        dividerContainer: {
            flexDirection: "row",
            justifyContent: "center",
            alignItems: "center",
            marginVertical: 2,
        },
        dividerItem: {
            flex: 1,
            height: 1,
            backgroundColor: theme.colors.primary,
        },
    });

    return (
        <View key={props.key}>
            <UnPressable
                onPress={function () {
                    if (props.onClick?.() !== false) setCollapse(!collapse);
                }}>
                <Flex justify="space-between" style={{paddingVertical: 4}}>
                    <UnText size={20} color={theme.colors.primary}>
                        {props.label}
                    </UnText>
                    <Icon name="menu-up" size={20} rotate={collapse ? 180 : 0} />
                </Flex>
            </UnPressable>
            {!collapse && (
                <>
                    {props.children}
                    <UnPressable
                        onPress={function () {
                            if (props.onClick?.() !== false) setCollapse(true);
                        }}>
                        <View style={style.dividerContainer}>
                            <View style={style.dividerItem} />
                            <UnText>收起↑</UnText>
                            <View style={style.dividerItem} />
                        </View>
                    </UnPressable>
                </>
            )}
        </View>
    );
}
