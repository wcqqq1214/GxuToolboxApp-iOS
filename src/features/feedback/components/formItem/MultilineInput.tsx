import {Controller, useFormContext} from "react-hook-form";
import {StyleSheet, Text, TextInput, View} from "react-native";
import React, {JSX} from "react";

import {formStyles} from "./formStyles";
import {InputProps} from "@/features/feedback/components/formItem/Input.tsx";

export const MultilineInput = ({name, label, rules, placeholder, keyboardType, onFocus}: InputProps): JSX.Element => {
    const {
        control,
        formState: {errors},
    } = useFormContext();

    return (
        <View style={{width: "100%"}}>
            <Text style={formStyles.label}>{label}</Text>
            <Controller
                control={control}
                name={name}
                rules={rules}
                render={({field: {onChange, value}}) => (
                    <TextInput
                        style={multilineInputStyles.input}
                        placeholder={placeholder || ""}
                        value={value}
                        multiline
                        onChangeText={onChange}
                        keyboardType={keyboardType || "default"}
                        onFocus={onFocus}
                    />
                )}
            />
            {errors[name] && <Text style={formStyles.error}>{(errors[name] as any).message}</Text>}
        </View>
    );
};

const multilineInputStyles = StyleSheet.create({
    input: {
        borderWidth: StyleSheet.hairlineWidth,
        borderColor: "#888",
        borderRadius: 8,
        paddingHorizontal: 8,
        fontSize: 16,
        height: 150,
        textAlignVertical: "top",
    },
});
