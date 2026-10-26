# 空闲教室功能实现计划

## Context

在 `gxu_tool_app` 中新增"空闲教室"功能，模仿个人课表工具，但不做实时查询：用户选择"学期 + 周次 + 教室"，从本地 SQLite 缓存渲染该教室一周的空闲时间。缓存管理页负责按周下载/删除数据。

已确认的关键决策：

1. **抓取方式：前端按天抓，后端配合放开页大小。** 正方接口的多值 `timeList` 是「与」语义，一次请求只能查一个 `(weekDay, timeList)`；一个教学日拆成 13 个节次请求，7 天串行。后端把 `pageSize` 上限从 500 放开到 10000 后，每个节次预期 1 页：**约 91 次请求/周、gzip 后约 1.3 MB/周、SQLite 约 5.5 MB**。若正方仍按 500 强制分页，前端 pagination 按 `totalCount` 自动继续翻页，回退为 364 次/周，不丢数据。
2. **周切换：左右滑动 pager（更像主课表）。** 复用 `TimeScheduleView` 的 20 页 pager；未缓存/未完成周在网格上方显示提示，提示卡片外的区域仍可左右滑动。
3. **路径：所有新增代码只放在 `src/features/emptyClassroom/` 下，按模块分目录。** 不在 `src/screens`、`src/js`、`src/type` 新增文件；只修改既有的 `src/core/schema.ts`、`src/route/screens/ToolboxStack.tsx`、`src/screens/tool/ToolboxIndex.tsx`、`TimeScheduleView.tsx` 和迁移注册文件。
4. **接口类型来自 adapter 库。** API 边界使用 `gxu-tool-adapters/jw` 的 `EmptyClassroom` 类型，不在 app 里重复定义 `ClassroomItem`。本计划使用 `import type {EmptyClassroom} from "gxu-tool-adapters/jw"`。
5. **后端改动单独拉分支并本地提交。** `tool-mono-repo` 从 `main` 拉 `feat/empty-classroom-page-size-gzip`：`pageSize` 上限 500→10000、引入 gzip 压缩、删除 `EmptyClassroomService` 的 `console.log(res)`、同步 DTO spec/README。app 从 `v2.2` 拉 `feat/empty-classroom`，所有改动分阶段本地 commit，**不 push**。后端先部署，app 再发版；app API 对旧后端 400 做一次 500 回退。

接口事实、测量数据见 `docs/empty-classroom-research.md`；请求样例见根目录 `test.ts`。

---

## 0. 前置：更新 adapter 依赖

当前 app 里的 `gxu-tool-adapters`（git 安装，1.0.0）和 `@gxutool/adapters`（1.0.1）的 `dist/jw/index.d.ts` **都没有** `emptyClassroom` 导出；mono 仓库 `tool-mono-repo/packages/adapters`（`@gxutool/adapters` 1.1.1）的源码已经导出：

```ts
export {parseEmptyClassroom} from './emptyClassroom/parser.js';
export type {EmptyClassroom} from './emptyClassroom/schema.js';
```

因此实现 API 层前必须：

1. app 现有业务实际 import 的是 `gxu-tool-adapters/jw`，优先把 **这个 alias** 更新到包含 `emptyClassroom` 的 adapter commit/tag（或从 mono 仓库 build/publish 1.1.1），执行 `pnpm install`。不要为了本功能全局改既有 import 到 `@gxutool/adapters/jw`；那是另一件事。
2. 验证 `node_modules/gxu-tool-adapters/dist/jw/index.d.ts` 含 `EmptyClassroom`，且 `dist/jw/emptyClassroom/schema.d.ts` 存在。
3. 如果 git 依赖暂时无法更新，先在 adapter 仓库补导出/发版并更新 app 依赖；**不要在 app 内复制 `EmptyClassroom` 接口**。
4. 更新后跑一次 `npx tsc --noEmit`，确认既有 `Schedule`/`SelectedCourse` 等 adapter 导入没有 breaking change。

adapter 的 `EmptyClassroom` 就是后端清洗后的分页结构：

```ts
type EmptyClassroom = {
    totalPage?: number;
    totalCount?: number;
    currentPage?: number;
    items: {
        classroomName: string;
        placeType: string;
        seatCount: string;
        seatCountForExam: string;
        building: string;
        owner: string;
        user: string;
        allowToUse: string;
        currentPage: number;
    }[];
};
```

app 的 `type/index.ts` 只派生：

```ts
import type {EmptyClassroom} from "gxu-tool-adapters/jw";
export type ClassroomPage = EmptyClassroom;
export type ClassroomItem = EmptyClassroom["items"][number];
```

Zod schema 负责校验后端信封里的 `data`，输出类型标注为 `EmptyClassroom`；DB/UI 的 `RoomPayload` 从 `ClassroomItem` 派生并把座位数转成 number|null。

---

## 0.5 后端改动（`tool-mono-repo`，独立分支）

后端仓库当前在 `main`、工作区干净。执行前确认 `D:\Programs\tool-mono-repo` 可写（当前环境已把它从 additional working directories 移除，必要时重新加入）。

### 分支与提交

```bash
cd D:/Programs/tool-mono-repo
git switch -c feat/empty-classroom-page-size-gzip
```

所有改动完成后本地提交，不 push：

```bash
git add apps/backend/src/main.ts \
        apps/backend/src/jw-system/emptyClassroom/dto/emptyRoom.dto.ts \
        apps/backend/src/jw-system/emptyClassroom/dto/emptyRoom.dto.spec.ts \
        apps/backend/src/jw-system/emptyClassroom/emptyClassroom.service.ts \
        apps/backend/README.md \
        apps/backend/package.json pnpm-lock.yaml
git commit -m "feat(empty-classroom): raise page size cap to 10000 and enable gzip"
```

### 改动清单

1. **`apps/backend/src/jw-system/emptyClassroom/dto/emptyRoom.dto.ts`**
   - `@Max(500)` → `@Max(10000)`；注释同步为"上限 10000，用于一次取回整个节次"。
2. **`apps/backend/src/jw-system/emptyClassroom/dto/emptyRoom.dto.spec.ts`**
   - 把 `rejects pageSize above the 500 cap` 改成 10000 上限（`10001` 拒绝）；
   - 新增 `accepts pageSize=10000` 的用例，断言 `dto.pageSize === 10000`。
3. **`apps/backend/src/main.ts`**
   - `import compression from "compression";`
   - 在 `app.use(cookieParser());` 后加 `app.use(compression({threshold: 1024}));`
   - gzip 对所有 JSON 响应生效；`TransformInterceptor` 在压缩之前，不受影响。
4. **`apps/backend/package.json`**
   - `dependencies` 加 `compression`；`devDependencies` 加 `@types/compression`。
   - 在 mono 仓库根执行 `pnpm --filter tool-app-be add compression` 和 `pnpm --filter tool-app-be add -D @types/compression`，提交 `pnpm-lock.yaml`。
5. **`apps/backend/src/jw-system/emptyClassroom/emptyClassroom.service.ts`**
   - 删除 `getEmptyClassroom` 里的 `console.log(res)`；否则 91 次/周、每次约 350KB 的原始响应会打出约 32MB 日志。
6. **`apps/backend/README.md`**
   - 第 205 / 270 行的"上限 500"改为"上限 10000"；
   - 第 357 行"长度 = pageSize，要拿全部必须逐页取"补一句：`pageSize=10000` 时预期一页返回全部；若正方强制按更小页返回，客户端按 `totalCount` 继续翻页。
7. **不要改** `parseEmptyClassroom`/adapter 的返回结构；app 的 adapter 类型更新是独立的前置步骤（见上一节）。

### 后端验证

```bash
cd D:/Programs/tool-mono-repo
pnpm --filter tool-app-be test          # DTO spec，含 10000 上限
pnpm --filter tool-app-be build
pnpm --filter tool-app-be start:dev     # 或现有本地启动方式
```

- `curl -H "Accept-Encoding: gzip" -D - ...` 确认 `Content-Encoding: gzip`；
- `curl -H "Accept-Encoding: identity" ...` 确认未压缩可读；
- 用一个有效 JW Cookie 调 `/jw/emptyClassroom?...&pageSize=10000`，记录 `items.length`、`totalCount`、`totalPage` 和响应时间：
  - 若 `items.length ≈ totalCount`（约 1,600–1,700），说明正方接受 10000，app 一周 91 次请求；
  - 若 `items.length` 只有 500 而 `totalCount` 约 1,690，说明正方仍按 500 分页，app 的 pagination 会按 `totalCount` 继续 4 页/节（回退为 364 次/周），功能不受影响；
  - 若正方直接报错/超时，保留 500 回退路径，并在计划风险里记录。
- 验证 gzip 对 app 透明：用 Android 真机请求，确认 `res.data` 是 JSON、不是二进制；**不要手动设置 `Accept-Encoding`**，让 OkHttp 自动加头并透明解压。
- 后端部署顺序：先部署后端，再发 app。app 的 API 对旧后端（max 500）的 400 做一次 500 回退，避免灰度期间缓存失败。

---

## 1. 需求清单

- 第一屏：学期选择器、教室选择、周 pager、复用 `TimeSchedule` 网格渲染所选教室的空闲时段；只读本地缓存，不发实时查询。
- 未缓存/未完成周：网格区域提示 + "去缓存"入口（顶部 header 也常驻"缓存管理"）。
- 缓存管理页（push 新页面）：
  - 学期选择器；
  - 第 1–20 周列表，区分已缓存/未缓存/未完成；
  - 已缓存显示周数据大小（估算）、缓存时间；
  - 单周下载（缓存）、删除；
  - 缓存中显示进度条（按天/节）和取消；
  - 前端限流：每分钟最多开始缓存一周，持久化，重启后仍生效。
- 缓存粒度：一天一批；每天 13 个节次依次请求；7 天依次推进；失败/取消保留已完成的天，下次续传。
- 后端配合：`pageSize` 上限 500→10000、全局 gzip、删除 `console.log(res)`；后端从 `main` 拉分支，所有改动本地提交，不 push。
- app 从 `v2.2` 拉 feature 分支，分阶段本地提交，不 push。

---

## 2. 数据模型

新增到 `src/core/schema.ts`（Drizzle），生成并注册迁移 `0003`。

### `emptyClassroomRooms`（教室维表）

| 列 | 类型 | 说明 |
|---|---|---|
| id | integer PK autoincrement | 内部教室 id |
| name | text notNull | `classroomName` |
| building | text notNull | 楼栋名（接口返回 `jxlmc`，是名称不是编码） |
| placeType | text notNull default "" | 场地类别 |
| seatCount | integer nullable | 座位数 |
| seatCountForExam | integer nullable | 考试座位数 |
| owner | text notNull default "" | 所属单位 |
| allowToUse | text notNull default "" | 是否可用 |
| updatedAt | integer timestamp notNull | 写入时间 |

唯一索引 `(building, name)`：接口没有暴露稳定的 `cdbh`，只能用楼栋 + 教室名作为业务键。`onConflictDoNothing` 依赖这个唯一索引。

### `emptyClassroomSlots`（教室-时间事实表，只存空闲）

| 列 | 类型 |
|---|---|
| year, term, week, day, period, roomId | integer notNull |

复合主键 `(year, term, week, day, period, roomId)`。**不建额外索引**（调研结论：单教室查询约 10 ms，足够；额外索引每周 +1.5～2.8 MB 不值得）。`term` 存逻辑学期 `1|2`。

### `emptyClassroomDays`（按天进度，断点续传的唯一真相）

| 列 | 类型 |
|---|---|
| year, term, week, day | integer notNull，复合 PK |
| fetchedAt | integer timestamp notNull |
| slotCount | integer notNull default 0 |

一天的数据在同一个事务里写入 slots + day 行 + snapshot；中断/崩溃时该天回滚，下次从该天重抓。最多丢一天（13 个节次）。

### `emptyClassroomSnapshots`（周快照元数据）

| 列 | 类型 | 说明 |
|---|---|---|
| year, term, week | integer notNull | 复合 PK |
| fetchedAt | integer timestamp notNull | 最近一次写入/完成时间 |
| completedDays | integer notNull default 0 | 0–7 |
| slotCount | integer notNull default 0 | 本周空闲记录数 |
| roomCount | integer notNull default 0 | 本周涉及教室数 |
| complete | integer boolean notNull default false | 7 天全部完成 |

**不存 `sizeBytes`**：大小由 `slotCount/roomCount` 在渲染时用公式算，避免公式调整后旧行留下过期值。**不引入 `beginWeek`**：snapshot 只在某一天成功保存时由 `saveDay` 原子创建；否则取消/鉴权失败会留下 `0/7` 的幽灵周。`completedDays === 0` 的 snapshot 视为未缓存。

---

## 3. 抓取算法

### 3.1 API 层 `src/features/emptyClassroom/api/`

**`schema/index.ts`**：Zod 校验后端信封 `{code,message,data}` 的 `data`；输出 `EmptyClassroom`。
- `classroomName`/`building` 必填；其余字符串字段给默认 `""`。
- `seatCount`/`seatCountForExam` 保持字符串（与 adapter 类型一致），到 `RoomPayload` 再转 number|null。
- `totalPage`/`totalCount` 可缺省；`currentPage` 完全忽略。
- `data === null` 或 `items` 非数组：先 `ensureJwAuthenticated()` 重试一次，仍失败抛"教务系统返回异常（登录可能已失效）"。**不要静默当空结果**，否则会把一周标成 0 条已缓存。

**`api/pagination.ts`**：纯函数 `collectSlotPages(fetchPage, {pageSize, maxPages})`：
- 第 1 页开始，顺序翻页。
- **优先按 `totalCount` 判断完整性**：只要 `totalCount` 存在且累计行数 < `totalCount`，就继续下一页，即使当前页 `items.length < pageSize`（这是为了兼容"后端允许 10000、但正方仍按 500 返回"的情况）。
- `totalCount` 缺省时：有 `totalPage` 就翻到 `pageNum >= totalPage`；两者都缺省才用短页（`items.length < pageSize`）判定结束。
- 空页一律停止。
- 不信 `currentPage`。
- 上限 `MAX_PAGES = 10`（10000 时预期 1 页；正方强制 500 时 4 页）。
- 如果 `totalCount` 存在且翻到上限仍不足，抛 typed incomplete-data 错误，**不要静默缓存截断数据**。
- 对下游按 `roomKey` 去重，但完整性判断用原始行数。

**`api/index.ts`**：

```ts
fetchDay(
  {year, term, week, day},
  {ensureAuth, shouldCancel, pageSize: PAGE_SIZE},
  onPeriod?: (day: number, period: number) => void,
): Promise<DayPayload>
```

- `period 1..13` 顺序；每个 period 调 `collectSlotPages`。
- 请求：
  ```ts
  backendHttp.get("/jw/emptyClassroom", {
      params: {weekDay:[day], weekList:[week], timeList:[period], year, term, pageNum, pageSize: PAGE_SIZE},
      paramsSerializer: {indexes: null},
      timeout: 30000,
  });
  ```
  `paramsSerializer: {indexes:null}` 生成重复键；默认 `weekDay[]=1` 会被后端 400。后端 `JwHttpService` 没有显式超时，单页给 30s。
- `year + term` 每个请求都成对带。
- HTTP 401/403 或 envelope `code===401`：每个任务最多调一次 `ensureAuth()`，然后重试同一请求；失败抛 typed auth error。
- 网络错误/5xx 最多重试 2 次（~800ms 间隔）；400 不重试。
- 每个 period 前后检查 `shouldCancel()`。
- 合并当天：
  - `rooms: Map<roomKey, RoomPayload>`（同一教室元数据第一份为准）
  - `freePeriods: Map<roomKey, number[]>`（每个 period 追加一次）
  - 页面数组用完即弃，不保留。
- `roomKey = building + "\u0000" + classroomName`；`RoomPayload` 由 `ClassroomItem` 派生，`seatCount/seatCountForExam` 用 `parseInt` 转 number|null，`building/name` trim，空名跳过。
- 只在一个任务启动时调用一次 `ensureJwAuthenticated()`，不要每页调用（否则多出 91/364 次 token 测试请求）。
- **页大小兼容**：`PAGE_SIZE = 10000`；如果旧后端对 `pageSize=10000` 返回 400（DTO 仍 `@Max(500)`），API 捕获这次 400，改用 `PAGE_SIZE_FALLBACK = 500` 重试同一请求，并把有效页大小记到本次 task 的共享 session（后续节次/天直接用 500，不重复 400）。后端先部署后，10000 正常生效。
- **gzip**：不要在 `backendHttp` 或本接口手动设置 `Accept-Encoding`。React Native 的 OkHttp 会自动加 `Accept-Encoding: gzip` 并透明解压；手动设置反而可能让 OkHttp 不解压。真机验证 `res.data` 是 JSON、`Content-Encoding: gzip` 生效。
- `test.ts` 是 Node 原生 http/https，不会自动解压 gzip；给它的请求加 `Accept-Encoding: identity`（或 zlib 解压），否则后端 gzip 后脚本会解析失败。

### 3.2 缓存 runner service `src/features/emptyClassroom/services/cacheRunner.ts`

纯编排、依赖注入，便于 Jest 用 fake 测试：

```ts
runWeekCache(
  {year, term, week},
  {
    repo: {getCompletedDays, saveDay, completeWeek},
    api: {fetchDay},
    ensureAuth: () => Promise<boolean>,
    beforeFirstRequest: () => void,
    onProgress: (p: {day; period; completedDays: number[]}) => void,
    onDaySaved: (day: number, completedDays: number[]) => void,
    shouldCancel: () => boolean,
  },
): Promise<{completedDays: number[]; complete: boolean; canceled: boolean}>
```

算法：

1. 先读 `getCompletedDays`；7 天已齐 → `completeWeek` 并返回，**不鉴权、不消耗冷却、不发请求**。
2. `ensureAuth()`；失败抛 auth error，**不消耗冷却**。
3. 在第一次真正发数据请求前调用一次 `beforeFirstRequest()`（store 在这里写 `lastStartedAt`）。
4. `day 1..7` 跳过已完成天；每天 `fetchDay`（内部 13 个 period）。
5. 每个 period 完成回调 `onProgress`；每个 period 之间检查取消。
6. 一天 13 节全部抓完 → `saveDay`（**即使此时收到取消也保存**，只丢弃抓了一半的天）→ `onDaySaved`。
7. 7 天齐 → `completeWeek`。
8. 取消：当前天抓完则保存，然后停止；已完成天保留。
9. 任意错误：停止并抛出；已完成天保留。

### 3.3 runner store `src/features/emptyClassroom/stores/cacheRunnerStore.ts`

Zustand，模块级常驻，离开缓存页后继续跑：

```ts
{
  task: CacheTask | null;          // year/term/week/phase/day/period/completedDays[]/pageSize
  error: {year; term; week; message} | null;
  lastStartedAt: number;           // 启动时从 MMKV 同步恢复
  revision: number;                // DB 状态变化时 +1，供 hooks 刷新
  start(year, term, week): Promise<StartResult>;
  cancel(): void;
  clearError(): void;
}
```

- `start` 顺序：
  1. 同步检查 `task` 是否存在 → `busy`。
  2. 读 `getCompletedDays`；7 天已齐 → `completeWeek` 并返回 `done`（不冷却、不鉴权）。
  3. 检查 MMKV `emptyClassroom:lastCacheStartedAt`，距现在 < 60s → `cooldown` + 剩余毫秒。
  4. 同步置 `task.phase = "auth"`（先于 await，双击不能竞态）。
  5. 调 `runWeekCache`；**鉴权由 service 内部先做**。service 抛 auth error → store 清 task、返回 `auth`，**不写 lastStartedAt**。
  6. service 在第一次数据请求前调 `beforeFirstRequest`，store 在这里写 `lastStartedAt = Date.now()` 到 MMKV。
  7. `onProgress` 更新 task；`onDaySaved` 更新 `completedDays`、`revision++`。
  8. 结束：task 清空；成功/取消/失败都 `revision++`；失败写 `error`。
- `cancel`：置模块级取消标记；当前请求返回后停止；task 显示"正在取消"，循环退出后清空。
- 冷却语义：**两次缓存"开始"之间至少 60 秒**（从第一次数据请求算）。抓取本身超过 60 秒时，完成后可立即开始下一周。重启后从 MMKV 恢复；损坏/未来时间夹到 60s 窗口内。
- 同一时刻只允许一个 task；不同周/学期按钮都禁用。
- task 不持久化；杀 App 后以 `emptyClassroomDays` 为续传真相，只持久化冷却时间。重启后不伪造"running"锁。

### 3.4 写入 `src/features/emptyClassroom/repo/EmptyClassroomRepo.ts`

`saveDay(year, term, week, day, payload)` 在一个 `db.transaction` 内：

1. 教室 upsert：每批 100 行 `insert(...).onConflictDoNothing({target:[building,name]})`（7 列 × 100 = 700 参数，留足旧 SQLite 999 上限余量）。
2. `select id, building, name from emptyClassroomRooms` 构建内存 Map（约 1,600 行；不要依赖 lastInsertRowid）。
3. 删除该天旧 slots（`year/term/week/day` 命中 PK 前缀）。
4. 插入 slots：每批 100 行（6 列 × 100 = 600 参数）。
5. upsert `emptyClassroomDays`（`slotCount = sum(freePeriods lengths)`）。
6. 同一事务内重算并 upsert snapshot：
   - `completedDays` = day 表行数
   - `slotCount` = day 表 `slotCount` 之和（不需要 count 扫描）
   - `roomCount` = 仅当 `completedDays === 7` 时用 `countDistinct(roomId)` 扫一次；未完成周保持 0
   - `complete = completedDays === 7`
   - `fetchedAt = now`
   snapshot 在第一天保存时才创建，**没有 `beginWeek`**。

其他方法：

- `getCompletedDays`、`getWeek`、`listWeeks(year, term)`。
- `completeWeek`：幂等对账；重算 counts/roomCount/complete 并 upsert snapshot。处理"7 天都在但 complete=false"的崩溃恢复。
- `deleteWeek`：事务删除 slots + days + snapshot；保留教室维表。
- `listRooms(year, term)`：先 `selectDistinct roomId` from slots（只读整数列，走 PK 前缀），再按 500 个 id 分块查 rooms（避开变量上限），JS 里按 building/name 排序。**只在 room picker 打开时懒加载**，按 `(year, term, revision)` 内存缓存；不要放第一屏关键路径，不要加索引。
- `getRoom(id)`：按 PK 查；用于第一屏已保存 roomId 的元信息。
- `getRoomWeekSlots(year, term, roomId, weeks)`：`inArray(week, weeks)`，空数组直接返回 `[]`。

**写队列**：op-sqlite 单连接，`db.transaction` 是异步的；用模块级 promise 链串行化 `saveDay/completeWeek/deleteWeek`，避免其他写操作插进当天事务。读操作不排队（第一屏在缓存页覆盖时不 focus）。

### 3.5 周数据大小

渲染时用公式：`estimateSizeBytes(slotCount, roomCount) = slotCount * 38 + roomCount * 130`，UI 显示"约 5.5 MB"（147,511×38 + 1,621×130 ≈ 5.55 MiB，与调研实测一致）。不存 `sizeBytes`、不测 `PRAGMA page_count`（全库差值会被其他表/删除/freelist/WAL 污染，且续传无法回溯已完成天）。

---

## 4. 第一屏 UI

文件：`screens/EmptyClassroomScreen.tsx`，路由 `emptyClassroom`。

```
[Stack header: 空闲教室                 缓存管理]
[FilterRow 学期: UnTermSelector]
[FilterRow 教室: 选择按钮（building · name）]
[状态行: 第 3 周 · 9.21–9.27 · 空闲 34 节 / 未缓存]
[未完成 banner / 运行中 banner（可选）]
[TimeScheduleView pager（20 页）]
[图例: 绿色=空闲，空白=有课/占用]
```

### 4.1 选择状态

`stores/selectionStore.ts`：`{year, term:1|2, week, roomId|null}`，持久化到 MMKV `emptyClassroomSelection`。

- 首次初始化：学期优先用 `useStartDay()` 当前/下一学期（逻辑 1/2）；未 ready 时回退到 `useUserConfig().jw.year/term`（3/12 转 1/2）。周次在当前学期已开学时取 `getWeekOfDate(now, startDay)` 夹到 1–20，否则第 1 周。
- `setTerm(year, term)`：值相同直接 no-op；变化时更新，当前学期取当前周，否则第 1 周，并清空 roomId。
- `setWeek` 夹 1–20；`setRoom` 存 id|null。
- 持久化值加载时校验：year 有限整数、term 1/2、week 1–20、roomId 正整数|null；损坏则忽略。
- 第一屏和缓存页共用；`UnTermSelector` 是非受控组件且挂载时会触发 `onChange`，因此：
  - 传给它的 term 用 **字符串** `"3"`/`"12"`（`toLegacyTerm` 返回字符串，匹配 `SchoolTerms` 的字符串比较）；
  - 用 `key={`${year}-${legacyTerm}`}` 强制重挂载，缓存页改学期后第一屏 selector 才会更新；
  - `setTerm` 必须 no-op 防止挂载回调造成循环。

### 4.2 教室选择

- `components/RoomPickerSheet.tsx`：`UnBottomSheet` + 搜索框 + `SectionList`（按楼栋分组）。
- 数据源：`listRooms(year, term)`，**打开 sheet 时才加载**；按 `(year, term, revision)` 缓存；显示 spinner。只包含当前学期有 slot 的教室（约 1,600）。
- 无数据："本学期已缓存的周次中没有教室数据，请先在缓存管理中缓存至少一周" + 入口。
- 选中后关闭 sheet；第一屏用 `getRoom(roomId)` 取元信息。
- 不因为切换学期就静默清空已保存的 roomId：先 `getRoom`，返回 null（DB 重建）才清空；存在但当前学期无 slot 时保留选择并显示"本周无空闲"，让用户自己重选。
- 第一屏显示 `building · name`、`seatCount`、`placeType`。

### 4.3 数据与网格

`hooks/useEmptyClassroomOverview.ts`：

- 依赖 `{year, term, roomId}` + focus + runner `revision`。
- 总是加载 `listWeeks(year, term)`（20 行，便宜）。
- 有 roomId 时 `getRoom(roomId)` 取标签/元信息。
- 每个已缓存（`completedDays > 0`）的周：
  - 默认只加载 active week ±2 的 slots（`TimeScheduleView` 的 `offscreenPageLimit=2`，最多 5 页），按周缓存到内存；`onPageChanged` 后补加载新的 ±2 窗口。调研单周单教室 ~9ms，5 周约 45ms 桌面，真机也在百毫秒内。
  - 不要一次取回全部 20 周（真机可能 0.5–1.5s）。用 `loadedWeeks: Set<number>` 区分"该周数据还在加载"与"已加载但该教室无空闲"；前者显示加载占位，后者显示"本周无空闲"，避免把加载中误判成无空闲。
- `buildFreeRuns(rows)` 合并连续空闲节次（只合并严格相邻 `period === prev + 1`，不跨天、不跨午休做特殊处理）。
- 本地 DB 读失败：hook 返回 `error`，第一屏一行错误 + 重试；不要弹 Toast。

`TimeScheduleView`：

- `startDay` 用 `useStartDay(year, term).startDay`，**同一个值传给 pager 和内层 `TimeSchedule`**；`showDate={ready}`、`showDayHighlight={ready}`、`showTimeSpanHighlight={false}`。
- `scheduleItems=[{data: freeRuns, isItemShow, itemRender:<EmptyRunBlock/>, needShift: EMPTY_CLASSROOM_NEED_SHIFT}]`。
- `isItemShow: item.week === week && item.day === day.isoWeekday()`。
- `EmptyRunBlock` 复制 `NewCourseItem` 的绝对定位数学：
  `top=(begin-1)*timeSpanHeight+margin`，`height=(end-begin+1)*timeSpanHeight-2*margin`。
  **不要加 `weekdayHeight`**：它渲染在 `TimeSchedule.renderItems` 的零高度 wrapper 里，已经位于星期表头下方；加表头高度会整体下移。
  绿色 success 半透明底 + 边框 + "空闲"/"空闲 N 节"；不要用 `useBlocksColor`。
- `needShift`：放进 `const.ts` 作为命名常量 `EMPTY_CLASSROOM_NEED_SHIFT = false`（按教学周原始数据展示，不做补课日重映射）。`TimeSchedule` 仍会显示 `(补)/(休)` 表头；上线前在已知补课/调休周人工核对一次，决定是否改为 `true` 或加 UI 说明。这是一个未验证的产品决策，不要藏在调用处。

### 4.4 pager 同步（避免 activePage=0 竞态）

对 `TimeScheduleView` 做两个向后兼容的可选 prop：

```ts
initialPage?: number;                    // 0-based page index
onPageChanged?: (pageIndex: number) => void;
```

- `initialPage` 只在 pager 首次挂载生效；clamp 到 `[0, pages.length-1]`，缺省仍是 `realCurrentWeek-1`。
- 包装 `rest.onPageSelected`：先调原 handler 保持 `usePagerView.activePage` 更新，再 `props.onPageChanged?.(e.nativeEvent.position)`。
- 现有调用方不传，行为不变；顺手 clamp 长按回本周的 `realCurrentWeek-1`（开学前可能为负）。
- 第一屏：
  - `initialPage={week - 1}`；
  - `onPageChanged={page => setWeek(page + 1)}`；
  - **不要用 effect 读 `pageView.activePage` 写 store**（初始 activePage=0 会把持久化的周覆盖成 1）。只在 `selection.week` 被外部改变（切学期重置、缓存页目标周）时单向 `pageView.setPage(week-1)`；用户滑动由 `onPageChanged` 反向写 store。
- 更新 `TimeSchedule.md` 的 `TimeScheduleView` 段落，注明 `initialPage` 只在首次挂载生效。

### 4.5 覆盖提示与状态

在 `TimeScheduleView` 外包 `position:relative` 容器；完整覆盖层只在特定状态出现：

- 根 `StyleSheet.absoluteFill`：`pointerEvents="box-none"`；暗色背景层 `pointerEvents="none"`；提示卡片 `pointerEvents="auto"`。卡片外的左右滑动仍落到 pager，避免用户被卡在未缓存周。
- 状态优先级：
  1. 当前学期没有任何 `completedDays>0` 的周 → 完整覆盖 "本学期还没有缓存数据" + "去缓存管理"。
  2. 当前周无 snapshot 或 `completedDays===0` → 完整覆盖 "第 X 周数据未缓存" + "去缓存"。
  3. 当前周 `1<=completedDays<=6` → **banner**（不挡网格）"缓存未完成 X/7 天，仅显示已缓存的天" + "去缓存/继续"；网格渲染已缓存天的空闲块。
  4. 已缓存但未选教室 → 完整覆盖 "请选择教室" + 打开 sheet。
  5. 已缓存 + 有教室 + 0 空闲 → banner "本周该教室无空闲"（不遮挡滑动）。
  6. 该周正在 runner 中 → 有数据时 banner 显示进度，0 天时完整覆盖显示进度 + "查看详情"。
- active week 用 `selection.week`（由 `onPageChanged` 同步），不要直接读 `pageView.activePage`。
- 完整覆盖的 "去缓存" 设置 `selection.week` 后 `navigation.navigate("emptyClassroomCache")`。

---

## 5. 缓存管理页 UI

文件：`screens/EmptyClassroomCacheScreen.tsx`，路由 `emptyClassroomCache`。

```
[Stack header: 缓存管理]
[学期: UnTermSelector disableSelectAll]
[汇总: 已缓存 2/20 周 · 约 11.2 MB]
[限流 banner: 每分钟仅可缓存一周，还需 42 秒]
[全局运行 banner（不随学期选择器隐藏）: 2026-2027 第1学期 · 第3周 · 4/7 天 + 进度条 + 取消]
[第1周  9.7–9.13   已缓存 · 约5.5MB · 10-26 14:30   [删除]]
[第2周  9.14–9.20  未缓存 · gzip约1.3MB（未压缩约32MB） [缓存]]
[第3周  9.21–9.27  未完成 3/7 天 · 约1.7MB           [继续] [删除]]
[第4周  ...         [进度条 42% · 第4/7天 第6/13节]   [取消]]
...
```

- 周列表 1–20；周日期用 `useStartDay(year, term).startDay` 计算，未 ready 时只显示"第 X 周"。保持 20 周（pager/后端范围一致），不要按 `weekCount` 动态缩短。
- 行状态优先级：running > complete > partial > none。
  - 已缓存：`约 X MB` + `fetchedAt` + 删除。
  - 未缓存：`缓存` 按钮 + "gzip 约 1.3 MB（未压缩约 32 MB）"。
  - 未完成：`已完成 X/7 天` + 估算大小（`slotCount*38`）+ `继续` + `删除`。
  - 当前运行周：`LinearProgress` + "第 D/7 天 · 第 P/13 节" + `取消`。
  - 失败：一行错误 + `重试`（受冷却限制）。
- 冷却中：所有开始/继续/重试按钮禁用并显示倒计时；运行中：其他周按钮禁用；删除不受冷却限制，但当前 running 周不可删除。
- 删除用 RNEUI `Dialog` 二次确认；`deleteWeek` 调 repo 后刷新，若 task 正好属于该周（done/error/cancelled）同时清掉 task。
- 下载前确认 `Dialog`："约 91 次请求 / gzip 后约 1.3 MB（未压缩约 32 MB）/ 预计 1–2 分钟；若正方仍按 500 分页会自动回退到约 364 次请求。建议 Wi-Fi 并保持应用在前台"。续传提示剩余天数。后端 gzip 未生效时按未压缩量提示。
- 完成/失败/取消用 `ToastAndroid` 或 `UnToast` 提示一次；页面内保留状态。
- 汇总大小 = 完成周 `estimateSizeBytes` + 未完成周 `slotCount*38`，显示"约"。
- 目标周高亮：从第一屏"去缓存"进入时，缓存页滚动/高亮到 `selection.week`（`FlatList` + `scrollToIndex` + `onScrollToIndexFailed` 兜底，或 `ScrollView` + `onLayout` 记录 y）。

### 缓存 hook `hooks/useEmptyClassroomCache.ts`

- `useFocusEffect` + runner `revision` 加载 `listWeeks(year, term)`；不要在本地再存一份会漂移的 snapshot。
- 订阅 runner task；状态 done/error/cancelled 时刷新。
- `startWeek(week)` 调 runner，处理 `busy/cooldown/auth/error` 结果并在 screen 提示。
- `deleteWeek(week)`：running 周拒绝；否则 repo 删除后刷新，并清掉该周旧 task 状态。
- `useCooldown(lastStartedAt)`：剩余 >0 时每秒 tick，夹到 60s 窗口；损坏/未来时间不会锁死。
- 学期切换会重新加载列表并清空目标周高亮。

---

## 6. 路由与入口

- `src/screens/tool/ToolboxIndex.tsx`：信息查询分组，"个人课表"附近新增
  `{label:"空闲教室", icon:<Icon name="calendar-search" .../>, type:"navigation", navigation:"emptyClassroom"}`（`calendar-search` 已在"全校实时课表"用过，glyph 确定存在）。
- `src/route/screens/ToolboxStack.tsx`：
  - `emptyClassroom` lazy screen，`options={({navigation}) => ({title:"空闲教室", headerRight: () => <Button type="clear" onPress={() => navigation.navigate("emptyClassroomCache")}>缓存管理</Button>})}`；覆盖全局"打开教务"，符合"入口放顶部"。
  - `emptyClassroomCache` lazy screen，`options={{title:"缓存管理"}}`。
- 缓存页返回按钮由 native-stack 自动提供。

---

## 7. 文件清单（全部在 `src/features/emptyClassroom/` 下）

```
api/index.ts                 fetchDay、请求、重试/鉴权/取消、pageSize 10000→500 回退
api/pagination.ts            collectSlotPages 纯函数（totalCount 优先）
schema/index.ts              Zod 校验后端信封，输出 EmptyClassroom
repo/EmptyClassroomRepo.ts   四张表读写、事务、批量插入、写队列、统计
services/cacheRunner.ts      runWeekCache 纯编排（可注入 fake）
stores/selectionStore.ts     学期/周/教室选择，MMKV 持久化
stores/cacheRunnerStore.ts   任务/进度/冷却/续传/取消/revision
hooks/useEmptyClassroomOverview.ts  第一屏 snapshots/room/runs
hooks/useRoomList.ts         room picker 懒加载 + revision 缓存
hooks/useEmptyClassroomCache.ts     缓存页列表/操作/冷却
hooks/useCooldown.ts        每秒倒计时
components/EmptyRunBlock.tsx        空闲块绝对定位
components/RoomPickerSheet.tsx      教室搜索/分组选择
components/WeekStatusOverlay.tsx    第一屏覆盖/横幅（box-none）
components/WeekCacheRow.tsx         单周状态/进度/操作
screens/EmptyClassroomScreen.tsx
screens/EmptyClassroomCacheScreen.tsx
type/index.ts                EmptyClassroom 派生类型 + 本地 DB/UI 类型
utils/constants.ts           PAGE_SIZE=10000/PAGE_SIZE_FALLBACK=500/MAX_PAGES/DAYS/PERIODS/COOLDOWN/batch/MMKV keys/needShift
utils/terms.ts               toLogicalTerm/toLegacyTerm("3"|"12")/clampWeek
utils/roomKey.ts             building+"\0"+name
utils/freeRuns.ts            buildFreeRuns 连续空闲段合并
utils/format.ts              formatBytes/estimateSizeBytes/formatCacheTime
utils/__tests__/freeRuns.test.ts
utils/__tests__/terms.test.ts
utils/__tests__/format.test.ts
schema/__tests__/apiSchema.test.ts
api/__tests__/pagination.test.ts
services/__tests__/cacheRunner.test.ts
```

修改（仅这些既有文件）：

- `src/core/schema.ts`：四张表 + 唯一索引（无 `sizeBytes`）。
- `drizzle/migrations/0003_*.sql`、`meta/0003_snapshot.json`、`meta/_journal.json`、`migrations.ts`：生成并注册。
- `src/components/tool/infoQuery/courseSchedule/TimeScheduleView.tsx`：`initialPage`/`onPageChanged` + 长按 clamp。
- `src/components/tool/infoQuery/courseSchedule/TimeSchedule.md`：补新 prop 说明。
- `src/route/screens/ToolboxStack.tsx`、`src/screens/tool/ToolboxIndex.tsx`。
- `package.json`/`pnpm-lock.yaml`：adapter 依赖更新（前置步骤）。
- `test.ts`：Node 原生请求加 `Accept-Encoding: identity`，避免后端 gzip 后脚本解析失败。
- `docs/empty-classroom-research.md`：末尾补一节"2026-10-26 后端调整"——pageSize 上限 10000、gzip、预期 91 请求/1.3MB、正方强制 500 时回退 364、后端分支名。
- `plan/empty-classroom-plan.md`：本计划的导出副本（已存在，随计划更新重新导出）。

约定：新增的有意义函数（repo/api/runner）按 `AGENTS.md` 补中文契约注释；组件沿用现有风格；底层不弹 Toast，hook 返回 loading/error/data，screen 提示一次。

---

## 8. 实施顺序与本地提交

### 8.1 后端（先做，独立分支）

1. `cd D:/Programs/tool-mono-repo && git switch -c feat/empty-classroom-page-size-gzip`；确认工作区干净。
2. 改 DTO `@Max(10000)`、DTO spec、`main.ts` gzip、`package.json` 依赖、删除 `console.log(res)`、README。
3. `pnpm --filter tool-app-be test` / `build`；本地起服务验证 gzip 与 pageSize=10000。
4. 本地提交（不 push）：`git add` 上述文件 + `pnpm-lock.yaml`；`git commit -m "feat(empty-classroom): raise page size cap to 10000 and enable gzip"`。

### 8.2 app（`v2.2` 拉 feature 分支）

1. `cd D:/Programs/gxu_tool_app && git switch -c feat/empty-classroom`；先 `git status`，**只 stage 空闲教室相关文件**（不要混入 `.npmrc`、`ScheduleCard.tsx`、`docs/superpowers/`、`scratch.md` 等无关改动）。
2. 先把已有调研产物和本计划本地提交：`docs/empty-classroom-research.md`、`test.ts`（含 `Accept-Encoding: identity` 更新）、`.gitignore` 相关条目、`plan/empty-classroom-plan.md`；提交信息如 `docs: add empty classroom research, plan, and smoke test`。
3. 更新 `gxu-tool-adapters` 依赖并验证 `EmptyClassroom` 导出；提交 `chore(deps): update gxu-tool-adapters for empty classroom types`。
4. `src/core/schema.ts` 加四张表；`npx drizzle-kit generate`；检查 `0003` SQL；在 `drizzle/migrations/migrations.ts` 注册；提交 `feat(empty-classroom): add schema and migration`。
5. `type/index.ts`、`utils/*`、`schema/index.ts`、`api/pagination.ts`，先写纯函数与测试；提交 `feat(empty-classroom): add api schema and pure utils`。
6. `api/index.ts`（fetchDay/重试/鉴权/取消/pageSize 回退）；`repo/EmptyClassroomRepo.ts`（saveDay/getCompletedDays/completeWeek/deleteWeek/listWeeks/listRooms/getRoom/getRoomWeekSlots + 写队列）；提交 `feat(empty-classroom): add api, repo, and cache runner`（runner 与 store 同批或下一批）。
7. `services/cacheRunner.ts` + `stores/cacheRunnerStore.ts`（任务/冷却/进度/续传/取消）；提交。
8. `TimeScheduleView` 的 `initialPage/onPageChanged` 扩展 + 文档；提交 `feat(empty-classroom): extend TimeScheduleView pager props`。
9. `stores/selectionStore.ts`、第一屏 hooks/components/screen；提交 `feat(empty-classroom): add empty classroom overview screen`。
10. 缓存页 components/screen；提交 `feat(empty-classroom): add cache management screen`。
11. `ToolboxStack.tsx` 注册两条路由；`ToolboxIndex.tsx` 加入口；提交 `feat(empty-classroom): register routes and toolbox entry`。
12. 纯函数测试 + `npx eslint` + `npx tsc --noEmit` + 真机手工流程；提交 `test(empty-classroom): add unit tests`。

所有提交只在本机，**不 push**。后端先于 app 部署；app 的 10000→500 回退用于灰度期旧后端。

先做后端 8.1 与 app 4–7：纯函数（Zod/连续空闲段/大小估算/分页/runner）用 Jest 验证；repo/API 在真机联调；UI 最后接上。

---

## 9. 验证计划

1. **后端**：`feat/empty-classroom-page-size-gzip` 分支上 `pnpm --filter tool-app-be test`（DTO spec 含 10000 上限）和 `build`；本地起服务：
   - `curl -H "Accept-Encoding: gzip" -D -` 确认 `Content-Encoding: gzip`；
   - `pageSize=10000` 请求成功，记录 `items.length/totalCount/totalPage`；若正方仍按 500 返回，确认 app pagination 会按 `totalCount` 继续；
   - 确认 `console.log(res)` 已删除，日志不再出现整页响应。
2. **adapter**：`node_modules/gxu-tool-adapters/dist/jw/index.d.ts` 含 `EmptyClassroom`；`npx tsc --noEmit` 不因 adapter 升级新增错误。
3. **迁移**：`npx drizzle-kit generate` 后检查 `0003` SQL 含四张表 + 唯一索引；`meta/_journal.json` 有 idx 3；`migrations.ts` 注册 `m0003`；从旧版本升级后既有数据不丢、无 "no such table"。
4. **纯函数测试**：`npm test -- emptyClassroom`，覆盖：
   - `buildFreeRuns`：连续合并、断点拆分、单节、多周/多天、输入顺序无关。
   - `terms`：`"3"`/`3` → 1、`"12"`/`12` → 2、`1`/`2` 幂等、`"16"` 拒绝、clampWeek。
   - `estimateSizeBytes(147511,1621)` 接近 5.55 MB；`formatBytes`。
   - API schema：合法页、`data:null`、缺省字段、数字字符串、未知字段忽略。
   - pagination：pageSize=10000 时一页 1690 条即停；正方强制 500 时 `totalCount=1690` 续到 500/500/500/190 四页；`totalCount` 缺省时用 `totalPage`/短页；`totalCount` 不足抛错；重复 key 去重不影响完整性；超上限抛错。
   - runner：续传跳过已完成天、7 天齐本地 finalize 不鉴权/不冷却、取消保留已完成天、失败保留 partial、`beforeFirstRequest` 只调一次。
   - API 回退：旧后端对 10000 返回 400 时，用 500 重试成功且只回退一次。
5. **静态检查**：`npx eslint` 新文件；`npx tsc --noEmit` 与既有 ~150 条基线比较，不新增错误（重点看新文件与 adapter 升级影响）。
6. **手工流程（真机）**：
   - 工具箱出现"空闲教室"；首次进入无缓存，提示去缓存管理。
   - 缓存管理列出 20 周；开始缓存第 1 周，确认下载提示、7 天 × 13 节推进；后端新版时每节 1 页，旧版/正方强制 500 时自动 4 页；完成后显示"约 5.5 MB"和时间。
   - 真机确认 gzip：`res.data` 是 JSON、缓存任务正常；不手动设置 `Accept-Encoding`。
   - 旧后端灰度：把 app 指向未升级后端，缓存仍能通过 500 回退完成（364 请求），不报 400。
   - 立即点第 2 周 → 冷却拦截并显示剩余秒数；60 秒后可开始。
   - 返回第一屏 → 第 1 周不再提示；选择教室，绿色空闲块与缓存数据一致；左右滑动到未缓存周，出现提示且卡片外仍可滑动。
   - 未完成周：取消/杀 App 后显示 `X/7`，继续时已完成天不再发请求（网络 profiler 验证）；未完成周仍可看到已缓存天的空闲块。
   - 冷却跨重启：开始后 60s 内杀 App 重开，按钮仍禁用直到倒计时结束。
   - 删除第 1 周 → 二次确认 → 行变未缓存；第一屏重新出现提示；slots/days/snapshot 均删除。
   - 未登录教务点缓存 → 提示登录，且不消耗 60 秒冷却。
   - 弱网/飞行模式中断 → 显示错误，已完成天保留；恢复后续传。
   - 切换学期：第一屏/缓存页 selector 显示同步；已选教室在当前学期无数据时显示"本周无空闲"，不静默给错误结果。
   - pager 持久化：停在第 12 周杀 App 重开仍停在第 12 周；滑到 13 周再重开仍在 13 周。
   - 补课/调休周：人工核对 `needShift` 选择后的展示，确认是否有误导。
7. **数据核对**：缓存一周后，用 SQLite 查看行数约 14.7 万、snapshot `complete=1`、`completedDays=7`；抽查某教室某天的空闲节次与接口单点查询一致（可复用 `test.ts --relations` 的查询方式）。
8. **回归**：主课表、班级课表、日程编辑仍正常（`TimeScheduleView` 的可选 prop 不传时行为不变）。
9. **本地提交检查**：两个仓库 `git log --oneline` 有对应提交、`git status` 只剩无关的既有改动；未 push。

---

## 10. 风险与已知限制

- **adapter 依赖**：当前安装版本没有 `EmptyClassroom` 导出；必须先更新依赖，否则 API 类型无法按用户要求来自 adapter。若 adapter 升级有 breaking change，先只取包含 `emptyClassroom` 的最小 commit/tag。
- **体量与耗时**：后端升级后预期 91 请求/周、gzip 约 1.3 MB/周（未压缩约 32 MB）、约 1–2 分钟/周；若正方仍按 500 分页则回退 364 请求/周。后端 `EmptyClassroomService` 的 `console.log(res)` 必须删除，否则新版每次约 350KB、一周约 32MB 日志。UI 下载前提示 Wi-Fi/时长。
- **正方可能忽略 10000**：`queryModel.showCount=10000` 是否被正方接受未验证；若被强制按 500 返回，app 的 pagination 按 `totalCount` 继续，功能正确但请求数回到 364/周、gzip 后流量仍在 MB 级。后端验证时必须记录 `items.length/totalCount/totalPage`。
- **旧后端灰度**：app 的 `pageSize=10000` 在未升级后端上会 400；API 必须做一次 500 回退。建议先部署后端再发 app；回退路径用于灰度/回滚。
- **gzip 透明解压**：真机依赖 OkHttp 自动加 `Accept-Encoding` 并解压；不要手动设置该头。`test.ts` 是 Node 原生请求，需 `Accept-Encoding: identity`，否则后端 gzip 后脚本解析失败。
- **正方夜间限制**：调研时直接访问正方在 23:30 被 483 拦截，校外访问开放时间 7:30–23:00。夜间缓存可能失败；错误提示要能区分"登录失效/教务系统不可用/网络错误"，不要把 HTML 原文弹给用户。
- **每分钟一周是"开始速率"限制**：一次抓取本身超过 60 秒时，完成后可立即开始下一周；不是"完成后必须等 60 秒"。清数据/改时钟可绕过，属于 UX 限流不是安全控制。
- **教室全集只来自空闲记录**：整周从不空闲的教室不会出现在选择器；这是接口 + 只存空闲方案的固有限制。
- **教室没有稳定编号**：业务键 `(building, name)`；若正方改名会产生新教室行，旧缓存不迁移。
- **调课/调休**：`needShift` 是未验证的产品决策，默认 false（按教学周原始数据）；补课日/调休日的空闲数据对齐未验证，上线前人工核对。
- **大小是估算**：`slotCount*38 + roomCount*130`，UI 写"约"；不存 `sizeBytes`。
- **续传粒度是一天**：取消/崩溃会丢当天抓了一半的 13 节（抓完整天即使取消也保存），最多重抓一天。
- **单主机**：缓存任务在 JS 内存中，杀 App 后任务消失；已完成天在 SQLite，可续传；冷却时间在 MMKV。
- **第一屏查询**：单教室跨已缓存周只靠 PK；默认按 active ±2 窗口加载（5 周），避免 20 周全量扫描在真机 0.5–1.5s。窗口外页面显示加载占位。
- **room picker 查询**：`SELECT DISTINCT roomId` 随已缓存周线性增长，20 周可能 1–2s；已设计为打开 sheet 才懒加载 + 内存缓存 + spinner，不加索引。
- **backend 仍无按天聚合接口**：放页大小只减少每节页数（91 请求/周），一天仍需 13 次请求；若后续后端增加按天接口，只需把 `api.fetchDay` 内部从 13 个节次循环换成一次后端请求，存储/UI 不变。
