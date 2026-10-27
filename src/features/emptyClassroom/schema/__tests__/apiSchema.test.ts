import {
    EMPTY_CLASSROOM_INVALID_RESPONSE_MESSAGE,
    EmptyClassroomDataError,
    parseBackendEnvelope,
    parseClassroomEnvelope,
    parseClassroomPage,
} from "@/features/emptyClassroom/schema/index.ts";

/** 合法的一页后端 data。 */
function validPage() {
    return {
        totalPage: 2,
        totalCount: 3,
        // 正方回显不可信，Schema 应忽略
        currentPage: 99,
        extra: "ignored",
        items: [
            {
                classroomName: "西1-101",
                placeType: "普通",
                seatCount: "60",
                seatCountForExam: 60,
                building: "西一教",
                owner: "教务处",
                user: "全校",
                allowToUse: "是",
                currentPage: 99,
                extra: "ignored",
            },
        ],
    };
}

function captureError(run: () => unknown): unknown {
    try {
        run();
    } catch (error) {
        return error;
    }
    throw new Error("预期抛出异常但没有抛出");
}

describe("parseClassroomPage", () => {
    it("校验合法页并输出与 EmptyClassroom 兼容的结构", () => {
        const page = parseClassroomPage(validPage());

        expect(page).toEqual({
            totalPage: 2,
            totalCount: 3,
            currentPage: 1,
            items: [
                {
                    classroomName: "西1-101",
                    placeType: "普通",
                    seatCount: "60",
                    seatCountForExam: "60",
                    building: "西一教",
                    owner: "教务处",
                    user: "全校",
                    allowToUse: "是",
                    currentPage: 1,
                },
            ],
        });
    });

    it("忽略 currentPage 与未知字段", () => {
        const page = parseClassroomPage(validPage());

        expect(page).not.toHaveProperty("extra");
        expect(page.items[0]).not.toHaveProperty("extra");
        // 输入 currentPage=99，输出不信任该值，统一归一化
        expect(page.currentPage).toBe(1);
        expect(page.items[0].currentPage).toBe(1);
    });

    it("缺省非 key 字符串补空串，座位数保持字符串", () => {
        const page = parseClassroomPage({
            items: [{classroomName: "A", building: "B"}],
        });

        expect(page.totalCount).toBeUndefined();
        expect(page.totalPage).toBeUndefined();
        expect(page.items[0]).toEqual({
            classroomName: "A",
            building: "B",
            placeType: "",
            seatCount: "",
            seatCountForExam: "",
            owner: "",
            user: "",
            allowToUse: "",
            currentPage: 1,
        });
    });

    it("数字座位数转成字符串，数字字符串原样保留", () => {
        const page = parseClassroomPage({
            items: [
                {
                    classroomName: "A",
                    building: "B",
                    seatCount: 120,
                    seatCountForExam: "120",
                },
            ],
        });

        expect(page.items[0].seatCount).toBe("120");
        expect(page.items[0].seatCountForExam).toBe("120");
    });

    it("分页计数兼容数字字符串", () => {
        const page = parseClassroomPage({
            totalCount: "1690",
            totalPage: "4",
            items: [],
        });

        expect(page.totalCount).toBe(1690);
        expect(page.totalPage).toBe(4);
    });

    it("data 为 null 时抛出可鉴权重试的明确错误", () => {
        const error = captureError(() => parseClassroomPage(null));

        expect(error).toBeInstanceOf(EmptyClassroomDataError);
        expect((error as EmptyClassroomDataError).isLikelyAuthFailure).toBe(true);
        expect((error as Error).message).toBe(EMPTY_CLASSROOM_INVALID_RESPONSE_MESSAGE);
    });

    it("items 非数组时同样抛出鉴权错误，不静默当空结果", () => {
        const error = captureError(() => parseClassroomPage({items: "nope"}));

        expect(error).toBeInstanceOf(EmptyClassroomDataError);
        expect((error as EmptyClassroomDataError).isLikelyAuthFailure).toBe(true);
        expect((error as Error).message).toBe(EMPTY_CLASSROOM_INVALID_RESPONSE_MESSAGE);
    });

    it("缺少必填 key 字段时抛出数据格式错误（不触发鉴权重试）", () => {
        const error = captureError(() => parseClassroomPage({items: [{building: "B"}]}));

        expect(error).toBeInstanceOf(EmptyClassroomDataError);
        expect((error as EmptyClassroomDataError).isLikelyAuthFailure).toBe(false);
        expect((error as Error).message).toContain("空闲教室数据格式异常");
    });
});

describe("parseBackendEnvelope", () => {
    it("校验信封并保留 code/message/data", () => {
        const envelope = parseBackendEnvelope({
            code: 200,
            message: "ok",
            data: validPage(),
            extra: "ignored",
        });

        expect(envelope.code).toBe(200);
        expect(envelope.message).toBe("ok");
        expect(envelope).not.toHaveProperty("extra");
    });

    it("message 缺省补空串，code 兼容数字字符串", () => {
        expect(parseBackendEnvelope({code: "200", data: null})).toEqual({
            code: 200,
            message: "",
            data: null,
        });
    });

    it("信封格式错误时抛出格式错误", () => {
        expect(() => parseBackendEnvelope({message: "缺少 code"})).toThrow("空闲教室接口响应格式异常");
    });
});

describe("parseClassroomEnvelope", () => {
    it("从信封中取出并校验 data", () => {
        const page = parseClassroomEnvelope({code: 200, message: "ok", data: validPage()});

        expect(page.items).toHaveLength(1);
        expect(page.totalCount).toBe(3);
    });

    it("data 为 null 时抛鉴权错误", () => {
        const error = captureError(() => parseClassroomEnvelope({code: 200, message: "ok", data: null}));

        expect(error).toBeInstanceOf(EmptyClassroomDataError);
        expect((error as EmptyClassroomDataError).isLikelyAuthFailure).toBe(true);
    });
});
