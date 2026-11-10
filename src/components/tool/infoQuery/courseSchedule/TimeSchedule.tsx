import {StyleProp, StyleSheet, TextStyle, View, ViewStyle} from "react-native";
import moment from "moment/moment";
import {Color} from "@/shared/color.ts";
import {Text, useTheme} from "@rneui/themed";
import {type ReactNode, useEffect, useMemo, useState} from "react";
import Flex from "@/components/un-ui/Flex.tsx";
import {useCourseData} from "@/hooks/useCourseData.ts";
import {useUserConfig} from "@/hooks/useUserConfig.ts";
import {TimeScheduleItemData} from "@/features/courseSchedule/type/schedule.ts";
import {useShift} from "@/features/courseSchedule/hooks/detail/useShift.ts";
import {getWeekOfDate} from "@/features/courseSchedule/utils/weekOfDate.ts";
import {layoutScheduleBlocks} from "@/features/courseSchedule/utils/layoutScheduleBlocks";

interface RenderBlock {
    key: string;
    begin: number;
    end: number;
    content: ReactNode;
    avoidOverlap: boolean;
}

function groupByTimeOverlap<T>(
    items: T[],
    isStack: ((a: T, b: T, ori: T[], day: moment.Moment, week: number) => boolean) | undefined,
    day: moment.Moment,
    week: number,
): T[][] {
    if (!isStack) return items.map(item => [item]);
    const groups: T[][] = [];
    for (const item of items) {
        const target = groups.find(g => g.some(x => isStack(item, x, [...g], day, week)));
        if (target) {
            target.push(item);
        } else {
            groups.push([item]);
        }
    }
    return groups;
}

export interface TimeScheduleProps<T = any> {
    /** 学期的第一天 */
    startDay?: moment.MomentInput;
    /** 课表当前周，1-20 */
    currentWeek?: number;
    /** 是否显示表头日期，如果不显示日期，左上角显示为周数，否则为第一天所在月份 */
    showDate?: boolean;
    /** 是否显示时间段高亮 */
    showTimeSpanHighlight?: boolean;
    /** 时候高亮今日，通过第一天和周数计算后和系统时间进行比对 */
    showDayHighlight?: boolean;

    scheduleItems: TimeScheduleItemData<T>[];
}

export function TimeSchedule<T = any>(props: TimeScheduleProps<T>) {
    const {store: ucStore} = useUserConfig();
    const {store, courseScheduleStyle} = useCourseData();
    const weekdayList = store(s => s.weekdayList);
    const timeSpanList = store(s => s.timeSpanList);
    const timeSpanHeight = store(s => s.theme.timeSpanHeight);
    const weekdayHeight = store(s => s.theme.weekdayHeight);
    const {theme} = useTheme();
    const shiftStore = useShift().store;
    const shiftRules = shiftStore(s => s.shiftRules);
    const {shiftMap, workDates, restDates} = useMemo(() => {
        const map = new Map<string, string>();
        const work = new Set<string>();
        const rest = new Set<string>();
        for (const [workDate, restDate] of shiftRules) {
            // 单向登记：只有补课日需要被替换成被补日。
            // 调休日（放假那天）整列不排课，不再反向去取配对日的元素。
            map.set(workDate, restDate);
            work.add(workDate);
            rest.add(restDate);
        }
        return {shiftMap: map, workDates: work, restDates: rest};
    }, [shiftRules]);

    const defaultStartDay = ucStore(s => s.jw.startDay);
    const startDay = moment(props.startDay ?? defaultStartDay);
    const [currentTime, setCurrentTime] = useState(moment().format());
    const currentWeek = props.currentWeek ?? getWeekOfDate(moment(), startDay);
    const currentTimeSpan = getCurrentTimeSpan();
    useEffect(() => {
        // 时间段刷新定时器
        if (props.showTimeSpanHighlight) {
            const id = setInterval(() => setCurrentTime(moment().format()), 5000);
            return () => {
                clearInterval(id);
            };
        }
    }, [props.showTimeSpanHighlight]);

    // 计算当前时间段
    function getCurrentTimeSpan() {
        let res = -1;
        timeSpanList.forEach((timeSpan, index, list) => {
            const start = index > 0 ? list[index - 1].split("\n")[1] : "00:00";
            const end = timeSpan.split("\n")[1];
            const startTime = moment(start, "hh:mm");
            const endTime = moment(end, "hh:mm");
            if (moment(currentTime).isBetween(startTime, endTime, undefined, "[]")) {
                res = index;
                return;
            }
        });
        return res > -1 ? res : null;
    }

    // 计算时间段的Top
    const timeSpanHighLightTop = {
        top: weekdayHeight + (currentTimeSpan ?? 1) * timeSpanHeight + 10,
    };

    // 生成短的时间段元素列表
    const shortTimeSpanList: [number | string, string][] = Array(Math.ceil(timeSpanList.length / 2))
        .fill(0)
        .map((_, index) =>
            timeSpanList[index * 2 + 1] !== undefined
                ? [
                      `${index * 2 + 1} - ${index * 2 + 2}`,
                      timeSpanList[index * 2].split("\n")[0] + "\n" + timeSpanList[index * 2 + 1].split("\n")[1],
                  ]
                : [index * 2 + 1, timeSpanList[index * 2]],
        );

    /**
     * 渲染某数据源在指定「日期 + 教学周」下应显示的元素。
     *
     * 把 day/week 做成显式入参，是为了让补课日列复用同一套流程渲染两组元素：
     * 主组取被补日（effectiveDay），附加组取本列自然日期（currentDay）。
     * 冲突栈（isItemStack / stackRender）只在各自组内合并，两组之间不会互相吞并。
     *
     * 入参：
     *   - td        数据源配置
     *   - tdIndex   td 在 scheduleItems 中的下标，与 keyPrefix 一起保证 React key 唯一
     *   - keyPrefix 组别前缀（"main" / "pre"）
     *   - day       传给 isItemShow / itemRender / stackRender 的日期
     *   - week      传给 isItemShow / stackRender 的教学周
     */
    function renderItems(
        td: TimeScheduleItemData<T>,
        tdIndex: number,
        keyPrefix: string,
        day: moment.Moment,
        week: number,
    ): RenderBlock[] {
        const visibleItems = td.data.filter(item => td.isItemShow?.(item, day, week));
        // 按时段重叠分组
        const groups = groupByTimeOverlap(visibleItems, td.isItemStack, day, week);
        return groups.map((group, gi) => {
            const timeRange: [number, number] = [
                Math.min(...group.map(g => (g as any).begin ?? 1)),
                Math.max(...group.map(g => (g as any).end ?? 1)),
            ];
            return {
                key: `${tdIndex}-${keyPrefix}-${gi}`,
                begin: timeRange[0],
                end: timeRange[1],
                avoidOverlap: td.avoidOverlap === true,
                content:
                    group.length > 1
                        ? (td.stackRender?.(group, day, week, timeRange) ?? null)
                        : group.map((item, ii) => <View key={ii}>{td.itemRender?.(item, day, week)}</View>),
            };
        });
    }

    return (
        <View style={courseScheduleStyle.courseSchedule}>
            {/*时间段高亮*/}
            {typeof currentTimeSpan === "number" && props.showTimeSpanHighlight && (
                <View style={[timeSpanHighLightTop, courseScheduleStyle.timeSpanHighLight]} />
            )}
            {/*时间表渲染*/}
            <View style={[courseScheduleStyle.weekdayContainer, courseScheduleStyle.timeSpanContainer]}>
                <View style={courseScheduleStyle.weekdayItem}>
                    {props.showDate ? (
                        <>
                            <Text style={courseScheduleStyle.weekdayText}>
                                {startDay.clone().add(currentWeek, "w").month() + 1 + "月"}
                            </Text>
                            <Text style={courseScheduleStyle.weekdayText}>{`第${currentWeek}周`}</Text>
                        </>
                    ) : (
                        <Text style={courseScheduleStyle.weekdayText}>{`第${currentWeek}周`}</Text>
                    )}
                </View>
                {/*时间段*/}
                {timeSpanHeight > 40
                    ? timeSpanList.map((time, index) => (
                          <Flex
                              inline
                              key={`timespan-${index}`}
                              style={courseScheduleStyle.timeSpanItem}
                              justify="center">
                              <Text style={courseScheduleStyle.timeSpanText}>{`${index + 1}\n${time}`}</Text>
                          </Flex>
                      ))
                    : shortTimeSpanList.map((value, index) => (
                          <Flex
                              inline
                              key={`timespan-${index}`}
                              style={[courseScheduleStyle.timeSpanItem, {height: timeSpanHeight * 2}]}
                              justify="center">
                              <Text style={courseScheduleStyle.timeSpanText}>{`${value[0]}\n${value[1]}`}</Text>
                          </Flex>
                      ))}
            </View>
            {/*课表*/}
            {(weekdayList ?? []).map((weekday, index) => {
                // 判断是否为当天
                const currentDay = startDay.clone().add({
                    week: currentWeek - 1,
                    day: index,
                });
                const dateKey = currentDay.format("YYYY-MM-DD");
                // 补课日：这一天改上被补日的课；调休日：这一天放假，整列不排课
                const isWorkDay = workDates.has(dateKey);
                const isRestDay = restDates.has(dateKey);
                const shiftedDate = isWorkDay ? shiftMap.get(dateKey) : undefined;
                const effectiveDay = shiftedDate ? moment(shiftedDate) : currentDay;
                const itemStyle = StyleSheet.create({
                    activeContainer: {
                        backgroundColor: Color(theme.colors.primary).setAlpha(0.2).rgbaString,
                        height: timeSpanHeight * (timeSpanHeight <= 40 ? 14 : 13) + weekdayHeight,
                    },
                    activeText: {
                        color: Color.mix(theme.colors.black, theme.colors.primary, 0.5).rgbaString,
                    },
                });
                // 生成合并的样式
                const weekdayContainerStyle: StyleProp<ViewStyle> = [courseScheduleStyle.weekdayContainer];
                const weekdayTextStyle: StyleProp<TextStyle> = [courseScheduleStyle.weekdayText];
                if (currentDay.isSame(moment(), "day") && props.showDayHighlight) {
                    weekdayContainerStyle.push(itemStyle.activeContainer);
                    weekdayTextStyle.push(itemStyle.activeText);
                }
                return (
                    // 当日课程渲染
                    <View style={weekdayContainerStyle} key={`day-${currentWeek}-${weekday}-${index}`}>
                        {/* 日期部分 */}
                        <View style={courseScheduleStyle.weekdayItem}>
                            <Text style={weekdayTextStyle}>
                                {(() => {
                                    const shiftLabel = workDates.has(dateKey)
                                        ? "(补)"
                                        : restDates.has(dateKey)
                                          ? "(休)"
                                          : "";
                                    return props.showDate
                                        ? `${weekday}${shiftLabel}\n${currentDay.month() + 1}-${currentDay.date()}`
                                        : `${weekday}${shiftLabel}`;
                                })()}
                            </Text>
                        </View>
                        {(() => {
                            const blocks = (props.scheduleItems ?? []).flatMap((td, tdIndex) => {
                                const applyShift = td.needShift !== false;
                                // 调休日（放假那天）不排课：参与调课的数据源整列跳过
                                if (applyShift && isRestDay) return [];

                                // 参与调课的数据源取被补日与其所在教学周，其余取本列自然日期与当前周
                                const targetDay = applyShift ? effectiveDay : currentDay;
                                const targetWeek = applyShift ? getWeekOfDate(effectiveDay, startDay) : currentWeek;

                                return [
                                    ...renderItems(td, tdIndex, "main", targetDay, targetWeek),
                                    ...(applyShift && isWorkDay && td.showPreShiftItems
                                        ? renderItems(td, tdIndex, "pre", currentDay, currentWeek)
                                        : []),
                                ];
                            });
                            const positions = new Map(
                                layoutScheduleBlocks(blocks.filter(block => block.avoidOverlap)).map(position => [
                                    position.item,
                                    position,
                                ]),
                            );
                            return blocks.map(block => {
                                const position = positions.get(block);
                                const count = position?.columnCount ?? 1;
                                return (
                                    <View
                                        key={block.key}
                                        style={{
                                            width: `${100 / count}%`,
                                            marginLeft: `${((position?.column ?? 0) * 100) / count}%`,
                                        }}>
                                        {block.content}
                                    </View>
                                );
                            });
                        })()}
                    </View>
                );
            })}
        </View>
    );
}
