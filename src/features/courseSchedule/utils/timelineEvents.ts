import moment from "moment";
import type {ScheduleTableItem, TimeScheduleItemData} from "../type/schedule";
import {getWeekOfDate} from "./weekOfDate";

/** 将各图层展开为实际日期上的日程，供下一项提示使用，保持与网格的调课规则一致。 */
export function timelineEvents(
    layers: readonly TimeScheduleItemData<ScheduleTableItem>[],
    startDay: moment.Moment,
    shiftRules: readonly (readonly [string, string])[],
): ScheduleTableItem[] {
    const workDates = new Set(shiftRules.map(rule => rule[0]));
    const restDates = new Set(shiftRules.map(rule => rule[1]));
    return layers.flatMap(layer =>
        layer.data.flatMap(item => {
            if (layer.needShift === false) return [item];
            const date = startDay
                .clone()
                .startOf("day")
                .add((item.week - 1) * 7 + item.day - 1, "days");
            const key = date.format("YYYY-MM-DD");
            const events = !restDates.has(key) && (!workDates.has(key) || layer.showPreShiftItems) ? [item] : [];
            for (const [workDate, restDate] of shiftRules) {
                if (restDate !== key) continue;
                const day = moment(workDate);
                events.push({
                    ...item,
                    id: `${item.id}:shift:${workDate}`,
                    week: getWeekOfDate(day, startDay),
                    day: day.isoWeekday() as ScheduleTableItem["day"],
                    isShift: true,
                });
            }
            return events;
        }),
    );
}
