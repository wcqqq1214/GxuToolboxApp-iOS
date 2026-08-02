import React, {JSX} from "react";
import {Controller, useFormContext} from "react-hook-form";
import {KeyboardTypeOptions, Text, TextInput, TextInputProps, View} from "react-native";
import {formStyles, inputStyles} from "@/features/feedback/components/formItem/formStyles.ts";

export interface InputProps {
    /**
     * 在 react-hook-form 中注册的字段名称。这是必填项。
     * @example 'username'
     * @example 'user.firstName'
     */
    name: string;
    /**
     * 显示在输入框上方的标签文本。这是必填项。
     */
    label: string;
    /**
     * react-hook-form 的验证规则对象。可选。
     * 用于定义字段的验证逻辑，如必填、最小长度、正则表达式等。
     * @see https://react-hook-form.com/api/useform/register
     * @example
     * {
     *   required: '此字段为必填项',
     *   minLength: { value: 4, message: '长度不能少于4个字符' },
     *   pattern: { value: /^[A-Za-z]+$/i, message: '只能包含英文字母' }
     * }
     */
    rules?: object;
    /**
     * 输入框的占位文本。可选。
     * 如果未提供，则占位符将是一个空字符串。
     */
    placeholder?: string;
    /**
     * 指定要显示的键盘类型，以优化用户输入体验。可选。
     * 如果未提供，将默认为 'default'。
     * @see https://reactnative.dev/docs/textinput#keyboardtype
     * @type {KeyboardTypeOptions}
     * @example 'numeric'         // 纯数字键盘
     * @example 'email-address'   // 带有 @ 和 . 符号的邮箱键盘
     * @example 'phone-pad'       // 电话拨号键盘
     */
    keyboardType?: KeyboardTypeOptions;
    editable?: boolean;
    onFocus?: TextInputProps["onFocus"];
}

export const Input = ({
    name,
    label,
    rules,
    placeholder,
    keyboardType,
    editable = true,
    onFocus,
}: InputProps): JSX.Element => {
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
                        style={inputStyles.input}
                        placeholder={placeholder || ""}
                        value={value}
                        onChangeText={onChange}
                        keyboardType={keyboardType || "default"}
                        editable={editable}
                        onFocus={onFocus}
                    />
                )}
            />
            {errors[name] && <Text style={formStyles.error}>{(errors[name] as any).message}</Text>}
        </View>
    );
};
