import React, {memo, useCallback, useMemo} from "react";
import {Pressable, StyleSheet, Vibration, View} from "react-native";
import {TimeSchedule, TimeScheduleProps} from "@/components/tool/infoQuery/courseSchedule/TimeSchedule.tsx";
import {usePagerView} from "react-native-pager-view";
import moment from "moment/moment";
import {useCourseData} from "@/hooks/useCourseData.ts";
import {buildColorMap, PaletteName} from "@/features/courseSchedule/utils/colorPalette.ts";
import {ColorMapContext} from "@/features/courseSchedule/hooks/useBlocksColor.ts";

export interface TimeScheduleViewProps extends TimeScheduleProps {
    pageView: ReturnType<typeof usePagerView>;
}

export const TimeScheduleView = memo(function TimeScheduleView(props: TimeScheduleViewProps) {
    const {store} = useCourseData();
    const {AnimatedPagerView, ref, ...rest} = props.pageView;
    const startDay = props.startDay ?? moment();
    const realCurrentWeek = Math.ceil(moment.duration(moment().diff(startDay)).asWeeks());

    const paletteName = (store(s => s.theme.palette) as PaletteName) || "macaron";
    const customColors = store(s => s.theme.customColors) || {};
    const flatItems = useMemo(() => props.scheduleItems.flatMap(td => td.data), [props.scheduleItems]);
    const colorMap = useMemo(
        () => buildColorMap(flatItems, paletteName, customColors),
        [flatItems, paletteName, customColors],
    );

    const handleLongPress = useCallback(() => {
        Vibration.vibrate(10);
        ref.current?.setPage(realCurrentWeek - 1);
    }, [realCurrentWeek]);

    const timeSpanHeight = store(s => s.theme.timeSpanHeight);
    const weekdayHeight = store(s => s.theme.weekdayHeight);
    const style = useMemo(
        () =>
            StyleSheet.create({
                pagerView: {
                    width: "100%",
                    height: timeSpanHeight * (timeSpanHeight <= 40 ? 14 : 13) + weekdayHeight + 50,
                },
            }),
        [timeSpanHeight, weekdayHeight],
    );

    return (
        <ColorMapContext.Provider value={colorMap}>
            <AnimatedPagerView
                ref={ref}
                style={style.pagerView}
                initialPage={realCurrentWeek - 1}
                layoutDirection="ltr"
                scrollEnabled={rest.scrollEnabled}
                pageMargin={10}
                onPageSelected={rest.onPageSelected}
                onPageScrollStateChanged={rest.onPageScrollStateChanged}
                offscreenPageLimit={2}
                overScrollMode="never"
                orientation="horizontal">
                {useMemo(
                    () =>
                        rest.pages.map((_, index) => (
                            <Pressable style={{width: "100%"}} onLongPress={handleLongPress}>
                                <View key={index} collapsable={false}>
                                    <TimeSchedule {...props} currentWeek={index + 1} />
                                </View>
                            </Pressable>
                        )),
                    [rest.pages.length, props.scheduleItems, props.startDay],
                )}
            </AnimatedPagerView>
        </ColorMapContext.Provider>
    );
});
