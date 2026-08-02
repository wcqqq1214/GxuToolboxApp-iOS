import {SchoolLabel, SchoolValue} from "@/type/global.ts";

export interface Subject {
    /** 学院代码 */
    jg_id: SchoolValue;
    /** 学院名称 */
    jgmc: SchoolLabel;
    /**  */
    jgpxzd: string;
    /** 专业代码 */
    zyh: string;
    /** 专业代码 */
    zyh_id: string;
    /** 专业名称和专业代码 */
    zymc: string;
}

export interface Class extends Subject {
    /** 班级代号 */
    bh: string;
    /** 班级代号 */
    bh_id: string;
    /** 班级名称 */
    bj: string;
    /** 年级id */
    njdm_id: string;
    /** 年级名称 */
    njmc: string;
    /**  */
    xqh_id: string;
}

export interface UserInfo {
    /** 名字 */
    name: string;
    /** 学院 */
    school: string;
    /** 班级 */
    class: string;
    /** 年级 */
    grade: number;
    /** 专业 */
    subject: string;
    /** 专业Id */
    subject_id: string;
}

export interface Week {
    /** 周数 */
    zs: string;
    /** 周数名称 */
    zsmc: string;
    /** 日期（yyyy-MM-dd/yyyy-MM-dd） */
    rq: string;
    /** 周数和日期，例：1(2025-02-24至2025-03-02) */
    zcrq: string;
}
