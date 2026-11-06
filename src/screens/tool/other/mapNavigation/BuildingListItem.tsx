import {Text, useTheme} from "@rneui/themed";
import {StyleSheet, TouchableOpacity, View} from "react-native";
import {Icon} from "@/components/un-ui/Icon.tsx";
import Flex from "@/components/un-ui/Flex.tsx";
import {Color} from "@/shared/color.ts";
import type {Building} from "@/features/map/type.ts";
import {useMapNavigation} from "@/features/map/hooks/useMapNavigation.ts";

interface Props {
    building: Building;
}

export default function BuildingListItem(props: Props) {
    const {openMap} = useMapNavigation();

    const {theme} = useTheme();
    const defaultColor = Color.mix(
        Color(theme.colors.primary),
        Color(theme.colors.background),
        theme.mode === "dark" ? 0.1 : 0.4,
    ).setAlpha(theme.mode === "dark" ? 0.3 : 0.8).rgbaString;

    const styles = StyleSheet.create({
        container: {
            marginHorizontal: 16,
            marginVertical: 8,
            padding: 16,
            borderRadius: 12,
            borderWidth: 1,
            borderColor: defaultColor,
            backgroundColor: Color(theme.colors.primary).setAlpha(0.05).rgbaString,
            flexDirection: "row",
            alignItems: "center",
            justifyContent: "space-between",
        },
        nameText: {
            fontSize: 18,
            fontWeight: "500",
            color: theme.colors.black,
        },
        iconContainer: {
            marginLeft: 16,
            padding: 4,
        },
        tag: {
            borderRadius: 4,
            borderWidth: 1,
            borderColor: Color.mix(theme.colors.primary, theme.colors.black, 0.3).rgbaString,
            paddingHorizontal: 8,
            paddingVertical: 4,
        },
        tagText: {
            fontSize: 12,
            color: Color.mix(theme.colors.primary, theme.colors.black, 0.3).rgbaString,
        },
    });

    return (
        <TouchableOpacity onPress={() => openMap(props.building.fullName)}>
            <View style={styles.container}>
                <Flex direction="column" align="flex-start" style={{flex: 1}}>
                    <Text style={styles.nameText}>{props.building.name}</Text>
                    <Flex style={{flexWrap: "wrap", marginTop: 8}} gap={8}>
                        {props.building.simpleName.map((name, index) => (
                            <View
                                key={index}
                                style={[styles.tag, name.includes("新生开学报道处") && {borderColor: "#FF0000"}]}>
                                <Text style={[styles.tagText, name.includes("新生开学报道处") && {color: "#FF0000"}]}>
                                    {name}
                                </Text>
                            </View>
                        ))}
                    </Flex>
                </Flex>
                <View style={styles.iconContainer}>
                    <Icon
                        type="ionicons"
                        name="navigate"
                        color={Color.mix(theme.colors.primary, theme.colors.black).rgbaString}
                        size={28}
                    />
                </View>
            </View>
        </TouchableOpacity>
    );
}
