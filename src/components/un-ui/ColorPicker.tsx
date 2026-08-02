import {StyleSheet, View} from "react-native";
import Flex from "./Flex.tsx";
import {Text, useTheme} from "@rneui/themed";
import {BaseColor, Color} from "@/shared/color.ts";
import {useCallback, useRef, useState} from "react";
import {UnPressable} from "@/components/un-ui";
import {ColorPickerInput, type ColorValue} from "react-native-color-picker-input";

interface Props {
    size: number;
    color: string;
    onColorChange: (color: string) => void;
}

export function ColorPicker(props: Partial<Props>) {
    const {theme} = useTheme();
    const [visible, setVisible] = useState(false);
    const defaultColor = Color(props.color ?? BaseColor.black);
    const [hex, setHex] = useState(defaultColor.hexString());
    const lastEmitted = useRef(hex);

    const handleChange = useCallback((_formatted: string, colorObj: ColorValue) => {
        setHex(colorObj.hex);
    }, []);

    const handleClose = useCallback(() => {
        setVisible(false);
        if (hex !== lastEmitted.current) {
            lastEmitted.current = hex;
            props.onColorChange?.(hex.toUpperCase());
        }
    }, [hex, props.onColorChange]);

    const size = props.size ?? 30;

    const style = StyleSheet.create({
        labelContainer: {
            borderColor: theme.colors.grey4,
            borderWidth: 1,
            borderRadius: 5,
            padding: 5,
            height: size,
        },
        colorLabel: {
            width: size * (2 / 3),
            height: size * (2 / 3),
            borderRadius: 3,
            backgroundColor: hex,
        },
    });

    return (
        <>
            <UnPressable onPress={() => setVisible(true)}>
                <Flex style={style.labelContainer} gap={10} inline>
                    <View style={style.colorLabel} />
                    <Text>{hex.toUpperCase()}</Text>
                </Flex>
                <ColorPickerInput
                    value={hex}
                    onChange={handleChange}
                    mode="slider"
                    presentation="modal"
                    outputFormat="hex"
                    displayFormat="hex"
                    showInputSwatch={false}
                    showInputText={false}
                    inputStyle={{display: "none"}}
                    pickerBackgroundColor={theme.colors.grey5}
                    pickerTextColor={theme.colors.black}
                    modalProps={{visible}}
                    onClose={handleClose}
                />
            </UnPressable>
        </>
    );
}
