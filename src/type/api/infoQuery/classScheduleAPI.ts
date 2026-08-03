import {
    CourseSchedule,
    CourseSelectionListItem,
    PhyExp,
} from "@/type/infoQuery/course/course.ts";
import {Class} from "@/type/infoQuery/base.ts";
import {PageModel, QueryResRoot} from "@/type/global.ts";

export interface GetCourseScheduleListRes extends QueryResRoot<CourseSchedule & Class & PageModel> {}

/** 物理实验课表查询返回 */
export interface PhyExpQueryRes {
    code: number;
    msg: string;
    count: number;
    data: PhyExp[];
}

export interface CourseSelectionListRes {
    tmpList: Array<CourseSelectionListItem>;
    sfxsjc: string;
};
