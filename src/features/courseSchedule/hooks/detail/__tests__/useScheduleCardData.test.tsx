import React from "react";
import TestRenderer, {act} from "react-test-renderer";
import moment from "moment";
import {useScheduleCardData} from "../useScheduleCardData";
import {useAttendanceAuth} from "@/core/auth/attendance/hooks/useAttendanceAuth";
import {useStartDay} from "../useStartDay";
import {usePersonalCourseData} from "../usePersonalCourseData";
import {useExamInfo} from "../useExamInfo";
import {useRecord} from "@/features/attendance/hooks/useRecord";
import {normalizeCourse} from "@/features/classCourseSchedule/utils/normalizeCourse";
import {attendanceApi} from "@/features/attendance/api";

jest.mock("@/core/auth/Jw/hooks/useJwAccount", () => ({
    useJwAccount: () => ({account: {username: "student"}}),
}));
jest.mock("@/core/auth/attendance/hooks/useAttendanceAuth", () => ({useAttendanceAuth: jest.fn()}));
jest.mock("../useStartDay", () => ({useStartDay: jest.fn()}));
jest.mock("../usePersonalCourseData", () => ({usePersonalCourseData: jest.fn()}));
jest.mock("../useExamInfo", () => ({useExamInfo: jest.fn()}));
jest.mock("../useHoliday", () => ({useHoliday: () => []}));
jest.mock("../../useCustomEvents", () => ({
    useCustomEvents: () => ({events: []}),
}));
jest.mock("@/features/attendance/hooks/useRecord", () => ({useRecord: jest.fn()}));
jest.mock("@/features/classCourseSchedule/utils/normalizeCourse", () => ({normalizeCourse: jest.fn()}));
jest.mock("@/features/attendance/api", () => ({attendanceApi: {getTableDataV2: jest.fn()}}));

let renderer: TestRenderer.ReactTestRenderer | null = null;
let latest: ReturnType<typeof useScheduleCardData>;
let recordState: {records: {date: string; periodRange: string; statusCode: number}[]};
const refreshCourses = jest.fn();
const refreshExams = jest.fn();
const startDay = moment().startOf("isoWeek");
const course = {id: "course", week: 1, day: 1, begin: 1, end: 2, title: "测试课程", kind: "course"};

/** 挂载首页数据组合与真实考勤课表 hook，覆盖认证通知后的渲染链路。 */
function Probe() {
    latest = useScheduleCardData(2026, 1);
    return null;
}

beforeEach(() => {
    jest.clearAllMocks();
    recordState = {records: []};
    (useAttendanceAuth as jest.Mock).mockReturnValue({authState: {status: "has_account_not_authenticated"}});
    (useStartDay as jest.Mock).mockReturnValue({startDay, weekCount: 20, year: 2026, term: 1, ready: true});
    (usePersonalCourseData as jest.Mock).mockReturnValue({schedule: {}, status: "success", refresh: refreshCourses});
    (useExamInfo as jest.Mock).mockReturnValue({examInfo: [], status: "success", refresh: refreshExams});
    (useRecord as jest.Mock).mockImplementation(() => recordState);
    (normalizeCourse as jest.Mock).mockReturnValue([course]);
    (attendanceApi.getTableDataV2 as jest.Mock).mockResolvedValue({
        totalWeeks: 20,
        rows: [{date: startDay.format("YYYY-MM-DD"), courses: [{subjectId: 1, subjectName: "测试课程", periods: [1, 2]}]}],
    });
});

afterEach(async () => {
    await act(async () => renderer?.unmount());
    renderer = null;
});

it("未登录时不请求，登录通知后只自动加载一次，普通重渲染不刷新", async () => {
    await act(async () => {
        renderer = TestRenderer.create(<Probe />);
    });
    expect(attendanceApi.getTableDataV2).not.toHaveBeenCalled();

    (useAttendanceAuth as jest.Mock).mockReturnValue({authState: {status: "authenticated"}});
    await act(async () => renderer!.update(<Probe />));
    expect(attendanceApi.getTableDataV2).toHaveBeenCalledTimes(1);
    expect(attendanceApi.getTableDataV2).toHaveBeenCalledWith(2026, 1, 1);
    expect(refreshCourses).not.toHaveBeenCalled();
    expect(refreshExams).not.toHaveBeenCalled();

    await act(async () => renderer!.update(<Probe />));
    expect(attendanceApi.getTableDataV2).toHaveBeenCalledTimes(1);
});

it("考勤记录异步到达时更新课程状态，保留原教务课表", async () => {
    (useAttendanceAuth as jest.Mock).mockReturnValue({authState: {status: "authenticated"}});
    await act(async () => {
        renderer = TestRenderer.create(<Probe />);
    });
    expect(latest.courseItem[0].status).toBeUndefined();

    recordState = {records: [{date: startDay.format("YYYY-MM-DD"), periodRange: "1,2", statusCode: 2}]};
    await act(async () => renderer!.update(<Probe />));
    expect(latest.courseItem).toEqual([{...course, status: 2}]);
    expect(attendanceApi.getTableDataV2).toHaveBeenCalledTimes(1);
});

it("手动刷新同时刷新三种数据，考勤请求未完成时保持刷新状态", async () => {
    (useAttendanceAuth as jest.Mock).mockReturnValue({authState: {status: "authenticated"}});
    await act(async () => {
        renderer = TestRenderer.create(<Probe />);
    });
    let finish!: () => void;
    (attendanceApi.getTableDataV2 as jest.Mock).mockReturnValueOnce(new Promise(resolve => {
        finish = () => resolve(null);
    }));
    let pending!: Promise<void>;
    await act(async () => {
        pending = latest.refresh();
    });
    expect(refreshCourses).toHaveBeenCalledTimes(1);
    expect(refreshExams).toHaveBeenCalledTimes(1);
    expect(attendanceApi.getTableDataV2).toHaveBeenCalledTimes(2);
    expect(latest.refreshing).toBe(true);
    await act(async () => {
        finish();
        await pending;
    });
    expect(latest.refreshing).toBe(false);
});
