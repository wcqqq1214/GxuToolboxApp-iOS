import {Controller, useFormContext} from "react-hook-form";
import {StyleSheet, Text, TouchableOpacity, View} from "react-native";

import React from "react";
import {formStyles} from "./formStyles.ts";
import {Icon} from "@/components/un-ui";

interface ChooserProps {
    name: string;
    label: string;
    rules?: object;
    options: {
        label: string;
        value: string;
    }[];
    multi?: boolean;
}

export const Chooser = ({name, label, rules, options, multi = false}: ChooserProps) => {
    const {
        control,
        formState: {errors},
    } = useFormContext();
    return (
        <View>
            <Text style={formStyles.label}>{label}</Text>
            <Controller
                control={control}
                name={name}
                rules={rules}
                render={({field: {onChange, value}}) => {
                    // 确保在多选模式下 value 是一个数组
                    const currentValue = multi ? (Array.isArray(value) ? value : []) : value;

                    const handlePress = (itemValue: string) => {
                        if (multi) {
                            // 多选逻辑
                            const newValues = currentValue.includes(itemValue)
                                ? currentValue.filter((v: string) => v !== itemValue) // 移除
                                : [...currentValue, itemValue]; // 添加
                            onChange(newValues);
                        } else {
                            // 单选逻辑
                            onChange(itemValue);
                        }
                    };

                    return (
                        <View style={chooserStyles.radioGroup}>
                            {options.map((item: any) => {
                                const isSelected = multi
                                    ? currentValue.includes(item.value)
                                    : currentValue === item.value;

                                return (
                                    <TouchableOpacity
                                        key={item.value}
                                        style={chooserStyles.radioRow}
                                        onPress={() => handlePress(item.value)}>
                                        <View style={{width: 20, alignItems: "center", marginRight: 15}}>
                                            <Icon
                                                type="material"
                                                name={isSelected ? "checkbox-outline" : "checkbox-blank-outline"}
                                                size={24}
                                                color={isSelected ? "#007AFF" : "#666"}
                                            />
                                        </View>
                                        <Text style={{fontSize: 17}}>{item.label}</Text>
                                    </TouchableOpacity>
                                );
                            })}
                        </View>
                    );
                }}
            />
            {errors[name] && <Text style={formStyles.error}>{errors[name]?.message?.toString()}</Text>}
        </View>
    );
};

const chooserStyles = StyleSheet.create({
    radioGroup: {
        marginVertical: 4,
    },
    radioRow: {
        flexDirection: "row",
        alignItems: "center",
        marginVertical: 10,
    },
    radio: {
        height: 20,
        width: 20,
        borderWidth: 1,
        marginRight: 8,
        borderColor: "#666",
    },
    radioChecked: {
        backgroundColor: "#007AFF",
    },
});
