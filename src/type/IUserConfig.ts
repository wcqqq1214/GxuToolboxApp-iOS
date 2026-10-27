import {PressableAndroidRippleConfig} from "react-native";
import {SchoolTerms, SchoolTermValue, SchoolYearValue} from "@/type/global.ts";
import {Course} from "@/type/infoQuery/course/course.ts";
import {DefaultUserTheme} from "@/shared/theme.ts";
import moment from "moment";
import {IUserActivity} from "@/type/app/activity.ts";

export interface IUserConfig {
    /** 主题相关配置 */
    theme: IUserTheme;
    /** 部分教务配置 */
    jw: IUserJwConfig;
    /** 偏好配置 */
    preference: IUserPreference;
    /** 各学期日程 */
    activity: IUserActivity;
    /** 开发者模式 */
    devMode: boolean;
}

/** 用户教务配置 */
export interface IUserJwConfig {
    /** 学年 */
    year: SchoolYearValue | number;
    /** 学期 */
    term: SchoolTermValue;
    /** 当前课表起始 */
    startDay: string;
}

/** 偏好配置 */
export interface IUserPreference {
    /** 课程元素详情 */
    courseDetail: Record<keyof Omit<Course, "queryModel" | "userModel" | "backgroundColor">, IDetailItem>;
}

/** 元素详情元素 */
export interface IDetailItem {
    /** 是否展示 */
    show: boolean;
    /** 对应的标签 */
    label: string;
}

/** 用户主题配置 */
export interface IUserTheme {
    /** 主题色 */
    primaryColor: string;
    /** 背景图链接 */
    bgUrl: string;
    /** 背景透明度 */
    bgOpacity: number;
    ripple: PressableAndroidRippleConfig;
}

export const defaultUserConfig: IUserConfig = {
    theme: DefaultUserTheme,
    jw: {
        year: ("" +
            (moment().isBefore(moment("8", "M"), "M") ? moment().year() - 1 : moment().year())) as SchoolYearValue,
        term: moment().isBetween(moment("02", "MM"), moment("07", "MM"), "month", "[]")
            ? SchoolTerms[1][0]
            : SchoolTerms[0][0],
        startDay: "2025-09-08",
    },
    activity: {
        data: [],
    },
    devMode: false,
    preference: {
        courseDetail: {
            kcmc: {label: "课程名称", show: true},
            cdmc: {label: "地点", show: true},
            khfsmc: {label: "考核方式", show: true},
            xm: {label: "上课教师", show: true},
            xf: {label: "学分", show: true},
            bklxdjmc: {label: "", show: false},
            cd_id: {label: "", show: false},
            cdbh: {label: "", show: false},
            cdlbmc: {label: "", show: false},
            cxbj: {label: "", show: false},
            cxbjmc: {label: "", show: false},
            date: {label: "", show: false},
            dateDigit: {label: "", show: false},
            dateDigitSeparator: {label: "", show: false},
            day: {label: "", show: false},
            jc: {label: "", show: false},
            jcor: {label: "", show: false},
            jcs: {label: "", show: false},
            jgh_id: {label: "", show: false},
            jgpxzd: {label: "", show: false},
            jxb_id: {label: "", show: false},
            jxbmc: {label: "", show: false},
            jxbsftkbj: {label: "", show: false},
            jxbzc: {label: "", show: false},
            kcbj: {label: "", show: false},
            kch: {label: "", show: false},
            kch_id: {label: "", show: false},
            kclb: {label: "", show: false},
            kcxszc: {label: "", show: false},
            kcxz: {label: "", show: false},
            kczxs: {label: "", show: false},
            kkzt: {label: "", show: false},
            lh: {label: "", show: false},
            listnav: {label: "", show: false},
            localeKey: {label: "", show: false},
            month: {label: "", show: false},
            oldjc: {label: "", show: false},
            oldzc: {label: "", show: false},
            pageTotal: {label: "", show: false},
            pageable: {label: "", show: false},
            pkbj: {label: "", show: false},
            px: {label: "", show: false},
            qqqh: {label: "", show: false},
            rangeable: {label: "", show: false},
            rk: {label: "", show: false},
            rsdzjs: {label: "", show: false},
            sfjf: {label: "", show: false},
            skfsmc: {label: "", show: false},
            sxbj: {label: "", show: false},
            totalResult: {label: "", show: false},
            xkbz: {label: "", show: false},
            xkrs: {label: "选课人数", show: true},
            xnm: {label: "", show: false},
            xqdm: {label: "", show: false},
            xqh1: {label: "", show: false},
            xqh_id: {label: "", show: false},
            xqj: {label: "", show: false},
            xqjmc: {label: "", show: false},
            xqm: {label: "", show: false},
            xqmc: {label: "", show: false},
            xsdm: {label: "", show: false},
            xslxbj: {label: "", show: false},
            year: {label: "", show: false},
            zcd: {label: "", show: false},
            zcmc: {label: "", show: false},
            zfjmc: {label: "", show: false},
            zhxs: {label: "", show: false},
            zxs: {label: "", show: false},
            zxxx: {label: "", show: false},
            zyfxmc: {label: "", show: false},
            zyhxkcbj: {label: "", show: false},
            zzmm: {label: "", show: false},
            zzrl: {label: "座位数", show: true},
        },
    },
};
