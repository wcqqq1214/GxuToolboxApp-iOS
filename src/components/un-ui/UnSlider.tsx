import {SliderProps} from "@rneui/base";
import {Slider, Text, useTheme} from "@rneui/themed";
import {StyleProp, StyleSheet, View, ViewStyle} from "react-native";
import Flex from "./Flex.tsx";
import {Color} from "@/shared/color.ts";
import {useCallback, useMemo, useRef, useState} from "react";
import {NumberInput} from "@/components/un-ui/NumberInput.tsx";

interface Props {
    containerStyle?: StyleProp<ViewStyle>;
    sliderContainerStyle?: StyleProp<ViewStyle>;
    inputMode?: boolean;
}

const styles = StyleSheet.create({
    track: {
        marginTop: -5,
    },
    thumb: {
        marginTop: -5,
    },
    sliderWrapper: {
        marginBottom: -5,
        flex: 1,
    },
});

export function UnSlider(props: Props & SliderProps) {
    const {theme} = useTheme();
    const [inputMode, setInputMode] = useState(props.inputMode);
    const [inputValue, setInputValue] = useState<number | null>(null);
    const slidingRef = useRef<number | null>(null);
    const rafRef = useRef<number | null>(null);
    const [displayValue, setDisplayValue] = useState(props.value ?? 0);

    const value = inputValue ?? props.value ?? 0;

    const valuePreviewStyle = useMemo(() => {
        const maxLen = Math.max(
            String(props.minimumValue ?? 0).length,
            String(props.maximumValue ?? 0).length,
        );
        return {
            backgroundColor: Color(theme.colors.black).setAlpha(0.1).rgbaString,
            width: maxLen * 9 + 20,
            textAlign: "center" as const,
            paddingVertical: 6,
            borderRadius: 4,
        };
    }, [theme.colors.black, props.minimumValue, props.maximumValue]);

    const minimumTrackTintColor = useMemo(
        () => Color.mix(theme.colors.primary, theme.colors.grey2).rgbaString,
        [theme.colors.primary, theme.colors.grey2],
    );

    const clamp = useCallback(
        (v: number) => {
            let res = v;
            if (props.maximumValue !== undefined && v > props.maximumValue) {
                res = props.maximumValue;
            } else if (props.minimumValue !== undefined && v < props.minimumValue) {
                res = props.minimumValue;
            }
            return res;
        },
        [props.maximumValue, props.minimumValue],
    );

    const onSlidingComplete = useCallback(
        (vo: number) => {
            const res = clamp(+vo || 0);
            slidingRef.current = null;
            if (rafRef.current !== null) {
                cancelAnimationFrame(rafRef.current);
                rafRef.current = null;
            }
            setDisplayValue(res);
            props.onValueChange?.(res);
        },
        [clamp, props.onValueChange],
    );

    const onValueChange = useCallback((vo: number) => {
        const v = clamp(+vo || 0);
        slidingRef.current = v;
        if (rafRef.current === null) {
            rafRef.current = requestAnimationFrame(() => {
                rafRef.current = null;
                setDisplayValue(slidingRef.current ?? v);
            });
        }
    }, [clamp]);

    const onInputBlur = useCallback(() => {
        if (inputValue !== null) {
            const res = clamp(inputValue);
            props.onValueChange?.(res);
        }
        setInputValue(null);
        setInputMode(false);
    }, [inputValue, clamp, props.onValueChange]);

    return (
        <Flex gap={10} inline justify="flex-end" style={props.containerStyle}>
            {inputMode ? (
                <NumberInput
                    value={value}
                    onSubmit={v => {
                        const res = clamp(+v || 0);
                        props.onValueChange?.(res);
                        setInputValue(null);
                    }}
                    onChange={setInputValue}
                    max={props.maximumValue}
                    min={props.minimumValue}
                    step={props.step}
                    onBlur={onInputBlur}
                    autoFocus
                />
            ) : (
                <Text style={valuePreviewStyle} onPress={() => setInputMode(true)}>
                    {displayValue}
                </Text>
            )}
            <View style={styles.sliderWrapper}>
                <Slider
                    {...props}
                    onValueChange={onValueChange}
                    onSlidingComplete={onSlidingComplete}
                    value={slidingRef.current ?? value}
                    containerStyle={props.sliderContainerStyle as any}
                    minimumTrackTintColor={minimumTrackTintColor}
                    trackStyle={styles.track}
                    thumbStyle={styles.thumb}
                />
            </View>
        </Flex>
    );
}
