import {useEffect, useState} from "react";
import moment from "moment";
import {useJwAccount} from "@/core/auth/Jw/hooks/useJwAccount.ts";
import {userProfileRepo} from "@/core/repo/userProfileRepo.ts";
import {classScheduleApi} from "@/features/classCourseSchedule/api";
import type {ClassDetail} from "gxu-tool-adapters/jw";

export const useFilter = ({year, term}: {year: string | number; term: string | number}) => {
    const {username} = useJwAccount();

    const [school, setSchool] = useState("");
    const [major, setMajor] = useState("");
    const [grade, setGrade] = useState<string>(String(moment().year()));
    const [classId, setClassId] = useState("");

    // 保持 [id, name] 形式以兼容 UI 的 Picker 渲染
    const [schoolList, setSchoolList] = useState<string[][]>([]);
    const [majorList, setMajorList] = useState<string[][]>([]);
    // 班级列表改存 ClassDetail：每条带 schoolId/majorId/grade/classId，选中后用其自带 grade 下钻查课表
    const [classList, setClassList] = useState<ClassDetail[]>([]);

    // 选中班级的完整定位参数。查课表用它的 major/grade/classId 而非外部 Picker 的 grade，
    // 这样年级选“全部”时仍能用班级各自的 grade 查到课表
    const selectedClass = classList.find(c => c.classId === classId);

    useEffect(() => {
        if (!username) return;
        let cancelled = false;

        (async () => {
            try {
                const info = await userProfileRepo.get(username);
                if (!info || cancelled) return;

                const schools = await classScheduleApi.fetchSchools();
                if (cancelled) return;
                if (schools.length === 0) return;
                setSchoolList(schools.map(s => [s.id, s.name]));

                // 通过学院名反查对应的代码
                const collegeName = info.college ?? schools[0].name;
                const schoolIndex = schools.findIndex(v => v.name === collegeName);
                const school = schools[Math.max(0, schoolIndex)].id;

                // 用户所在的这一届
                const grade = info.grade ? info.grade : String(moment().year());

                // 通过学院代码查该学院有什么专业（专业列表随年级变化，故传入 grade）
                const majorList = (await classScheduleApi.fetchMajors(grade, school)).map(m => [
                    m.majorId,
                    m.majorName,
                ]);
                if (cancelled) return;
                setMajorList(majorList);

                // 用户的专业对应的代码（列表为空时降级为空串，避免后续下标越界）
                const majorIndex = majorList.findIndex(v => v[1].indexOf(info.major) > -1);
                const major = majorList[Math.max(0, majorIndex)]?.[0] ?? "";

                // 班级列表用 class-schedules 接口，每条带完整定位参数（含 grade）
                let classList: ClassDetail[] = [];
                if (major) {
                    classList = await classScheduleApi.fetchFullClasses(
                        String(year),
                        String(term),
                        school,
                        major,
                        grade,
                    );
                    if (cancelled) return;
                }

                // 用户所在的班级
                const newClassIndex = classList.findIndex(v => v.className.indexOf(info.class_name) > -1);
                const classId = classList[Math.max(0, newClassIndex)]?.classId;

                setSchool(school);
                setMajor(major);
                setGrade(grade);
                setClassList(classList);
                setClassId(classId);
            } catch (e) {
                console.warn("初始化班级课表筛选条件失败", e);
            }
        })();

        return () => {
            cancelled = true;
        };
        // year/term 仅用于首次初始化的班级查询；学期变更不重置已选筛选条件，
        // 改由 change* 用最新 year/term 重查
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [username]);

    const changeSchool = async (newSchool: string) => {
        setSchool(newSchool);
        setMajor("");
        setClassId("");
        setClassList([]);
        setGrade("");
        // setGrade 不会同步更新当前闭包里的 grade，后续请求须改用局部变量
        const g = "";
        try {
            setMajorList((await classScheduleApi.fetchMajors(g, newSchool)).map(m => [m.majorId, m.majorName]));
            setClassList(await classScheduleApi.fetchFullClasses(String(year), String(term), newSchool, "", g));
        } catch (e) {
            console.warn("查询专业列表失败", e);
            setMajorList([]);
            setClassList([]);
        }
    };

    const changeMajor = async (newMajor: string) => {
        setMajor(newMajor);
        setClassId("");
        setClassList([]);
        // 选“全部”（空串）时同样重新查询：空 major 经 cleanParams 过滤后，后端返回该条件下全部班级
        try {
            setClassList(await classScheduleApi.fetchFullClasses(String(year), String(term), school, newMajor, grade));
        } catch (e) {
            console.warn("查询班级列表失败", e);
            setClassList([]);
        }
    };

    // 年级变化时专业列表也会变化（教务系统按年级过滤专业），故需重新拉取专业并重置下游选择
    const changeGrade = async (newGrade: number | string) => {
        const g = newGrade === "" ? "" : String(newGrade);
        // 空串表示“全部年级”，应放行；仅拦截非数字脏值
        if (g !== "" && Number.isNaN(Number(g))) return;
        setGrade(g);
        setMajor("");
        setClassId("");
        setClassList([]);
        try {
            setMajorList((await classScheduleApi.fetchMajors(g, school)).map(m => [m.majorId, m.majorName]));
            setClassList(await classScheduleApi.fetchFullClasses(String(year), String(term), school, "", g));
        } catch (e) {
            console.warn("查询专业列表失败", e);
            setMajorList([]);
            setClassList([]);
        }
    };

    return {
        school,
        schoolList,
        changeSchool,
        major,
        changeMajor,
        grade,
        changeGrade,
        classId,
        setClassId,
        classList,
        majorList,
        selectedClass,
    };
};
