import {useState} from "react";
import {StyleSheet, View} from "react-native";
import {useTheme} from "@rneui/themed";
import {Icon} from "./Icon";
import {UnPressable} from "./UnPressable";
import {UnText} from "./UnText";

export type UnMultiSelectOption = {
    value: string;
    label: string;
    description?: string;
};

export type UnMultiSelectProps = {
    options: UnMultiSelectOption[];
    selectedValues: string[];
    onChange: (values: string[]) => void;
    /** 未选择任何项时显示的文案。 */
    emptyLabel: string;
    /** 下拉选项的标题。 */
    title?: string;
    disabled?: boolean;
};

/**
 * 作用：展开式多选下拉框；未选择任何项表示调用方定义的“全部”。
 * 修改注意：空字符串是合法选项值（如“其他楼栋”），不要用真值判断是否选中。
 */
export function UnMultiSelect(props: UnMultiSelectProps) {
    const {options, selectedValues, onChange, emptyLabel, title, disabled = false} = props;
    const {theme} = useTheme();
    const [open, setOpen] = useState(false);
    const selected = new Set(selectedValues);
    const selectedLabels = options.filter(option => selected.has(option.value)).map(option => option.label);
    const summary =
        selectedLabels.length === 0
            ? emptyLabel
            : selectedLabels.length === 1
              ? selectedLabels[0]
              : `已选 ${selectedLabels.length} 项`;

    const toggle = (value: string) => {
        onChange(
            selected.has(value)
                ? selectedValues.filter(item => item !== value)
                : [...selectedValues, value],
        );
    };

    return (
        <View style={styles.container}>
            <UnPressable
                disabled={disabled}
                onPress={() => setOpen(value => !value)}
                style={[
                    styles.field,
                    {
                        borderColor: theme.colors.grey4,
                        backgroundColor: theme.colors.grey5,
                        opacity: disabled ? 0.5 : 1,
                    },
                ]}>
                <UnText size={14} numberOfLines={1} style={styles.summary}>
                    {summary}
                </UnText>
                <Icon name={open ? "chevron-up" : "chevron-down"} size={18} color={theme.colors.grey2} />
            </UnPressable>

            {open && !disabled && (
                <View
                    style={[
                        styles.dropdown,
                        {
                            borderColor: theme.colors.grey4,
                            backgroundColor: theme.colors.background,
                        },
                    ]}>
                    <UnPressable
                        onPress={() => onChange([])}
                        style={[styles.option, {borderBottomColor: theme.colors.grey4}]}>
                        <Icon
                            name={selectedValues.length === 0 ? "checkbox-outline" : "checkbox-blank-outline"}
                            size={20}
                            color={selectedValues.length === 0 ? theme.colors.primary : theme.colors.grey2}
                        />
                        <UnText size={14} color={selectedValues.length === 0 ? theme.colors.primary : undefined}>
                            {emptyLabel}
                        </UnText>
                    </UnPressable>
                    {!!title && (
                        <UnText size={11} color={theme.colors.grey2} style={styles.title}>
                            {title}
                        </UnText>
                    )}
                    {options.map((option, index) => {
                        const checked = selected.has(option.value);
                        return (
                            <UnPressable
                                key={option.value || "other"}
                                onPress={() => toggle(option.value)}
                                style={[
                                    styles.option,
                                    index < options.length - 1 && {borderBottomColor: theme.colors.grey4},
                                ]}>
                                <Icon
                                    name={checked ? "checkbox-outline" : "checkbox-blank-outline"}
                                    size={20}
                                    color={checked ? theme.colors.primary : theme.colors.grey2}
                                />
                                <View style={styles.optionText}>
                                    <UnText size={14} color={checked ? theme.colors.primary : undefined}>
                                        {option.label}
                                    </UnText>
                                    {!!option.description && (
                                        <UnText size={11} color={theme.colors.grey2}>
                                            {option.description}
                                        </UnText>
                                    )}
                                </View>
                            </UnPressable>
                        );
                    })}
                </View>
            )}
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
        gap: 6,
    },
    field: {
        minHeight: 40,
        borderWidth: 1,
        borderRadius: 8,
        paddingHorizontal: 12,
        flexDirection: "row",
        alignItems: "center",
        gap: 8,
    },
    summary: {
        flex: 1,
    },
    dropdown: {
        borderWidth: 1,
        borderRadius: 8,
        overflow: "hidden",
    },
    option: {
        minHeight: 42,
        borderBottomWidth: StyleSheet.hairlineWidth,
        paddingHorizontal: 12,
        flexDirection: "row",
        alignItems: "center",
        gap: 9,
    },
    optionText: {
        flex: 1,
        gap: 1,
    },
    title: {
        paddingHorizontal: 12,
        paddingTop: 8,
        paddingBottom: 4,
    },
});
