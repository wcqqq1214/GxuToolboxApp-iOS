import {StyleSheet} from "react-native";
import {Dialog, Text, useTheme} from "@rneui/themed";
import {Color} from "@/shared/color.ts";
import React, {useEffect, useState} from "react";
import DateTimePicker, {type DateType, useDefaultStyles} from "react-native-ui-datepicker";
import moment from "moment/moment";
import dayjs from "dayjs";
import {UnPressable} from "@/components/un-ui";

interface Props {
    value: number;
    mode: "single" | "range" | "multiple";
    onlyDate?: boolean;
    /** 可选日期下限。 */
    minDate?: DateType;
    /** 可选日期上限。 */
    maxDate?: DateType;
    /** 只有传入日期可选；未传时不做额外限制。 */
    enabledDates?: DateType[] | ((date: DateType) => boolean);
    onChange?: (value: number) => void;
}

/**
 * 作用：通用日期选择入口；点击后打开日历 Dialog。
 * 修改注意：日期限制由调用方通过 minDate/maxDate/enabledDates 传入，不在组件内绑定具体星期。
 */
export function UnDateTimePicker(props: Props) {
    const defaultStyles = useDefaultStyles();
    const {theme} = useTheme();
    const [dialogVisible, setDialogVisible] = useState(false);
    const [value, setValue] = useState(props.value);
    const style = StyleSheet.create({
        labelContainer: {
            backgroundColor: Color.mix(
                theme.colors.grey5,
                theme.colors.primary,
                theme.mode === "light" ? 0.15 : 0.2,
            ).setAlpha(theme.mode === "light" ? 0.7 : 0.55).rgbaString,
            borderRadius: 5,
            paddingHorizontal: 15,
            paddingVertical: 10,
        },
    });

    useEffect(() => {
        setValue(props.value);
    }, [props.value]);

    return (
        <>
            <UnPressable onPress={() => setDialogVisible(true)} style={style.labelContainer}>
                <Text>{moment(value).format(props.onlyDate ? "YYYY-MM-DD" : "YYYY-MM-DD hh:mm:ss")}</Text>
            </UnPressable>
            <Dialog isVisible={dialogVisible} onBackdropPress={() => setDialogVisible(false)}>
                <DateTimePicker
                    styles={defaultStyles}
                    mode={props.mode}
                    locale="cn"
                    showOutsideDays
                    firstDayOfWeek={1}
                    minDate={props.minDate}
                    maxDate={props.maxDate}
                    enabledDates={props.enabledDates}
                    date={value}
                    onChange={(change: unknown) => {
                        if (change === null || typeof change !== "object" || !("date" in change)) return;
                        const next = dayjs((change as {date?: DateType}).date).valueOf();
                        if (!Number.isFinite(next)) return;
                        setValue(next);
                        props.onChange?.(next);
                        if (props.mode === "single") setDialogVisible(false);
                    }}
                />
            </Dialog>
        </>
    );
}
