import {ReactNode} from "react";
import moment from "moment";

export interface TimeScheduleItemData<T = any> {
    /** 元素数据 */
    data: T[];
    /** 元素渲染 */
    itemRender?: (item: T, day: moment.Moment, week: number) => ReactNode;
    /** 判断元素是否在当天渲染 */
    isItemShow?: (item: T, day: moment.Moment, week: number) => boolean;
    /** 判断两项是否应合并到同一个冲突栈 */
    isItemStack?: (a: T, b: T, ori: T[], day: moment.Moment, week: number) => boolean;
    /** 冲突栈渲染：同一时段重叠的多项数据合并渲染 */
    stackRender?: (items: T[], day: moment.Moment, week: number, timeRange: [number, number]) => ReactNode;
    /** 是否需要应用调课，默认 true */
    needShift?: boolean;
}

export interface ScheduleTableItem<T = any, K extends string = string> {
    id: string;
    week: number;
    day: 1 | 2 | 3 | 4 | 5 | 6 | 7;
    begin: 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13;
    end: 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13;
    title: string;
    subtitle?: string;
    location?: string;
    teacher?: string;
    color?: string;
    kind?: K;
    seat?: string;
    status?: number;
    isShift?: boolean;
    qq?: string;
    raw?: T;
}
