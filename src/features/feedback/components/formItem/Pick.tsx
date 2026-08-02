import {Controller, useFormContext} from "react-hook-form";
import {StyleSheet, Text, View} from "react-native";
import React from "react";
import {formStyles} from "./formStyles.ts";
import {Picker} from "@react-native-picker/picker";

interface PickProps {
    name: string;
    label: string;
    rules?: object;
    placeholder: string;
    units: any[];
    readonly?: boolean;
}

export const Pick = ({name, label, rules, placeholder, units, readonly}: PickProps) => {
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
                    // 如果是只读模式，直接显示文本
                    if (readonly) {
                        // 从 options 数组中找到当前 value 对应的 label
                        const selectedOption = units.find(opt => opt.value === value);
                        return (
                            <View style={pickerStyles.pickerWrapper}>
                                <Text style={pickerStyles.readonlyText}>
                                    {selectedOption ? selectedOption.label : ""}
                                </Text>
                            </View>
                        );
                    }

                    // 否则，显示正常的 Picker
                    return (
                        <View style={pickerStyles.pickerWrapper}>
                            <Picker
                                selectedValue={value}
                                onValueChange={onChange}
                                style={pickerStyles.picker}
                                mode="dropdown">
                                <Picker.Item label={placeholder} value="" />
                                {units.map((opt: any) => (
                                    <Picker.Item key={opt.label} label={opt.label} value={opt.value} />
                                ))}
                            </Picker>
                        </View>
                    );
                }}
            />
            {errors[name] && <Text style={formStyles.error}>{errors[name]?.message?.toString()}</Text>}
        </View>
    );
};

const pickerStyles = StyleSheet.create({
    pickerWrapper: {
        borderWidth: StyleSheet.hairlineWidth,
        borderColor: "#888",
        borderRadius: 9,
        marginBottom: 8,
        height: 60,
    },
    picker: {
        height: 54,
    },
    readonlyText: {
        fontSize: 16,
        paddingHorizontal: 8,
        lineHeight: 54, // 垂直居中
        color: "#333",
    },
});
