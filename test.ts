/**
 * 空闲教室接口冒烟测试（在 App 根目录运行）
 *
 * 运行：
 *   # 先在根目录 test-credentials.local.ts 里填学号密码（已 gitignore），然后：
 *   npx tsx test.ts
 *
 *   # 也可以直接传：
 *   npx tsx test.ts --cookie "JSESSIONID=xxx; route=xxx"
 *   npx tsx test.ts --username 2407140119 --password '******'
 *
 * 默认请求线上后端 http://api.tool.gxutech.xyz，可用 --base 指向本地。
 *
 * 覆盖：
 *   1. 楼号 / 场地类别选项接口（无需登录）
 *   2. 查询接口（需登录）：响应结构、分页、第二页是否真的换页
 *   3. 参数校验：未知参数、逗号数组、[] 数组、越界、缺必填、pageSize 超限
 *   4. 未登录查询是否返回 401（需显式加 --check-unauth）
 *   5. year/term 成对提交的诊断信息（不判定失败）
 *   6. --relations：参数与结果的与/或关系实验
 *   7. --bench-sqlite：单表 vs 教室抽离的 SQLite 空间/查询基准
 *
 * 注意：脚本不会打印 Cookie；--verbose 只打印请求 URL。
 */
import axios from "axios";
import {TEST_CREDENTIALS} from "./test-credentials.local";

// ---------------- 类型 ----------------

type OptionItem = {label: string; name: string};

type Envelope<T> = {code: number; message: string; data: T};

type ClassroomItem = {
    classroomName: string;
    placeType: string;
    seatCount: string;
    seatCountForExam: string;
    building: string;
    owner: string;
    user: string;
    allowToUse: string;
    currentPage?: number;
};

type ClassroomPage = {
    totalPage?: number;
    totalCount?: number;
    currentPage?: number;
    items: ClassroomItem[];
};

type TermPair = {year: number; term: number};

type RequestResult<T> = {
    status: number;
    json: T;
    text: string;
    setCookies: string[];
};

// Node 环境下的全局变量（项目未安装 @types/node，这里显式声明，避免类型检查报错）
declare const process: {
    argv: string[];
    env: Record<string, string | undefined>;
    stdout: {isTTY?: boolean};
    exit(code?: number): never;
    exitCode?: number;
    hrtime: {bigint(): bigint};
};

// test.ts 由 tsx 以 CommonJS 运行；node:sqlite / node:fs / node:path 用 require 取，
// 避免项目未安装 @types/node 时 IDE 报「找不到模块」。
declare const require: (id: string) => any;

// ---------------- CLI ----------------

const args = new Map<string, string>();
const flags = new Set<string>();
const rawArgs = process.argv.slice(2);

for (let i = 0; i < rawArgs.length; i += 1) {
    const arg = rawArgs[i];
    if (arg === "--help" || arg === "-h") {
        printHelp();
        process.exit(0);
    }
    if (!arg.startsWith("--")) {
        console.error(`无法识别的参数：${arg}`);
        printHelp();
        process.exit(2);
    }
    const key = arg.slice(2);
    const next = rawArgs[i + 1];
    if (next === undefined || next.startsWith("--")) {
        flags.add(key);
    } else {
        args.set(key, next);
        i += 1;
    }
}

const BASE = stripTrailingSlash(
    args.get("base") || process.env.BASE_URL || "http://api.tool.gxutech.xyz",
);
const COOKIE_ARG = args.get("cookie") || process.env.JW_COOKIE || "";
const USERNAME =
    args.get("username") || process.env.JW_USERNAME || TEST_CREDENTIALS.username || "";
const PASSWORD =
    args.get("password") || process.env.JW_PASSWORD || TEST_CREDENTIALS.password || "";
const WEEK_DAY = readInt("day", args.get("day") ?? 1, 1, 7);
const WEEK = readInt("week", args.get("week") ?? 1, 1, 20);
const PERIOD = readInt("time", args.get("time") ?? 1, 1, 13);
const PAGE_SIZE = readInt("page-size", args.get("page-size") ?? 5, 1, 500);
const CHECK_UNAUTH = flags.has("check-unauth");
const RUN_RELATIONS = flags.has("relations");
const RUN_SQLITE_BENCH = flags.has("bench-sqlite");
const BUILDING_ARG = args.get("building");
const PLACE_ARG = args.get("place");
const VERBOSE = flags.has("verbose");
const REQUEST_TIMEOUT_MS = 20_000;

// ---------------- 输出与断言 ----------------

const useColor = Boolean(process.stdout.isTTY) && !process.env.NO_COLOR;
const paint = (code: string, text: string) =>
    useColor ? `\u001b[${code}m${text}\u001b[0m` : text;
const green = (text: string) => paint("32", text);
const red = (text: string) => paint("31", text);
const yellow = (text: string) => paint("33", text);
const cyan = (text: string) => paint("36", text);
const dim = (text: string) => paint("2", text);

let passed = 0;
let failed = 0;
let skipped = 0;

async function test(name: string, fn: () => Promise<void>) {
    try {
        await fn();
        passed += 1;
        console.log(`  ${green("PASS")} ${name}`);
    } catch (error) {
        failed += 1;
        console.log(`  ${red("FAIL")} ${name}`);
        console.log(`       ${red(error instanceof Error ? error.message : String(error))}`);
    }
}

function skip(name: string, reason: string) {
    skipped += 1;
    console.log(`  ${yellow("SKIP")} ${name}${reason ? dim(`（${reason}）`) : ""}`);
}

function note(message: string) {
    console.log(`  ${cyan("INFO")} ${message}`);
}

function section(title: string) {
    console.log(`\n${title}`);
}

function assert(condition: unknown, message: string): asserts condition {
    if (!condition) throw new Error(message);
}

function assertEqual(actual: unknown, expected: unknown, message: string) {
    assert(
        actual === expected,
        `${message}（期望 ${JSON.stringify(expected)}，实际 ${JSON.stringify(actual)}）`,
    );
}

// ---------------- HTTP ----------------

async function request<T>(
    pathname: string,
    options: {method?: "GET" | "POST"; body?: unknown; cookie?: string} = {},
): Promise<RequestResult<T>> {
    const method = options.method ?? "GET";
    const url = `${BASE}${pathname}`;
    if (VERBOSE) {
        console.log(
            dim(`  → ${method} ${url}${options.cookie ? "（带 Cookie）" : ""}`),
        );
    }

    try {
        const response = await axios.request<T>({
            url,
            method,
            data: options.body,
            headers: {
                Accept: "application/json",
                // 后端启用 gzip 后，Node 侧显式要求未压缩，避免脚本/断言依赖 Axios 的解压行为
                "Accept-Encoding": "identity",
                ...(options.cookie ? {Cookie: options.cookie} : {}),
            },
            timeout: REQUEST_TIMEOUT_MS,
            // 4xx/5xx 不抛异常，交给断言处理
            validateStatus: () => true,
        });

        const rawSetCookie = response.headers["set-cookie"];
        const setCookies = (
            Array.isArray(rawSetCookie)
                ? rawSetCookie
                : rawSetCookie
                  ? [rawSetCookie]
                  : []
        ).map(String);

        return {
            status: response.status,
            json: response.data,
            text: typeof response.data === "string" ? response.data : safeStringify(response.data),
            setCookies,
        };
    } catch (error) {
        const reason = error instanceof Error ? error.message : String(error);
        throw new Error(`请求失败：${method} ${url} · ${reason}`);
    }
}

function describeBody(json: {message?: string} | null | undefined, text: string): string {
    if (json?.message) return json.message;
    return text.replace(/\s+/g, " ").slice(0, 120);
}

function safeStringify(value: unknown): string {
    try {
        return JSON.stringify(value);
    } catch {
        return String(value);
    }
}

/** 登录并把 Set-Cookie 里的 JSESSIONID / route 拼成 Cookie 头 */
async function login(username: string, password: string): Promise<string> {
    const {status, json, text, setCookies} = await request<Envelope<null>>(
        "/jw/login",
        {method: "POST", body: {username, password}},
    );

    // NestJS 的 POST 默认返回 201，不能只认 200
    if (status < 200 || status >= 300 || json?.code !== 200) {
        throw new Error(`HTTP ${status} · ${describeBody(json, text)}`);
    }

    const jar: Record<string, string> = {};
    for (const header of setCookies) {
        const pair = header.split(";")[0];
        const index = pair.indexOf("=");
        if (index > 0) jar[pair.slice(0, index).trim()] = pair.slice(index + 1).trim();
    }

    if (!jar.JSESSIONID || !jar.route) {
        throw new Error("登录成功但响应里缺少 JSESSIONID / route");
    }

    return `JSESSIONID=${jar.JSESSIONID}; route=${jar.route}`;
}

// ---------------- 查询构造 ----------------

/** 查询串：数组展开成重复键，空值跳过 */
function buildQuery(params: Record<string, unknown>): string {
    const parts: string[] = [];
    for (const [key, value] of Object.entries(params)) {
        if (value === undefined || value === null || value === "") continue;
        for (const item of Array.isArray(value) ? value : [value]) {
            if (item === undefined || item === null || item === "") continue;
            parts.push(`${encodeURIComponent(key)}=${encodeURIComponent(String(item))}`);
        }
    }
    return parts.join("&");
}

function makeQuery(overrides: Record<string, unknown> = {}): string {
    return `/jw/emptyClassroom?${buildQuery({
        weekDay: [WEEK_DAY],
        weekList: [WEEK],
        timeList: [PERIOD],
        pageNum: 1,
        pageSize: PAGE_SIZE,
        ...(termPair ?? {}),
        ...overrides,
    })}`;
}

function query(overrides: Record<string, unknown> = {}) {
    return request<Envelope<ClassroomPage | null>>(makeQuery(overrides), {cookie});
}

// ---------------- 学期 ----------------

/**
 * 学年/学期：优先命令行，其次 /jw/profile/startday。
 * startday 没有 isCurrent 标记，这里取「开学日期已到且最近」的一行；都不满足则取最晚一行。
 */
async function resolveTermPair(): Promise<TermPair> {
    const yearArg = args.get("year");
    const termArg = args.get("term");
    if (yearArg || termArg) {
        if (!yearArg || !termArg) throw new Error("--year 与 --term 必须同时提供");
        return {
            year: readInt("year", yearArg, 1, 9999),
            term: readInt("term", termArg, 1, 2),
        };
    }

    const {status, json, text} = await request<Envelope<{year: number; term: number; day: string}[]>>(
        "/jw/profile/startday",
    );
    if (status !== 200 || json?.code !== 200) {
        throw new Error(`startday 接口异常：HTTP ${status} · ${describeBody(json, text)}`);
    }

    const rows = (Array.isArray(json.data) ? json.data : []).filter(
        row =>
            Number.isInteger(row.year) &&
            Number.isInteger(row.term) &&
            Number.isFinite(Date.parse(row.day)),
    );
    if (!rows.length) throw new Error("startday 没有可用的学期数据");

    const started = rows
        .filter(row => Date.parse(row.day) <= Date.now())
        .sort((left, right) => Date.parse(right.day) - Date.parse(left.day));
    const chosen =
        started[0] ??
        [...rows].sort((left, right) => Date.parse(right.day) - Date.parse(left.day))[0];

    return {year: chosen.year, term: chosen.term};
}

// ---------------- 测试 ----------------

let cookie = COOKIE_ARG;
let credentialSource = COOKIE_ARG ? "Cookie（--cookie / JW_COOKIE）" : "";
let termPair: TermPair | null = null;
let loginError = "";

async function main() {
    console.log("空闲教室接口冒烟测试");
    console.log(`目标：${BASE}`);
    console.log(
        `参数：weekDay=${WEEK_DAY} weekList=${WEEK} timeList=${PERIOD} pageSize=${PAGE_SIZE}`,
    );

    if (!cookie && USERNAME && PASSWORD) {
        try {
            cookie = await login(USERNAME, PASSWORD);
            credentialSource = `登录（学号 ${mask(USERNAME)}）`;
        } catch (error) {
            loginError = error instanceof Error ? error.message : String(error);
        }
    }
    console.log(
        `凭据：${
            credentialSource ||
            (loginError ? `登录失败（${loginError}）` : "无（需登录的查询会跳过）")
        }`,
    );

    // ---------- 1. 选项接口 ----------
    section("一、选项接口（无需登录）");

    await test("GET /jw/emptyClassroom/building 返回楼号列表", async () => {
        const {status, json, text} = await request<Envelope<OptionItem[]>>(
            "/jw/emptyClassroom/building",
        );
        assertEqual(status, 200, `HTTP 状态异常 · ${describeBody(json, text)}`);
        assert(json?.code === 200, `业务码异常 · ${describeBody(json, text)}`);
        assert(Array.isArray(json.data) && json.data.length > 0, "data 应为非空数组");
        for (const [index, item] of json.data.entries()) {
            assert(
                typeof item?.label === "string" && typeof item?.name === "string",
                `第 ${index + 1} 项缺少字符串 label/name`,
            );
        }
        assert(
            json.data.some(item => item.label === "" && item.name === "全部"),
            '选项里应包含 {label:"", name:"全部"}',
        );
        note(`共 ${json.data.length} 个楼号选项`);
    });

    await test("GET /jw/emptyClassroom/place 返回场地类别列表", async () => {
        const {status, json, text} = await request<Envelope<OptionItem[]>>(
            "/jw/emptyClassroom/place",
        );
        assertEqual(status, 200, `HTTP 状态异常 · ${describeBody(json, text)}`);
        assert(json?.code === 200, `业务码异常 · ${describeBody(json, text)}`);
        assert(Array.isArray(json.data) && json.data.length > 0, "data 应为非空数组");
        for (const [index, item] of json.data.entries()) {
            assert(
                typeof item?.label === "string" && typeof item?.name === "string",
                `第 ${index + 1} 项缺少字符串 label/name`,
            );
        }
        note(`共 ${json.data.length} 个场地类别选项`);
    });

    // ---------- 2. 查询接口 ----------
    section("二、查询接口（需登录）");

    if (loginError) {
        console.log(`  ${red("FAIL")} 登录失败：${loginError}`);
        failed += 1;
    }

    if (!cookie) {
        skip(
            "查询接口整体",
            loginError ? "登录失败" : "未提供 --cookie 或 --username/--password",
        );
    } else {
        try {
            termPair = await resolveTermPair();
            note(`使用学期：year=${termPair.year} term=${termPair.term}`);
        } catch (error) {
            note(
                `未解析到学期，year/term 将不提交：${error instanceof Error ? error.message : String(error)}`,
            );
        }

        await test("GET /jw/emptyClassroom 返回一页结果", async () => {
            const {status, json, text} = await query();
            assertEqual(status, 200, `HTTP 状态异常 · ${describeBody(json, text)}`);
            assert(json?.code === 200, `业务码异常 · ${describeBody(json, text)}`);

            const data = json.data;
            assert(
                data && typeof data === "object" && !Array.isArray(data),
                "data 应为对象（为 null 通常说明适配器解析失败或会话异常）",
            );
            assert(Array.isArray(data.items), "data.items 应为数组");
            assert(
                data.items.length <= PAGE_SIZE,
                `本页 ${data.items.length} 条，超过 pageSize=${PAGE_SIZE}`,
            );

            if (data.items.length > 0) {
                const item = data.items[0];
                for (const field of ["classroomName", "building", "placeType", "seatCount"] as const) {
                    assert(
                        typeof item[field] === "string",
                        `items[0].${field} 应为字符串`,
                    );
                }
            }

            note(
                `totalCount=${data.totalCount ?? "null"}，totalPage=${data.totalPage ?? "null"}，本页 ${data.items.length} 条`,
            );
        });

        await test("分页：第 2 页与第 1 页不同且总数一致", async () => {
            const first = await query({pageNum: 1});
            assertEqual(
                first.status,
                200,
                `第 1 页 HTTP ${first.status} · ${describeBody(first.json, first.text)}`,
            );
            assert(first.json?.code === 200, `第 1 页业务码 ${first.json?.code}`);

            const firstData = first.json.data;
            assert(
                firstData && Array.isArray(firstData.items),
                "第 1 页 data.items 不是数组",
            );

            const totalPage = firstData.totalPage;
            const totalCount = firstData.totalCount;
            const mayHaveSecondPage =
                (typeof totalPage === "number" && totalPage >= 2) ||
                (typeof totalCount === "number" && totalCount > PAGE_SIZE);

            if (!mayHaveSecondPage) {
                skip(
                    "分页第 2 页",
                    `totalPage=${totalPage ?? "null"} totalCount=${totalCount ?? "null"}，只有一页`,
                );
                return;
            }

            const second = await query({pageNum: 2});
            assertEqual(
                second.status,
                200,
                `第 2 页 HTTP ${second.status} · ${describeBody(second.json, second.text)}`,
            );
            assert(
                second.json?.code === 200,
                `第 2 页业务码 ${second.json?.code}：${describeBody(second.json, second.text)}`,
            );

            const secondData = second.json.data;
            assert(
                secondData && Array.isArray(secondData.items),
                "第 2 页 data.items 不是数组",
            );
            assert(
                secondData.items.length <= PAGE_SIZE,
                `第 2 页 ${secondData.items.length} 条，超过 pageSize=${PAGE_SIZE}`,
            );

            if (typeof totalCount === "number" && typeof secondData.totalCount === "number") {
                assertEqual(secondData.totalCount, totalCount, "两页的 totalCount 不一致");
            }
            if (typeof secondData.currentPage === "number" && secondData.currentPage !== 2) {
                // 实测：正方返回的 queryModel.currentPage 恒为 1，分页是否生效以第 2 页内容为准
                note(
                    `上游回显 currentPage=${secondData.currentPage}（请求的是 pageNum=2），` +
                        "该字段不可靠；分页是否生效以上面的内容比对为准",
                );
            }
            if (firstData.items.length > 0 && secondData.items.length > 0) {
                const keyOf = (item: ClassroomItem) =>
                    `${item.building ?? ""}\u0000${item.classroomName ?? ""}`;
                const firstKeys = new Set(firstData.items.map(keyOf));
                assert(
                    secondData.items.some(item => !firstKeys.has(keyOf(item))),
                    "第 2 页内容与第 1 页完全相同，pageNum 可能没有生效",
                );
            }
            note(`第 1 页 ${firstData.items.length} 条，第 2 页 ${secondData.items.length} 条`);
        });

        // 诊断：year/term 成对提交（不判定失败）
        if (termPair) {
            try {
                const [paired, onlyTerm] = await Promise.all([
                    query({year: termPair.year, term: termPair.term, pageNum: 1, pageSize: 1}),
                    query({year: undefined, term: termPair.term, pageNum: 1, pageSize: 1}),
                ]);
                const countOf = (result: RequestResult<Envelope<ClassroomPage | null>>) =>
                    typeof result.json?.data?.totalCount === "number"
                        ? result.json.data.totalCount
                        : null;
                const pairedCount = countOf(paired);
                const onlyTermCount = countOf(onlyTerm);
                note(
                    `year/term 诊断：成对提交 totalCount=${pairedCount ?? "null"}，只传 term=${onlyTermCount ?? "null"}`,
                );
                if (pairedCount !== null && pairedCount > 0 && onlyTermCount === 0) {
                    note("符合已知陷阱：只传 term 时返回空结果，调用方必须成对提交");
                } else if (pairedCount !== null && pairedCount === onlyTermCount) {
                    note("本次未复现「只传 term 返回空结果」，上游行为可能已变化");
                }
            } catch (error) {
                note(
                    `year/term 诊断失败：${error instanceof Error ? error.message : String(error)}`,
                );
            }
        }
    }

    // ---------- 3. 参数校验 ----------
    section("三、参数校验（无需登录）");

    await expectValidationError(
        "未知参数返回 400",
        "/jw/emptyClassroom?weekDay=1&weekList=1&timeList=1&foo=bar",
    );
    await expectValidationError(
        "逗号分隔数组返回 400",
        "/jw/emptyClassroom?weekDay=1,2&weekList=1&timeList=1",
    );
    await expectValidationError(
        "数组括号写法（weekDay[]）返回 400",
        "/jw/emptyClassroom?weekDay%5B%5D=1&weekList=1&timeList=1",
    );
    await expectValidationError(
        "周次越界（weekList=21）返回 400",
        "/jw/emptyClassroom?weekDay=1&weekList=21&timeList=1",
    );
    await expectValidationError(
        "缺少必填数组（只传 weekDay）返回 400",
        "/jw/emptyClassroom?weekDay=1",
    );
    await expectValidationError(
        "pageSize 超限（501）返回 400",
        "/jw/emptyClassroom?weekDay=1&weekList=1&timeList=1&pageSize=501",
    );

    // ---------- 4. 未登录 ----------
    if (CHECK_UNAUTH) {
        section("四、未登录行为");
        if (cookie) {
            skip("未登录查询应返回 401", "本次已提供登录凭据");
        } else {
            await test("未登录查询返回 401", async () => {
                const {status, json, text} = await query();
                assertEqual(status, 401, `HTTP 状态异常 · ${describeBody(json, text)}`);
                assertEqual(json?.code, 401, "业务码应为 401");
            });
        }
    }

    // ---------- 5. 参数与结果关系 ----------
    if (RUN_RELATIONS) {
        if (!cookie) {
            section("五、参数与结果关系（--relations）");
            skip("参数关系实验", "需要登录凭据");
        } else {
            await runRelationExperiment();
        }
    }

    // ---------- 6. SQLite 结构基准 ----------
    if (RUN_SQLITE_BENCH) {
        if (!cookie) {
            section("六、SQLite 结构基准（--bench-sqlite）");
            skip("SQLite 基准", "需要登录凭据");
        } else {
            await runSqliteBenchmark();
        }
    }

    // ---------- 汇总 ----------
    console.log(
        `\n结果：${green(`${passed} 通过`)}，${failed ? red(`${failed} 失败`) : `${failed} 失败`}，${skipped} 跳过`,
    );
    process.exitCode = failed > 0 ? 1 : 0;
}

async function expectValidationError(name: string, pathname: string) {
    await test(name, async () => {
        const {status, json, text} = await request<Envelope<null>>(pathname);
        assertEqual(status, 400, `HTTP 状态异常 · ${describeBody(json, text)}`);
        assertEqual(json?.code, 400, "业务码应为 400");
    });
}

// ---------------- 参数与结果关系实验 ----------------

/**
 * 实验思路：
 *   固定其他条件，只让一个维度出现多个值，比较「组合查询」与
 *   「各单值查询的交集 / 并集」：
 *     - 组合 = 交集 → 该维度的多个值是「与」（必须同时满足）
 *     - 组合 = 并集 → 该维度的多个值是「或」（满足任意一个即可）
 *   三个维度同时多值时，再与 8 个单点组合（2×2×2）的交集/并集比较，
 *   可以判断跨维度是不是完整的「与」。
 *
 * 为了缩小结果集，默认从楼号选项里挑一个教学楼（totalCount 20~500），
 * 也可以用 --building <label> 手动指定；--place <label> 同理。
 */

function twoValues(value: number, min: number, max: number): [number, number] {
    const first = Math.min(Math.max(value, min), max - 1);
    return [first, first + 1];
}

function classroomKey(item: ClassroomItem): string {
    return `${item.building ?? ""}\u0000${item.classroomName ?? ""}`;
}

type SetResult = {
    keys: Set<string>;
    totalCount: number | null;
    rows: number;
    pages: number;
    complete: boolean;
    duplicates: number;
};

/** 按 pageNum 逐页取完整集合（pageSize=500，最多 5 页） */
async function fetchSet(overrides: Record<string, unknown>): Promise<SetResult> {
    const pageSize = 500;
    const maxPages = 5;
    const keys = new Set<string>();
    let rows = 0;
    let totalCount: number | null = null;
    let page = 1;
    let lastPageSize = 0;

    while (page <= maxPages) {
        const res = await query({...overrides, pageNum: page, pageSize});
        assertEqual(res.status, 200, `HTTP ${res.status} · ${describeBody(res.json, res.text)}`);
        assert(
            res.json?.code === 200,
            `业务码 ${res.json?.code}：${describeBody(res.json, res.text)}`,
        );

        const data = res.json.data;
        assert(data && Array.isArray(data.items), "data.items 不是数组");
        if (typeof data.totalCount === "number") totalCount = data.totalCount;
        for (const item of data.items) keys.add(classroomKey(item));
        rows += data.items.length;
        lastPageSize = data.items.length;

        if (data.items.length === 0) break;
        if (totalCount !== null && rows >= totalCount) break;
        if (data.items.length < pageSize) break;
        page += 1;
    }

    return {
        keys,
        totalCount,
        rows,
        pages: page,
        complete: totalCount !== null ? rows >= totalCount : lastPageSize < pageSize,
        duplicates: rows - keys.size,
    };
}

function describeSet(name: string, result: SetResult) {
    note(
        `${name}：${result.keys.size} 个教室（totalCount=${result.totalCount ?? "null"}，` +
            `拉取 ${result.rows} 行 / ${result.pages} 页${result.complete ? "" : "，未拉全"}）`,
    );
}

/** 比较组合查询与一组单值查询：组合 = 交集（与）还是并集（或） */
function compareCombination(label: string, combined: SetResult, singles: SetResult[]) {
    const [first, ...rest] = singles;
    const intersection = new Set(
        [...first.keys].filter(key => rest.every(single => single.keys.has(key))),
    );
    const union = new Set(first.keys);
    for (const single of rest) {
        for (const key of single.keys) union.add(key);
    }

    const combinedSubsetOfIntersection = [...combined.keys].every(key => intersection.has(key));
    const intersectionSubsetOfCombined = [...intersection].every(key => combined.keys.has(key));
    const combinedSubsetOfUnion = [...combined.keys].every(key => union.has(key));
    const unionSubsetOfCombined = [...union].every(key => combined.keys.has(key));

    const equalsIntersection = combinedSubsetOfIntersection && intersectionSubsetOfCombined;
    const equalsUnion = combinedSubsetOfUnion && unionSubsetOfCombined;
    const complete = combined.complete && singles.every(single => single.complete);

    note(
        `${label}：组合=${combined.keys.size}，交集=${intersection.size}，并集=${union.size}` +
            `${complete ? "" : "（数据未拉全，结论仅供参考）"}`,
    );

    if (equalsIntersection && !equalsUnion) {
        note("  → 与（AND）：组合结果 = 各单值结果的交集");
    } else if (equalsUnion && !equalsIntersection) {
        note("  → 或（OR）：组合结果 = 各单值结果的并集");
    } else if (equalsIntersection && equalsUnion) {
        note("  → 各单值结果相同，无法区分与/或");
    } else if (combinedSubsetOfIntersection) {
        note("  → 不是纯交集/并集：组合结果是交集的真子集（叠加了更严格的约束）");
    } else if (unionSubsetOfCombined) {
        note("  → 不是纯交集/并集：组合结果是并集的真超集");
    } else {
        const onlyInIntersection = [...intersection].filter(key => !combined.keys.has(key)).length;
        const onlyInCombined = [...combined.keys].filter(key => !intersection.has(key)).length;
        note(
            `  → 不是纯交集/并集：交集另有 ${onlyInIntersection} 个不在组合中，` +
                `组合另有 ${onlyInCombined} 个不在交集中`,
        );
    }

    if (combined.duplicates > 0) {
        note(`  注意：组合结果里有 ${combined.duplicates} 行重复教室`);
    }
}

type RelationScope = {building?: string; name?: string};

/** 选一个规模适中的教学楼作为实验范围；失败则退回全量 */
async function pickRelationScope(): Promise<RelationScope> {
    if (BUILDING_ARG !== undefined) {
        return {building: BUILDING_ARG, name: BUILDING_ARG};
    }

    try {
        const {json} = await request<Envelope<OptionItem[]>>("/jw/emptyClassroom/building");
        const candidates = (Array.isArray(json?.data) ? json.data : [])
            .filter(option => option.label && /教/.test(option.name))
            .slice(0, 8);

        let fallback: {building: string; name: string} | null = null;
        for (const candidate of candidates) {
            const probe = await query({
                building: candidate.label,
                pageNum: 1,
                pageSize: 1,
            });
            const count = probe.json?.data?.totalCount;
            if (typeof count !== "number" || count <= 0) continue;
            fallback ??= {building: candidate.label, name: candidate.name};
            if (count >= 20 && count <= 500) {
                return {building: candidate.label, name: candidate.name};
            }
        }
        if (fallback) return fallback;
    } catch (error) {
        note(`挑选楼号失败：${error instanceof Error ? error.message : String(error)}`);
    }

    return {};
}

/** 场地类别：默认「普通」，可用 --place 覆盖 */
async function pickPlace(): Promise<OptionItem | null> {
    if (PLACE_ARG !== undefined) {
        return {label: PLACE_ARG, name: PLACE_ARG};
    }
    try {
        const {json} = await request<Envelope<OptionItem[]>>("/jw/emptyClassroom/place");
        const options = Array.isArray(json?.data) ? json.data : [];
        return options.find(option => option.name === "普通") ?? options[0] ?? null;
    } catch {
        return null;
    }
}

async function runRelationExperiment() {
    section("五、参数与结果关系（--relations）");

    const scope = await pickRelationScope();
    if (scope.building) {
        note(`限定楼号：${scope.name ?? ""}（label=${scope.building}），用于缩小结果集`);
    } else {
        note("未限定楼号，使用全量结果（请求会比较多）");
    }
    const filter = scope.building ? {building: scope.building} : {};

    const [d1, d2] = twoValues(WEEK_DAY, 1, 7);
    const [w1, w2] = twoValues(WEEK, 1, 20);
    const [p1, p2] = twoValues(PERIOD, 1, 13);
    note(`实验维度：weekDay=${d1}/${d2}，weekList=${w1}/${w2}，timeList=${p1}/${p2}`);

    // 8 个单点组合（2×2×2）
    const combos: Record<string, SetResult> = {};
    for (const day of [d1, d2]) {
        for (const week of [w1, w2]) {
            for (const period of [p1, p2]) {
                const key = `${day}-${week}-${period}`;
                combos[key] = await fetchSet({
                    ...filter,
                    weekDay: day,
                    weekList: week,
                    timeList: period,
                });
                describeSet(`F(day=${day}, week=${week}, period=${period})`, combos[key]);
            }
        }
    }

    // 单维度多值：其他维度固定
    const multiDay = await fetchSet({
        ...filter,
        weekDay: [d1, d2],
        weekList: w1,
        timeList: p1,
    });
    const multiWeek = await fetchSet({
        ...filter,
        weekDay: d1,
        weekList: [w1, w2],
        timeList: p1,
    });
    const multiTime = await fetchSet({
        ...filter,
        weekDay: d1,
        weekList: w1,
        timeList: [p1, p2],
    });

    describeSet(`F(day=[${d1},${d2}], week=${w1}, period=${p1})`, multiDay);
    describeSet(`F(day=${d1}, week=[${w1},${w2}], period=${p1})`, multiWeek);
    describeSet(`F(day=${d1}, week=${w1}, period=[${p1},${p2}])`, multiTime);

    compareCombination(`weekDay 多值（${d1} + ${d2}）`, multiDay, [
        combos[`${d1}-${w1}-${p1}`],
        combos[`${d2}-${w1}-${p1}`],
    ]);
    compareCombination(`weekList 多值（${w1} + ${w2}）`, multiWeek, [
        combos[`${d1}-${w1}-${p1}`],
        combos[`${d1}-${w2}-${p1}`],
    ]);
    compareCombination(`timeList 多值（${p1} + ${p2}）`, multiTime, [
        combos[`${d1}-${w1}-${p1}`],
        combos[`${d1}-${w1}-${p2}`],
    ]);

    // 三个维度同时多值 vs 8 个单点组合
    const multiAll = await fetchSet({
        ...filter,
        weekDay: [d1, d2],
        weekList: [w1, w2],
        timeList: [p1, p2],
    });
    describeSet(
        `F(day=[${d1},${d2}], week=[${w1},${w2}], period=[${p1},${p2}])`,
        multiAll,
    );
    compareCombination("三个维度同时多值 vs 8 个单点组合", multiAll, Object.values(combos));

    await runFilterChecks(scope, d1, w1, p1, combos[`${d1}-${w1}-${p1}`]);
}

/** 过滤器（楼号 / 场地类别 / 教室名）与时间条件是否也是「与」 */
async function runFilterChecks(
    scope: RelationScope,
    day: number,
    week: number,
    period: number,
    baseSet: SetResult,
) {
    const time = {weekDay: day, weekList: week, timeList: period};
    const filter = scope.building ? {building: scope.building} : {};
    note("过滤器与时间条件的关系：检查过滤结果是否全部落在未过滤结果内");

    if (scope.building) {
        const page = await query({...time, ...filter, pageNum: 1, pageSize: 500});
        const items = page.json?.data?.items ?? [];
        const mismatches = scope.name
            ? items.filter(item => item.building !== scope.name)
            : [];
        note(
            `  楼号过滤：本页 ${items.length} 条，building 字段与选项名不一致 ${mismatches.length} 条` +
                (mismatches.length ? `（示例：${mismatches[0].building}）` : ""),
        );
    }

    const place = await pickPlace();
    if (place) {
        const withPlace = await fetchSet({...filter, ...time, place: place.label});
        const allFromBase = [...withPlace.keys].every(key => baseSet.keys.has(key));
        const page = await query({
            ...filter,
            ...time,
            place: place.label,
            pageNum: 1,
            pageSize: 500,
        });
        const items = page.json?.data?.items ?? [];
        const mismatches = items.filter(item => item.placeType !== place.name);

        note(
            `  场地类别过滤（label=${place.label} ${place.name}）：${withPlace.keys.size} 个教室，` +
                `全部包含于未加该过滤的结果=${allFromBase}`,
        );
        note(
            `    placeType 字段与选项名不一致 ${mismatches.length} 条` +
                (mismatches.length ? `（示例：${mismatches[0].placeType}）` : ""),
        );
    }

    const sampleKey = [...baseSet.keys][0];
    const sampleName = sampleKey?.split("\u0000")[1];
    if (sampleName) {
        const withName = await fetchSet({...filter, ...time, roomName: sampleName});
        const allMatch = [...withName.keys].every(key =>
            (key.split("\u0000")[1] ?? "").includes(sampleName),
        );

        note(
            `  roomName 过滤（关键字="${sampleName}"）：${withName.keys.size} 个教室，` +
                `名称全部包含关键字=${allMatch}，包含基准教室=${withName.keys.has(sampleKey)}`,
        );
    }
}

// ---------------- SQLite 结构基准（--bench-sqlite） ----------------

type BenchRoom = {
    name: string;
    building: string;
    placeType: string;
    seats: number | null;
    examSeats: number | null;
};

type BenchHandle = {
    label: string;
    file: string;
    db: any;
    insertMs: number;
    size: {bytes: number; pageSize: number; pageCount: number};
    idMap: Map<string, number> | null;
};

type BenchSuite = {
    weekAll: {medianMs: number; rows: number};
    oneRoom: {medianMs: number; rows: number};
    oneSlot: {medianMs: number; rows: number};
    building: {medianMs: number; rows: number} | null;
};

function benchNowMs(): number {
    return Number(process.hrtime.bigint()) / 1e6;
}

async function fetchBenchRooms(): Promise<BenchRoom[]> {
    const items: ClassroomItem[] = [];
    for (let page = 1; page <= 10; page += 1) {
        const res = await query({
            weekDay: 1,
            weekList: 1,
            timeList: 1,
            pageNum: page,
            pageSize: 500,
        });
        if (res.status !== 200 || res.json?.code !== 200) {
            throw new Error(`HTTP ${res.status} · ${describeBody(res.json, res.text)}`);
        }
        const data = res.json.data;
        if (!data || !Array.isArray(data.items) || data.items.length === 0) break;
        items.push(...data.items);
        if (items.length >= (data.totalCount ?? 0)) break;
    }
    if (items.length === 0) throw new Error("基准数据为空");

    const seen = new Set<string>();
    const rooms: BenchRoom[] = [];
    for (const item of items) {
        const key = `${item.building}\u0000${item.classroomName}`;
        if (seen.has(key)) continue;
        seen.add(key);
        rooms.push({
            name: item.classroomName,
            building: item.building,
            placeType: item.placeType,
            seats: Number(item.seatCount) || null,
            examSeats: Number(item.seatCountForExam) || null,
        });
    }
    return rooms;
}

function benchDbSize(fs: any, file: string) {
    const db = new (require("node:sqlite").DatabaseSync)(file);
    const pageSize = db.prepare("PRAGMA page_size").get().page_size;
    const pageCount = db.prepare("PRAGMA page_count").get().page_count;
    db.close();
    return {bytes: fs.statSync(file).size, pageSize, pageCount};
}

function benchFmtMb(bytes: number): string {
    return `${(bytes / 1024 / 1024).toFixed(2)} MB`;
}

async function runSqliteBenchmark() {
    section("六、SQLite 结构基准（--bench-sqlite）");

    let DatabaseSync: any;
    try {
        DatabaseSync = require("node:sqlite").DatabaseSync;
    } catch {
        note("当前 Node 没有 node:sqlite（需要 Node >= 22.5），跳过");
        return;
    }
    if (!DatabaseSync) {
        note("当前 Node 没有 node:sqlite，跳过");
        return;
    }
    if (!termPair) {
        note("未解析到学期，无法生成基准数据");
        return;
    }

    const fs: any = require("node:fs");
    const path: any = require("node:path");
    const cacheRoot = path.join(process.cwd(), ".bench-cache");
    const dbDir = path.join(cacheRoot, "sqlite");
    fs.mkdirSync(dbDir, {recursive: true});

    const lines: string[] = [];
    const log = (text = "") => {
        console.log(text);
        lines.push(text);
    };

    let rooms: BenchRoom[];
    try {
        rooms = await fetchBenchRooms();
    } catch (error) {
        note(`拉取基准数据失败：${error instanceof Error ? error.message : String(error)}`);
        return;
    }

    const Y = termPair.year;
    const T = termPair.term;
    const W = 1;
    const oneSlot: Array<[number, number]> = [[1, 1]];
    const oneWeek: Array<[number, number]> = [];
    for (let day = 1; day <= 7; day += 1) {
        for (let period = 1; period <= 13; period += 1) oneWeek.push([day, period]);
    }
    const sample = rooms[0];

    log(`数据：${rooms.length} 间教室，学期 ${Y}/${T}（第 ${W} 周，周一第 1 节取数）`);

    const SINGLE_DDL = `
CREATE TABLE slot_single (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  year INTEGER NOT NULL, term INTEGER NOT NULL, week INTEGER NOT NULL,
  day INTEGER NOT NULL, period INTEGER NOT NULL,
  roomName TEXT NOT NULL, building TEXT NOT NULL, placeType TEXT NOT NULL,
  seatCount INTEGER, seatCountForExam INTEGER
);
CREATE INDEX idx_single_slot ON slot_single(year, term, week, day, period);
`;
    const NORMAL_DDL = `
CREATE TABLE room (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL, building TEXT NOT NULL, placeType TEXT NOT NULL,
  seatCount INTEGER, seatCountForExam INTEGER
);
CREATE UNIQUE INDEX room_unique ON room(building, name);
CREATE TABLE slot_norm (
  year INTEGER NOT NULL, term INTEGER NOT NULL, week INTEGER NOT NULL,
  day INTEGER NOT NULL, period INTEGER NOT NULL, roomId INTEGER NOT NULL,
  PRIMARY KEY (year, term, week, day, period, roomId)
);
`;
    const SINGLE_ROOM_INDEX =
        "CREATE INDEX idx_single_room ON slot_single(building, roomName, year, term, week)";
    const SINGLE_BUILDING_INDEX =
        "CREATE INDEX idx_single_building ON slot_single(year, term, week, building)";
    const NORM_ROOM_INDEX =
        "CREATE INDEX idx_norm_room ON slot_norm(roomId, year, term, week, day, period)";
    const NORM_BUILDING_INDEX = "CREATE INDEX room_building ON room(building)";

    function freshDb(file: string, ddl: string, extraIndexes: string[] = []) {
        fs.rmSync(file, {force: true});
        const db = new DatabaseSync(file);
        db.exec("PRAGMA journal_mode=DELETE");
        db.exec(ddl);
        for (const sql of extraIndexes) db.exec(sql);
        return db;
    }

    function insertSingle(
        db: any,
        slots: Array<[number, number]>,
    ): number {
        const insert = db.prepare(
            "INSERT INTO slot_single (year,term,week,day,period,roomName,building,placeType,seatCount,seatCountForExam) VALUES (?,?,?,?,?,?,?,?,?,?)",
        );
        const started = benchNowMs();
        db.exec("BEGIN");
        for (const [day, period] of slots) {
            for (const room of rooms) {
                insert.run(
                    Y, T, W, day, period,
                    room.name, room.building, room.placeType, room.seats, room.examSeats,
                );
            }
        }
        db.exec("COMMIT");
        return benchNowMs() - started;
    }

    function insertNormal(
        db: any,
        slots: Array<[number, number]>,
    ): {insertMs: number; idMap: Map<string, number>} {
        const insertRoom = db.prepare(
            "INSERT INTO room (name,building,placeType,seatCount,seatCountForExam) VALUES (?,?,?,?,?)",
        );
        const insertSlot = db.prepare(
            "INSERT INTO slot_norm (year,term,week,day,period,roomId) VALUES (?,?,?,?,?,?)",
        );
        const idMap = new Map<string, number>();
        const started = benchNowMs();
        db.exec("BEGIN");
        for (const room of rooms) {
            const result = insertRoom.run(
                room.name, room.building, room.placeType, room.seats, room.examSeats,
            );
            idMap.set(`${room.building}\u0000${room.name}`, Number(result.lastInsertRowid));
        }
        for (const [day, period] of slots) {
            for (const room of rooms) {
                insertSlot.run(
                    Y, T, W, day, period,
                    idMap.get(`${room.building}\u0000${room.name}`),
                );
            }
        }
        db.exec("COMMIT");
        return {insertMs: benchNowMs() - started, idMap};
    }

    function buildSingle(
        label: string,
        slots: Array<[number, number]>,
        extraIndexes: string[] = [],
    ): BenchHandle {
        const file = path.join(dbDir, `${label}.db`);
        const db = freshDb(file, SINGLE_DDL, extraIndexes);
        const insertMs = insertSingle(db, slots);
        db.exec("VACUUM");
        return {label, file, db, insertMs, size: benchDbSize(fs, file), idMap: null};
    }

    function buildNormalized(
        label: string,
        slots: Array<[number, number]>,
        extraIndexes: string[] = [],
    ): BenchHandle {
        const file = path.join(dbDir, `${label}.db`);
        const db = freshDb(file, NORMAL_DDL, extraIndexes);
        const {insertMs, idMap} = insertNormal(db, slots);
        db.exec("VACUUM");
        return {label, file, db, insertMs, size: benchDbSize(fs, file), idMap};
    }

    function benchQuery(
        db: any,
        sql: string,
        params: Array<string | number>,
        iterations: number,
    ) {
        const statement = db.prepare(sql);
        statement.all(...params);
        const times: number[] = [];
        let rows = 0;
        for (let i = 0; i < iterations; i += 1) {
            const started = benchNowMs();
            rows = statement.all(...params).length;
            times.push(benchNowMs() - started);
        }
        times.sort((left, right) => left - right);
        return {medianMs: times[Math.floor(times.length / 2)], rows};
    }

    function querySuite(handle: BenchHandle, room: BenchRoom): BenchSuite {
        const db = handle.db;
        const single = handle.label.startsWith("S");
        const roomId = single
            ? null
            : handle.idMap?.get(`${room.building}\u0000${room.name}`);

        const weekAll = benchQuery(
            db,
            single
                ? "SELECT roomName,building,placeType,day,period FROM slot_single WHERE year=? AND term=? AND week=?"
                : "SELECT r.name,r.building,r.placeType,s.day,s.period FROM slot_norm s JOIN room r ON r.id=s.roomId WHERE s.year=? AND s.term=? AND s.week=?",
            [Y, T, W],
            5,
        );
        const oneRoom = benchQuery(
            db,
            single
                ? "SELECT day,period FROM slot_single WHERE year=? AND term=? AND week=? AND building=? AND roomName=?"
                : "SELECT day,period FROM slot_norm WHERE year=? AND term=? AND week=? AND roomId=?",
            single ? [Y, T, W, room.building, room.name] : [Y, T, W, roomId as number],
            20,
        );
        const oneSlot = benchQuery(
            db,
            single
                ? "SELECT roomName,building,placeType FROM slot_single WHERE year=? AND term=? AND week=? AND day=? AND period=?"
                : "SELECT r.name,r.building,r.placeType FROM slot_norm s JOIN room r ON r.id=s.roomId WHERE s.year=? AND s.term=? AND s.week=? AND s.day=? AND s.period=?",
            [Y, T, W, 1, 1],
            20,
        );
        const building = benchQuery(
            db,
            single
                ? "SELECT roomName,day,period FROM slot_single WHERE year=? AND term=? AND week=? AND building=?"
                : "SELECT r.name,s.day,s.period FROM slot_norm s JOIN room r ON r.id=s.roomId WHERE s.year=? AND s.term=? AND s.week=? AND r.building=?",
            single ? [Y, T, W, room.building] : [Y, T, W, room.building],
            20,
        );
        return {weekAll, oneRoom, oneSlot, building};
    }

    function printSuite(handle: BenchHandle, suite: BenchSuite) {
        log(
            `  ${handle.label.padEnd(18)} ${benchFmtMb(handle.size.bytes).padStart(9)}` +
                ` (${handle.size.pageCount}×${handle.size.pageSize})  ` +
                `插入 ${handle.insertMs.toFixed(0).padStart(5)} ms  ` +
                `整周 ${suite.weekAll.medianMs.toFixed(1).padStart(6)} ms  ` +
                `单教室 ${suite.oneRoom.medianMs.toFixed(3).padStart(7)} ms  ` +
                `单格 ${suite.oneSlot.medianMs.toFixed(2).padStart(5)} ms  ` +
                `楼栋 ${(suite.building?.medianMs ?? 0).toFixed(2).padStart(6)} ms`,
        );
    }

    const handles: BenchHandle[] = [];

    log("\n===== 单格（约 1621 行）=====");
    const s1 = buildSingle("S1_single_slot", oneSlot);
    const n1 = buildNormalized("N1_single_slot", oneSlot);
    handles.push(s1, n1);
    printSuite(s1, querySuite(s1, sample));
    printSuite(n1, querySuite(n1, sample));

    log("\n===== 整周（91 格，约 147,511 行）=====");
    const sBase = buildSingle("S91_base", oneWeek);
    const sRoom = buildSingle("S91_room_idx", oneWeek, [SINGLE_ROOM_INDEX]);
    const sAll = buildSingle("S91_all_idx", oneWeek, [
        SINGLE_ROOM_INDEX,
        SINGLE_BUILDING_INDEX,
    ]);
    const nBase = buildNormalized("N91_base", oneWeek);
    const nRoom = buildNormalized("N91_room_idx", oneWeek, [NORM_ROOM_INDEX]);
    const nAll = buildNormalized("N91_all_idx", oneWeek, [
        NORM_ROOM_INDEX,
        NORM_BUILDING_INDEX,
    ]);
    handles.push(sBase, sRoom, sAll, nBase, nRoom, nAll);
    for (const handle of handles.slice(-6)) {
        printSuite(handle, querySuite(handle, sample));
    }

    log("\n===== 抽离表：楼栋查询的三种写法（N91_all_idx）=====");
    const buildingVariants: Array<[string, string, Array<string | number>]> = [
        [
            "A 普通 JOIN（从 slot 扫）",
            "SELECT r.name,s.day,s.period FROM slot_norm s JOIN room r ON r.id=s.roomId WHERE s.year=? AND s.term=? AND s.week=? AND r.building=?",
            [Y, T, W, sample.building],
        ],
        [
            "B room 驱动 + INDEXED BY",
            "SELECT r.name,s.day,s.period FROM room r CROSS JOIN slot_norm s INDEXED BY idx_norm_room WHERE r.building=? AND s.roomId=r.id AND s.year=? AND s.term=? AND s.week=?",
            [sample.building, Y, T, W],
        ],
        [
            "C roomId IN 子查询",
            "SELECT r.name,s.day,s.period FROM slot_norm s JOIN room r ON r.id=s.roomId WHERE s.year=? AND s.term=? AND s.week=? AND s.roomId IN (SELECT id FROM room WHERE building=?)",
            [Y, T, W, sample.building],
        ],
    ];
    for (const [label, sql, params] of buildingVariants) {
        const result = benchQuery(nAll.db, sql, params, 20);
        const plan = nAll.db
            .prepare(`EXPLAIN QUERY PLAN ${sql}`)
            .all(...params)
            .map((item: any) => item.detail)
            .join(" | ");
        log(
            `  ${label.padEnd(24)} ${result.medianMs.toFixed(3).padStart(7)} ms (${result.rows} 行)`,
        );
        log(`    计划: ${plan}`);
    }

    log("\n数据库文件（可直接用 SQLite 工具打开）：");
    for (const handle of handles) log(`  ${handle.file}`);
    const reportFile = path.join(cacheRoot, "latest.txt");
    fs.writeFileSync(reportFile, lines.join("\n"), "utf8");
    log(`\n报告：${reportFile}`);

    for (const handle of handles) handle.db.close();
}

// ---------------- 工具 ----------------

function readInt(name: string, value: string | number, min: number, max: number): number {
    const number = Number(value);
    if (!Number.isInteger(number) || number < min || number > max) {
        console.error(`参数 --${name} 必须是 ${min}~${max} 的整数，收到：${value}`);
        process.exit(2);
    }
    return number;
}

function stripTrailingSlash(value: string): string {
    return String(value).replace(/\/+$/, "");
}

function mask(value: string): string {
    const text = String(value);
    if (text.length <= 5) return "*".repeat(text.length);
    return `${text.slice(0, 3)}****${text.slice(-2)}`;
}

function printHelp() {
    console.log(`
空闲教室接口冒烟测试

用法：
  npx tsx test.ts [选项]

选项：
  --base <url>        后端地址，默认 http://api.tool.gxutech.xyz
  --cookie <cookie>   教务会话 Cookie（JSESSIONID=...; route=...）
  --username <学号>   与 --password 一起使用，先调 /jw/login
  --password <密码>
  --day <1-7>         星期，默认 1
  --week <1-20>       周次，默认 1
  --time <1-13>       节次，默认 1
  --page-size <n>     每页条数，默认 5（上限 500）
  --year <year>       学年；与 --term 一起覆盖自动识别
  --term <1|2>        学期
  --check-unauth      额外验证未登录查询返回 401
  --relations         参数与结果关系实验（多值是「与」还是「或」）
  --building <label>  关系实验限定的楼号（默认自动挑一个教学楼）
  --place <label>     关系实验限定的场地类别（默认「普通」）
  --bench-sqlite      单表 vs 教室抽离的 SQLite 空间/查询基准
                      （生成物在 ./.bench-cache/sqlite/）
  --verbose           打印每个请求的 URL（不会打印 Cookie）
  --help              显示本帮助

环境变量：BASE_URL / JW_COOKIE / JW_USERNAME / JW_PASSWORD

退出码：0 全部通过；1 存在失败；2 参数错误。
`);
}

// ---------------- 启动 ----------------

main().catch(error => {
    console.error(`脚本异常：${error instanceof Error ? error.stack || error.message : String(error)}`);
    process.exitCode = 1;
});
