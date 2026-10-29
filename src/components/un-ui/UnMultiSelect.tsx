import {useEffect, useRef, useState} from "react";
import {Modal, Pressable, ScrollView, StyleSheet, useWindowDimensions, View} from "react-native";
import {useTheme} from "@rneui/themed";
import {Color} from "@/shared/color";
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

type DropdownAnchor = {
    left: number;
    top: number;
    width: number;
    maxHeight: number;
};

/**
 * 作用：展开式多选下拉框；未选择任何项表示调用方定义的“全部”。
 * 修改注意：候选框通过独立浮层锚定在触发器下方，不参与页面布局；空字符串是合法选项值。
 */
export function UnMultiSelect(props: UnMultiSelectProps) {
    const {options, selectedValues, onChange, emptyLabel, title, disabled = false} = props;
    const {theme} = useTheme();
    const {height: windowHeight} = useWindowDimensions();
    const [open, setOpen] = useState(false);
    const [anchor, setAnchor] = useState<DropdownAnchor | null>(null);
    const triggerRef = useRef<View>(null);
    const selected = new Set(selectedValues);
    const selectedLabels = options.filter(option => selected.has(option.value)).map(option => option.label);
    const controlBackground = Color.mix(
        theme.colors.grey5,
        theme.colors.primary,
        theme.mode === "light" ? 0.15 : 0.2,
    ).setAlpha(theme.mode === "light" ? 0.7 : 0.55).rgbaString;
    const floatingBackground = Color.mix(
        theme.colors.background,
        theme.colors.primary,
        theme.mode === "light" ? 0.1 : 0.2,
    ).rgbaString;
    const floatingShadow = Color.mix(theme.colors.grey2, theme.colors.primary, 0.25).setAlpha(0.4).rgbaString;
    const summary =
        selectedLabels.length === 0
            ? emptyLabel
            : selectedLabels.length === 1
              ? selectedLabels[0]
              : `已选 ${selectedLabels.length} 项`;

    const toggle = (value: string) => {
        onChange(selected.has(value) ? selectedValues.filter(item => item !== value) : [...selectedValues, value]);
    };
    const closeDropdown = () => setOpen(false);
    const toggleDropdown = () => {
        if (open) {
            closeDropdown();
            return;
        }
        triggerRef.current?.measureInWindow((left, top, width, height) => {
            const dropdownTop = top + height + 6;
            const spaceBelow = Math.max(0, windowHeight - dropdownTop - 12);
            const spaceAbove = Math.max(0, top - 12);
            const openAbove = spaceBelow < 180 && spaceAbove > spaceBelow;
            const maxHeight = Math.min(360, Math.max(1, openAbove ? spaceAbove : spaceBelow));
            setAnchor({
                left,
                top: openAbove ? Math.max(12, top - maxHeight - 6) : dropdownTop,
                width,
                maxHeight,
            });
            setOpen(true);
        });
    };

    useEffect(() => {
        if (disabled) setOpen(false);
    }, [disabled]);

    return (
        <View style={styles.container}>
            <View ref={triggerRef} collapsable={false}>
                <UnPressable
                    disabled={disabled}
                    onPress={toggleDropdown}
                    style={[
                        styles.field,
                        {
                            backgroundColor: controlBackground,
                            opacity: disabled ? 0.5 : 1,
                        },
                    ]}>
                    <UnText size={14} numberOfLines={1} style={styles.summary}>
                        {summary}
                    </UnText>
                    <Icon name={open ? "chevron-up" : "chevron-down"} size={18} color={theme.colors.grey2} />
                </UnPressable>
            </View>

            <Modal
                visible={open && !disabled && anchor !== null}
                transparent
                animationType="none"
                statusBarTranslucent
                onRequestClose={closeDropdown}>
                <View style={styles.modalRoot}>
                    <Pressable style={styles.backdrop} onPress={closeDropdown} />
                    {anchor && (
                        <View
                            style={[
                                styles.dropdown,
                                {
                                    top: anchor.top,
                                    left: anchor.left,
                                    width: anchor.width,
                                    maxHeight: anchor.maxHeight,
                                    backgroundColor: floatingBackground,
                                    shadowColor: floatingShadow,
                                },
                            ]}>
                            <View style={styles.dropdownSurface}>
                                <ScrollView
                                    style={[styles.dropdownScroll, {maxHeight: anchor.maxHeight - 2}]}
                                    nestedScrollEnabled
                                    keyboardShouldPersistTaps="handled">
                                    <UnPressable
                                        onPress={() => onChange([])}
                                        style={[styles.option, {borderBottomColor: theme.colors.grey4}]}>
                                        <Icon
                                            name={
                                                selectedValues.length === 0
                                                    ? "checkbox-outline"
                                                    : "checkbox-blank-outline"
                                            }
                                            size={20}
                                            color={
                                                selectedValues.length === 0 ? theme.colors.primary : theme.colors.grey2
                                            }
                                        />
                                        <UnText
                                            size={14}
                                            color={selectedValues.length === 0 ? theme.colors.primary : undefined}>
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
                                                    index < options.length - 1 && {
                                                        borderBottomColor: theme.colors.grey4,
                                                    },
                                                ]}>
                                                <Icon
                                                    name={checked ? "checkbox-outline" : "checkbox-blank-outline"}
                                                    size={20}
                                                    color={checked ? theme.colors.primary : theme.colors.grey2}
                                                />
                                                <View style={styles.optionText}>
                                                    <UnText
                                                        size={14}
                                                        color={checked ? theme.colors.primary : undefined}>
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
                                </ScrollView>
                            </View>
                        </View>
                    )}
                </View>
            </Modal>
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
        position: "relative",
    },
    field: {
        minHeight: 40,
        borderRadius: 8,
        paddingHorizontal: 12,
        flexDirection: "row",
        alignItems: "center",
        gap: 8,
    },
    summary: {
        flex: 1,
    },
    modalRoot: {
        flex: 1,
    },
    backdrop: {
        ...StyleSheet.absoluteFillObject,
    },
    dropdown: {
        position: "absolute",
        borderRadius: 10,
        zIndex: 1000,
        elevation: 12,
        shadowOffset: {width: 0, height: 4},
        shadowOpacity: 0.2,
        shadowRadius: 8,
    },
    dropdownSurface: {
        flexShrink: 1,
        borderRadius: 10,
        overflow: "hidden",
    },
    dropdownScroll: {
        flexGrow: 0,
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
