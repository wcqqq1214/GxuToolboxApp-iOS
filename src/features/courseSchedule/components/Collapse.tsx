import React, {PropsWithChildren, useState} from "react";
import {StyleSheet, View} from "react-native";
import {useTheme} from "@rneui/themed";
import {Flex, Icon, UnPressable, UnText} from "@/components/un-ui";

type Props = PropsWithChildren<{
    title: string;
}>;

export function Collapse({title, children}: Props) {
    const {theme} = useTheme();
    const [collapsed, setCollapsed] = useState(true);

    return (
        <View>
            <UnPressable onPress={() => setCollapsed(value => !value)}>
                <Flex justify="space-between" style={styles.header}>
                    <UnText size={20} color={theme.colors.primary}>
                        {title}
                    </UnText>
                    <Icon name="menu-up" size={20} rotate={collapsed ? 180 : 0} />
                </Flex>
            </UnPressable>
            {!collapsed && (
                <>
                    {children}
                    <UnPressable onPress={() => setCollapsed(true)}>
                        <View style={styles.footer}>
                            <View style={[styles.line, {backgroundColor: theme.colors.primary}]} />
                            <UnText>收起↑</UnText>
                            <View style={[styles.line, {backgroundColor: theme.colors.primary}]} />
                        </View>
                    </UnPressable>
                </>
            )}
        </View>
    );
}

const styles = StyleSheet.create({
    header: {
        paddingVertical: 4,
    },
    footer: {
        flexDirection: "row",
        justifyContent: "center",
        alignItems: "center",
        marginVertical: 2,
    },
    line: {
        flex: 1,
        height: 1,
    },
});
