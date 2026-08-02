import {StyleSheet, View} from "react-native";
import {useTheme} from "@rneui/themed";
import {Icon, UnPressable, UnText} from "@/components/un-ui";

type Props = {
    title: string;
    subtitle?: string;
    onPress?: () => void;
};

export function FileCard(props: Props) {
    const {theme} = useTheme();

    const style = StyleSheet.create({
        card: {
            flexDirection: "row",
            alignItems: "center",
            backgroundColor: theme.colors.grey5,
            borderRadius: 10,
            paddingHorizontal: 10,
            paddingVertical: 12,
            marginBottom: 6,
            elevation: 2,
            shadowColor: "#000",
            shadowOffset: {width: 0, height: 1},
            shadowOpacity: 0.08,
            shadowRadius: 3,
        },
        iconWrapper: {
            width: 36,
            height: 36,
            borderRadius: 18,
            backgroundColor: theme.colors.primary + "18",
            justifyContent: "center",
            alignItems: "center",
            marginRight: 12,
        },
        content: {
            flex: 1,
        },
        title: {
            fontSize: 14,
            fontWeight: "600",
            color: theme.colors.black,
            marginBottom: 2,
            flexShrink: 1,
        },
        subtitle: {
            fontSize: 12,
            color: theme.colors.grey3,
            flexShrink: 0,
        },
    });

    return (
        <UnPressable style={style.card} onPress={props.onPress}>
            <View style={style.iconWrapper}>
                <Icon type="material" name="file-document-outline" size={20} color={theme.colors.primary} />
            </View>
            <View style={style.content}>
                <UnText style={style.title} numberOfLines={1}>{props.title}</UnText>
                {props.subtitle ? (
                    <UnText style={style.subtitle} numberOfLines={1}>{props.subtitle}</UnText>
                ) : null}
            </View>
        </UnPressable>
    );
}
