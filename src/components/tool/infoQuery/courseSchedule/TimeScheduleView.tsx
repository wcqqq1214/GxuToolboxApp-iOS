import React, {memo, useCallback, useMemo} from "react";
import {Pressable, StyleSheet, Vibration, View} from "react-native";
import {TimeSchedule, TimeScheduleProps} from "@/components/tool/infoQuery/courseSchedule/TimeSchedule.tsx";
import {usePagerView, type PagerViewOnPageSelectedEvent} from "react-native-pager-view";
import moment from "moment/moment";
import {getWeekOfDate} from "@/features/courseSchedule/utils/weekOfDate.ts";
import {useCourseData} from "@/hooks/useCourseData.ts";
import {buildColorMap, PaletteName} from "@/features/courseSchedule/utils/colorPalette.ts";
import {ColorMapContext} from "@/features/courseSchedule/hooks/useBlocksColor.ts";

export interface TimeScheduleViewProps extends TimeScheduleProps {
    pageView: ReturnType<typeof usePagerView>;
    /** 首次挂载时停留的页（0-based）；只在首次挂载生效，自动夹到 [0, pages.length-1]。 */
    initialPage?: number;
    /** pager 切页回调（0-based）；原有的 pageView.onPageSelected 仍会先执行。 */
    onPageChanged?: (pageIndex: number) => void;
}

export const TimeScheduleView = memo(function TimeScheduleView(props: TimeScheduleViewProps) {
    const {store} = useCourseData();
    const {AnimatedPagerView, ref, ...rest} = props.pageView;
    const startDay = props.startDay ?? moment();
    const realCurrentWeek = getWeekOfDate(moment(), startDay);
    const lastPage = Math.max(0, rest.pages.length - 1);
    const requestedInitialPage =
        typeof props.initialPage === "number" && Number.isFinite(props.initialPage)
            ? props.initialPage
            : realCurrentWeek - 1;
    const initialPage = Math.min(lastPage, Math.max(0, Math.trunc(requestedInitialPage)));

    const paletteName = (store(s => s.theme.palette) as PaletteName) || "macaron";
    const customColors = store(s => s.theme.customColors) || {};
    const flatItems = useMemo(() => props.scheduleItems.flatMap(td => td.data), [props.scheduleItems]);
    const colorMap = useMemo(
        () => buildColorMap(flatItems, paletteName, customColors),
        [flatItems, paletteName, customColors],
    );

    const handleLongPress = useCallback(() => {
        Vibration.vibrate(10);
        // 开学前 realCurrentWeek 可能为 0/负数，必须夹到有效页范围。
        ref.current?.setPage(Math.min(lastPage, Math.max(0, realCurrentWeek - 1)));
    }, [lastPage, realCurrentWeek, ref]);

    const handlePageSelected = useCallback(
        (event: PagerViewOnPageSelectedEvent) => {
            rest.onPageSelected?.(event);
            props.onPageChanged?.(event.nativeEvent.position);
        },
        [rest.onPageSelected, props.onPageChanged],
    );

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
                initialPage={initialPage}
                layoutDirection="ltr"
                scrollEnabled={rest.scrollEnabled}
                pageMargin={10}
                onPageSelected={handlePageSelected}
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
