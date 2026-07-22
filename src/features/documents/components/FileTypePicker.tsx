import {useState} from "react";
import {StyleSheet, TouchableOpacity, View} from "react-native";
import {UnText, vw} from "@/components/un-ui";
import {useTheme} from "@rneui/themed";
import {FileTypeLabels} from "@/type/api/fileSystem/query.ts";

type Props = {
    selectedValue: number;
    onValueChange: (value: number) => void;
    enabled?: boolean;
};

export function FileTypePicker(props: Props) {
    const [open, setOpen] = useState(false);
    const {theme} = useTheme();
    const items = Array.from(FileTypeLabels);
    const selectedLabel = items.find(([, v]) => v === props.selectedValue)?.[0] ?? items[0]?.[0] ?? "";

    const style = StyleSheet.create({
        container: {
            position: "relative",
        },
        trigger: {
            flexDirection: "row",
            alignItems: "center",
            paddingVertical: 4,
            paddingHorizontal: 8,
            borderRadius: 6,
            borderWidth: 1,
            borderColor: theme.colors.grey3,
            backgroundColor: props.enabled ? "transparent" : theme.colors.grey5,
            gap: 4,
        },
        arrow: {
            transform: [{rotate: open ? "180deg" : "0deg"}],
        },
        dropdown: {
            position: "absolute",
            top: "100%",
            left: 0,
            right: 0,
            zIndex: 999,
            marginTop: 4,
            backgroundColor: theme.colors.white,
            borderRadius: 8,
            borderWidth: 1,
            borderColor: theme.colors.grey3,
            elevation: 4,
            shadowColor: "#000",
            shadowOffset: {width: 0, height: 2},
            shadowOpacity: 0.15,
            shadowRadius: 4,
            overflow: "hidden",
        },
        option: {
            paddingVertical: 10,
            paddingHorizontal: 12,
        },
        optionActive: {
            backgroundColor: theme.colors.primary,
        },
    });

    function handleSelect(value: number) {
        if (value !== props.selectedValue) {
            props.onValueChange(value);
        }
        setOpen(false);
    }

    return (
        <View style={style.container}>
            <TouchableOpacity
                style={style.trigger}
                activeOpacity={0.6}
                disabled={!props.enabled}
                onPress={() => setOpen(!open)}>
                <UnText size={14} color={props.enabled ? theme.colors.black : theme.colors.grey2}>
                    {selectedLabel}
                </UnText>
                <UnText size={10} style={style.arrow} color={theme.colors.grey2}>
                    ▼
                </UnText>
            </TouchableOpacity>

            {open && (
                <View style={style.dropdown}>
                    {items.map(([label, value]) => (
                        <TouchableOpacity
                            key={value}
                            style={[
                                style.option,
                                value === props.selectedValue && style.optionActive,
                            ]}
                            activeOpacity={0.5}
                            onPress={() => handleSelect(value)}>
                            <UnText
                                size={14}
                                color={value === props.selectedValue ? theme.colors.white : theme.colors.black}>
                                {label}
                            </UnText>
                        </TouchableOpacity>
                    ))}
                </View>
            )}
        </View>
    );
}
