import {StyleSheet, View} from "react-native";
import {useTheme} from "@rneui/themed";
import {UnPressable, UnText} from "@/components/un-ui";

type Props = {
    visible: boolean;
    currentPage: number;
    totalPages: number;
    onPrev: () => void;
    onNext: () => void;
};

export function FilePaginator(props: Props) {
    const {theme} = useTheme();
    const isFirstPage = props.currentPage <= 1;
    const isLastPage = props.currentPage >= props.totalPages;

    // 总页数 ≤1 时不显示
    if (props.totalPages <= 1 || !props.visible) return null;

    const style = StyleSheet.create({
        container: {
            flexDirection: "row",
            justifyContent: "flex-end",
            alignItems: "center",
            gap: 10,
            paddingVertical: 6,
        },
        button: {
            width: 32,
            height: 32,
            borderRadius: 8,
            justifyContent: "center",
            alignItems: "center",
            backgroundColor: theme.colors.grey5,
        },
        buttonDisabled: {
            opacity: 0.30,
        },
    });

    return (
        <View style={style.container}>
            <UnPressable
                style={[style.button, isFirstPage && style.buttonDisabled]}
                onPress={props.onPrev}
                disabled={isFirstPage}>
                <UnText size={18} color={theme.colors.black}>
                    −
                </UnText>
            </UnPressable>
            <UnText size={14}>
                第 {props.currentPage} / {props.totalPages} 页
            </UnText>
            <UnPressable
                style={[style.button, isLastPage && style.buttonDisabled]}
                onPress={props.onNext}
                disabled={isLastPage}>
                <UnText size={18} color={theme.colors.black}>
                    +
                </UnText>
            </UnPressable>
        </View>
    )
}
