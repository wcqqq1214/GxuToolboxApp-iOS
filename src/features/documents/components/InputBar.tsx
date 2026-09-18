import React from "react";
import {StyleSheet, TextInput, TouchableOpacity, View} from "react-native";
import {useTheme} from "@rneui/themed";
import {Icon} from "@/components/un-ui";

type Props = {
    /** 当前搜索关键词 */
    keyword: string;
    /** 关键词变化回调 */
    onKeywordChange: (text: string) => void;
    /** 提交搜索回调 */
    onSubmit?: () => void;
    /** 是否禁用 */
    disabled?: boolean;
    /** 占位文本 */
    placeholder?: string;
};

export function InputBar(props: Props) {
    const {theme} = useTheme();
    const inputRef = React.useRef<TextInput>(null);

    const style = StyleSheet.create({
        container: {
            flexDirection: "row",
            alignItems: "center",
            backgroundColor: theme.colors.grey5,
            borderRadius: 8,
            borderWidth: 1,
            borderColor: theme.colors.grey3,
            paddingHorizontal: 10,
            height: 40,
        },
        input: {
            flex: 1,
            fontSize: 14,
            color: theme.colors.black,
            paddingVertical: 0,
        },
        iconBtn: {
            padding: 4,
        },
    });

    function handleClear() {
        props.onKeywordChange("");
        inputRef.current?.focus();
    }

    return (
        <View style={style.container}>
            <Icon
                type="material"
                name="magnify"
                size={20}
                color={theme.colors.grey2}
            />

            <TextInput
                ref={inputRef}
                style={style.input}
                value={props.keyword}
                onChangeText={props.onKeywordChange}
                onSubmitEditing={props.onSubmit}
                placeholder={props.placeholder ?? "搜索文件标题..."}
                placeholderTextColor={theme.colors.grey3}
                editable={!props.disabled}
                returnKeyType="search"
                autoCorrect={false}
            />

            {props.keyword.length > 0 && (
                <TouchableOpacity
                    style={style.iconBtn}
                    activeOpacity={0.6}
                    onPress={handleClear}
                    hitSlop={{top: 8, bottom: 8, left: 8, right: 8}}>
                    <Icon
                        type="material"
                        name="close-circle"
                        size={18}
                        color={theme.colors.grey2}
                    />
                </TouchableOpacity>
            )}
        </View>
    );
}
