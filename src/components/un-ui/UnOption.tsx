import React, {useState} from "react";
import {Text, useTheme} from "@rneui/themed";
import {StyleSheet, TouchableOpacity, View, ViewProps} from "react-native";

interface Props {
    options: Option[];
    label: string;
    onSelect?: (index: number) => void;
}

interface Option {
    label: string;
    key: string;
    checked: boolean;
}

export function UnOption(props: Props & ViewProps) {
    const {theme} = useTheme();
    const [selectIdx, setSelectIdx] = useState<number>(-1);

    const styles = StyleSheet.create({
        item: {marginBottom: 16},
        itemTitle: {
            fontSize: 14,
            lineHeight: 22,
            color: theme.colors.black,
            marginBottom: 12,
        },
        radioRow: {
            flexDirection: "row",
            justifyContent: "space-between",
            gap: 6,
        },
        radioWrap: {
            flex: 1,
            alignItems: "center",
            justifyContent: "center",
            paddingVertical: 10,
            borderRadius: 10,
            borderWidth: 1,
            borderColor: theme.mode === "dark" ? "rgba(255,255,255,0.08)" : "#f0f0f0",
            backgroundColor: theme.mode === "dark" ? "rgba(255,255,255,0.03)" : "#fafafa",
        },
        radioDot: {
            width: 8,
            height: 8,
            borderRadius: 4,
            backgroundColor: theme.mode === "dark" ? "rgba(255,255,255,0.2)" : "#d9d9d9",
            marginBottom: 6,
        },
        radioText: {
            fontSize: 11,
            color: theme.colors.grey2,
            textAlign: "center",
        },
    });

    const isActive = (opt: Option, optIdx: number) => (opt.checked && selectIdx === -1) || selectIdx === optIdx;

    return (
        <View style={styles.item} {...props}>
            <Text style={styles.itemTitle}>{props.label}</Text>
            <View style={styles.radioRow}>
                {props.options.map((opt, optIdx) => {
                    const active = isActive(opt, optIdx);
                    return (
                        <TouchableOpacity
                            key={opt.key}
                            activeOpacity={0.7}
                            style={[
                                styles.radioWrap,
                                active && {
                                    borderColor: theme.colors.primary,
                                    backgroundColor: `${theme.colors.primary}15`,
                                },
                            ]}
                            onPress={() => {
                                props.onSelect?.(optIdx);
                                setSelectIdx(optIdx);
                            }}>
                            <View style={[styles.radioDot, active && {backgroundColor: theme.colors.primary}]} />
                            <Text
                                style={[styles.radioText, active && {color: theme.colors.primary, fontWeight: "600"}]}>
                                {opt.label}
                            </Text>
                        </TouchableOpacity>
                    );
                })}
            </View>
        </View>
    );
}
