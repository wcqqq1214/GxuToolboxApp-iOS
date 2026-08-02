import {BaseColor, Color} from "@/shared/color.ts";
import {createContext, useCallback, useEffect, useState} from "react";
import {StyleSheet, ToastAndroid} from "react-native";
import {store} from "@/core/store.ts";
import {SchoolTerms, SchoolTermValue, SchoolValue, SchoolYears, SchoolYearValue} from "@/type/global.ts";
import {
    ClassScheduleQueryRes,
    CourseScheduleQueryRes,
    CourseSelectionListRes,
    GetCourseScheduleListRes,
    PhyExpQueryRes,
} from "@/type/api/infoQuery/classScheduleAPI.ts";
import {http, objectToFormUrlEncoded} from "@/core/http.ts";
import {defaultYear} from "@/js/jw/infoQuery.ts";
import {Course, CourseListTypeId, PhyExp, PracticalCourse} from "@/type/infoQuery/course/course.ts";
import {authApi} from "@/js/auth/auth.ts";
import axios from "axios";
import {EngTrainingScheduleRes} from "@/type/api/infoQuery/EngTraining.ts";
import {CourseScheduleClass} from "@/class/jw/course.ts";
import {ensureJwAuthenticated} from "@/core/auth/Jw/JwMachine.ts";

export const CourseScheduleData = {
    courseInfoVisible: {
        name: true,
        position: true,
        teacher: true,
    },
    startDay: "2025-02-24",
    randomColor: [
        BaseColor.pink,
        BaseColor.lightgreen,
        BaseColor.skyblue,
        BaseColor.orange,
        BaseColor.tan,
        BaseColor.sandybrown,
        BaseColor.navy,
        BaseColor.maroon,
        BaseColor.mediumspringgreen,
        BaseColor.slateblue,
        BaseColor.yellowgreen,
        BaseColor.red,
        BaseColor.yellow,
        BaseColor.gold,
        BaseColor.lightskyblue,
        BaseColor.lightsteelblue,
        BaseColor.limegreen,
        BaseColor.mediumaquamarine,
        BaseColor.mediumblue,
    ],
    weekdayList: ["一", "二", "三", "四", "五", "六", "日"],
    timeSpanList: [
        "08:00\n08:45",
        "08:55\n09:40",
        "10:00\n10:45",
        "10:55\n11:40",
        "14:30\n15:15",
        "15:20\n16:05",
        "16:25\n17:10",
        "17:15\n18:00",
        "18:10\n18:55",
        "18:45\n19:30",
        "19:40\n20:25",
        "20:30\n21:15",
        "21:20\n22:05",
    ],
};
export type CourseScheduleDataType = typeof CourseScheduleData;
export type CourseScheduleStyleType = ReturnType<typeof generateCourseScheduleStyle>;

export interface CourseThemeConfig {
    timeSpanHeight: number;
    weekdayHeight: number;
    courseItemMargin: number;
    courseItemBorderWidth: number;
    courseColor: Record<string, string>;
    palette?: import("@/features/courseSchedule/utils/colorPalette.ts").PaletteName;
    customColors?: Record<string, string>;
}

export function generateCourseScheduleStyle(config: CourseThemeConfig, theme: any) {
    return StyleSheet.create({
        timeSpanHighLight: {
            position: "absolute",
            height: config.timeSpanHeight,
            flex: 1,
            width: "100%",
            left: 0,
            overflow: "hidden",
            borderRadius: 5,
            backgroundColor: Color(theme.colors.primary).setAlpha(0.1).rgbaString,
        },
        courseSchedule: {
            flex: 1,
            flexDirection: "row",
        },
        timeSpanContainer: {
            flex: undefined,
        },
        weekdayContainer: {
            flex: 1,
            justifyContent: "flex-start",
            borderRadius: 5,
            marginVertical: 10,
        },
        weekdayItem: {
            alignItems: "center",
            justifyContent: "center",
            height: config.weekdayHeight,
        },
        weekdayText: {
            fontSize: 12,
            textAlign: "center",
            color: theme.colors.grey2,
        },
        timeSpanItem: {
            height: config.timeSpanHeight,
        },
        timeSpanText: {
            textAlign: "center",
            fontSize: 10,
            color: theme.colors.grey2,
        },
        courseItem: {
            overflow: "hidden",
            width: "96%",
            marginHorizontal: "2%",
            borderRadius: 5,
            borderWidth: config.courseItemBorderWidth,
            borderStyle: "solid",
            paddingVertical: 5,
            paddingHorizontal: 2,
        },
        practicalCourseItem: {
            gap: 3,
            marginHorizontal: "1%",
            paddingHorizontal: 5,
            marginTop: 10,
        },
    });
}

export function useCourseScheduleData() {
    const [courseScheduleData, setCourseScheduleData] = useState<typeof CourseScheduleData>(CourseScheduleData);
    const updateCourseScheduleData = useCallback(
        async (data: Partial<typeof CourseScheduleData>) => {
            const newData = {
                ...courseScheduleData,
                ...data,
            };
            setCourseScheduleData(newData);
            await store.save({key: "courseScheduleSetting", data: newData});
        },
        [courseScheduleData],
    );

    useEffect(() => {
        store
            .load({key: "courseScheduleSetting"})
            .then(data => {
                setCourseScheduleData(prevData => ({
                    ...prevData,
                    ...data,
                }));
            })
            .catch(err => {
                console.log("加载课程表设置失败:", err);
            });
    }, []);

    return {courseScheduleData, updateCourseScheduleData};
}

export const CourseScheduleContext = createContext<{
    courseScheduleData: typeof CourseScheduleData;
    courseScheduleStyle: ReturnType<typeof generateCourseScheduleStyle>;
    updateCourseScheduleData: (data: Partial<typeof CourseScheduleData>) => void;
} | null>(null);

async function randomCourseColor(courseList: (Course | PracticalCourse)[]) {
    const courseData = await store.load({key: "courseScheduleStore"}).catch(() => null);
    const courseColor: Record<string, string> = courseData?.theme?.courseColor ?? {};
    let hasChange = false;
    courseList.forEach(course => {
        if (!courseColor[course.kcmc]) {
            let randomNum = Math.floor(Math.random() * CourseScheduleData.randomColor.length);
            course.backgroundColor = courseColor[course.kcmc] = CourseScheduleData.randomColor[randomNum];
            hasChange = true;
        } else {
            course.backgroundColor = courseColor[course.kcmc];
        }
    });
    if (hasChange) {
        await store.save({
            key: "courseScheduleStore",
            data: {...courseData, theme: {...courseData?.theme, courseColor}},
        });
    }
}

export const courseApi = {
    /**
     * 获取个人课表
     * @param year 学年
     * @param term 学期
     */
    getCourseSchedule: async (
        year: number | SchoolYearValue,
        term: SchoolTermValue,
    ): Promise<CourseScheduleClass | undefined> => {
        const schoolYear = SchoolYears.find(v => +v[0] === year) ?? SchoolYears.find(v => +v[0] === defaultYear)!;
        if (!(await ensureJwAuthenticated())) {
            return;
        }
        const reqBody = objectToFormUrlEncoded({
            xnm: schoolYear[0],
            xqm: term ?? SchoolTerms[0][0],
        });
        const res = await http.post<CourseScheduleQueryRes>("/kbcx/xskbcx_cxXsgrkb.html", reqBody);
        if (typeof res.data === "object") {
            await randomCourseColor(res.data.kbList);
            await randomCourseColor(res.data.sjkList);
            return new CourseScheduleClass(res.data);
        } else {
            ToastAndroid.show("获取课表信息失败", ToastAndroid.SHORT);
            return;
        }
    },
    /**
     * 获取班级课表列表，参数可为空
     * @param year 学年
     * @param term 学期
     * @param schoolId 学院id
     * @param subjectId 专业id
     * @param grade 年级
     * @param classId 班级id
     */
    getClassCourseScheduleList: async (
        year?: SchoolYearValue,
        term?: SchoolTermValue,
        schoolId?: SchoolValue,
        subjectId?: string,
        grade?: number,
        classId?: string,
    ): Promise<GetCourseScheduleListRes> => {
        const reqBody = objectToFormUrlEncoded({
            xnm: year,
            xqm: term,
            njdm_id: grade,
            jg_id: schoolId,
            zyh_id: subjectId,
            bh_id: classId,
            queryModel: {
                showCount: 1000,
            },
        });
        const res = await http.post("/kbdy/bjkbdy_cxBjkbdyTjkbList.html", reqBody);
        return res.data;
    },
    /**
     * 获取班级课表内容
     * @param year 学年
     * @param term 学期
     * @param schoolId 学院id
     * @param subjectId 专业id
     * @param grade 年级
     * @param classId 班级id
     */
    getClassCourseSchedule: async (
        year: SchoolYearValue,
        term: SchoolTermValue,
        schoolId: SchoolValue,
        subjectId: string,
        grade: number,
        classId: string,
    ): Promise<ClassScheduleQueryRes | null> => {
        const reqBody = objectToFormUrlEncoded({
            xnm: year,
            xqm: term,
            njdm_id: grade,
            jg_id: schoolId,
            zyh_id: subjectId,
            bh_id: classId,
            // 不确定，但得有
            tjkbzdm: 1,
            tjkbzxsdm: 0,
        });
        const res = await http.post<ClassScheduleQueryRes>("/kbdy/bjkbdy_cxBjKb.html", reqBody);
        if (typeof res.data === "object") {
            await randomCourseColor(res.data.kbList);
            await randomCourseColor(res.data.sjkList);
            return res.data;
        } else {
            ToastAndroid.show("获取课表信息失败", ToastAndroid.SHORT);
            return null;
        }
    },
    getClassCourseScheduleNew: async (
        year: SchoolYearValue,
        term: SchoolTermValue,
        bh_id: number,
    ): Promise<ClassScheduleQueryRes | null> => {
        const reqBody = objectToFormUrlEncoded({
            xnm: year,
            xqm: term,
            bh_id: bh_id,
        });
        const res = await http.post<ClassScheduleQueryRes>("/kbdy/bjkbdy_cxBjKb.html", reqBody);
        if (typeof res.data === "object") {
            await randomCourseColor(res.data.kbList);
            await randomCourseColor(res.data.sjkList);
            return res.data;
        } else {
            ToastAndroid.show("获取课表信息失败", ToastAndroid.SHORT);
            return null;
        }
    },

    /**
     * 获取物理实验课列表
     */
    getPhyExpList: async (): Promise<PhyExpQueryRes> => {
        // 登录物理实验平台服务
        await authApi.loginService("http://pec.gxu.edu.cn//caslogin.aspx");
        const res = await http.post<{d: string}>(
            "https://pec.gxu.edu.cn/LMSmini/teacher/UI/wxInterface/syjx.asmx/getRuleManage",
            {
                page: 1,
                limit: 100,
            },
            {headers: {"Content-Type": "application/json"}},
        );
        const data: PhyExpQueryRes = JSON.parse(res.data.d);
        // 将实验课键名转小写
        data.data = data.data.map(
            item => Object.fromEntries(Object.entries(item).map(([key, _]) => [key.toLowerCase(), _])) as PhyExp,
        );
        return data;
    },

    // 选课相关
    courseSelection: {
        getList: async (
            year: SchoolYearValue,
            term: SchoolTermValue,
            type: CourseListTypeId,
            page: number = 1,
            pageSize: number = 20,
            keyword?: string,
        ) => {
            const reqBody = objectToFormUrlEncoded({
                xkxnm: year,
                xkxqm: term,
                kklxdm: type,
                kspage: page,
                jspage: pageSize,
                xkkz_id: "47F02D572DC2768EE063020410AC6B75", // TODO换成自动获取方式
                filter_list: [keyword],
            });
            const res = await http.post<CourseSelectionListRes>("/xsxk/zzxkyzb_cxZzxkYzbPartDisplay.html", reqBody);
            if (typeof res.data === "object") {
                return res.data;
            } else {
                ToastAndroid.show("获取选课列表信息失败", ToastAndroid.SHORT);
                return null;
            }
        },
    },

    // 工程训练中心课表相关（金工实训），Engineering training
    engTraining: {
        /**
         * 登录工程训练中心-学生服务
         */
        getPersonalExpList: async (): Promise<EngTrainingScheduleRes> => {
            const authRes = await authApi.loginEngTraining();
            if (!authRes || !authRes.data) return;
            const token = authRes.data.token;
            const res = await axios.get<EngTrainingScheduleRes>(
                "http://xlzxms.gxu.edu.cn/api/course-newedition-server/course/course/arrange/stuPersonalArrangeTable",
                {
                    headers: {
                        authorization: token,
                    },
                },
            );
            return res.data;
        },
    },
};
