# 空闲教室接口调研与本地缓存方案

> 记录一次从接口分析、参数语义实测，到 SQLite 存储方案选型的完整过程。
> 结论先行：**多值参数是「与」；要拿到全部教室 × 全部时间，一周需要 91 次查询；本地缓存用「教室维表 + 教室-时间事实表」，不建额外索引、只保留当前周，约 5.5 MB/周。**

---

## 1. 接口现状

代码位置（mono 仓库 `tool-mono-repo`）：

| 层 | 文件 |
|---|---|
| Controller | `apps/backend/src/jw-system/emptyClassroom/emptyClassroom.controller.ts` |
| Service | `apps/backend/src/jw-system/emptyClassroom/emptyClassroom.service.ts` |
| DTO / 校验 | `apps/backend/src/jw-system/emptyClassroom/dto/emptyRoom.dto.ts` |
| 适配器清洗 | `packages/adapters/jw/src/emptyClassroom/schema.ts` |
| 文档 | `apps/backend/README.md`（第 244–375 行） |

### 1.1 三个接口

| 方法 / 路径 | 说明 | 需登录 |
|---|---|---|
| `GET /jw/emptyClassroom/building` | 楼号选项（后端硬编码，首项是「全部」） | 否 |
| `GET /jw/emptyClassroom/place` | 场地类别选项（后端硬编码，无「全部」项） | 否 |
| `GET /jw/emptyClassroom` | 空闲教室查询，转发正方 | 是，需教务 Cookie |

统一返回信封：

```json
{ "code": 200, "message": "success", "data": ... }
```

### 1.2 查询参数

| 参数 | 必填 | 说明 |
|---|---|---|
| `weekDay` | 是 | 星期 1–7，重复键数组 |
| `weekList` | 是 | 周次 1–20，重复键数组 |
| `timeList` | 是 | 节次 1–13，重复键数组 |
| `building` / `place` / `roomName` | 否 | 楼号 / 场地类别 / 教室名（**包含匹配**） |
| `year` / `term` | 否 | 学年 + 学期（1=上、2=下），**必须成对** |
| `pageNum` / `pageSize` | 否 | 默认 1 / 20，`pageSize` 上限 500 |

约束：

- 三个数组必须用**重复键**：`weekDay=1&weekDay=2`；
- 逗号分隔、`weekDay[]=`、未知参数都会 400（后端 `ValidationPipe`）；
- `data` 是一页记录，字段为 `classroomName / placeType / seatCount / seatCountForExam / building / owner / user / allowToUse`。

---

## 2. 实测过程与关键结论

### 2.1 登录

`POST /jw/login` 返回 **201**（NestJS POST 默认），不是 200。脚本已按 2xx 判断。

### 2.2 分页

- 第 2、3 页内容与上一页零重叠，`totalCount` 稳定，**分页本身正常**；
- 但上游回显的 `data.currentPage` / 每条记录的 `currentPage` **恒为 1**，不可信；
- 判断翻页是否生效要看内容与 `totalCount`，不要看 `currentPage`。

### 2.3 `year` / `term`

- 成对提交 `year=2026&term=1`：`totalCount=1622`；
- 只传 `term=1`：`totalCount=0`，已知陷阱复现；
- 结论：**要么都传，要么都不传**。

### 2.4 多值参数是「与」

实验方法：固定楼号（东九教）、学年学期，比较「多值组合查询」与「各单值查询的交集 / 并集」。

| 维度 | 单选 A | 单选 B | 多值组合 | 交集 | 并集 | 结论 |
|---|---|---|---|---|---|---|
| `weekDay` | 周一 52 | 周二 50 | **49** | 49 | 53 | 与 |
| `weekList` | 第1周 52 | 第2周 53 | **52** | 52 | 53 | 与 |
| `timeList` | 第1节 52 | 第2节 51 | **51** | 51 | 52 | 与 |

三个维度同时多值（2 天 × 2 周 × 2 节）：

- 8 个单点组合的交集 = 45，并集 = 54；
- 组合查询实际返回 **45**。

结论：**完整笛卡尔积上的「与」**——选 2 天、2 周、2 节，要求教室在全部 8 个组合里都空闲，不是「任意一个」。

过滤器也是「与」：

| 条件 | `totalCount` |
|---|---|
| 无过滤 | 1622 |
| `building=9`（东九教） | 52 |
| `place=007`（普通） | 41 |
| `building=9 + place=007` | 1 |
| `building=9 + place=011`（多媒体） | 10 |
| `roomName=西1-101` | 1 |

`roomName` 是**包含匹配**：`101` 能匹配 32 间，`西1-10` 匹配 7 间。要精确查一间教室，传完整名称，并在客户端用 `classroomName ===` 再过滤一次。

### 2.5 谁的限制

| 限制 | 来源 |
|---|---|
| 三个数组必填、范围 1–7 / 1–20 / 1–13 | **我们后端的 DTO** |
| 未知参数 / 逗号 / `[]` 写法 400 | **我们的 ValidationPipe** |
| `pageSize ≤ 500` | **我们的 DTO** |
| 多值「与」 | **正方**（我们只是把数组编码成 `xqj` / `zcd` / `jcd`） |
| `year` + `term` 成对 | **正方**行为 |
| `roomName` 包含匹配 | **正方**行为 |

未验证：只传 `roomName + week`、不传 `weekDay/timeList` 时正方会怎样。我们的 DTO 会先 400，请求到不了正方。直接打正方时被 483 挡住——正方对校外网络的开放时间是 **7:30–23:00**，测试时是 23:30。

### 2.6 对「按教室查」的影响

接口返回的是「满足全部时间条件的教室」，没有时间维度。因此：

- 查某教室某时段：`roomName=完整名称` + 单个 `weekDay/timeList`，`totalCount>0` 即空闲；
- 查某教室整周：**91 次查询/周**（逐格），或先做全周快照再本地查；
- 正方如果有「教室课表」接口，一次请求就能拿到占用时段，但当前后端没有封装，尚未探查。

---

## 3. 全量数据采集

### 3.1 规模

| 项目 | 数值 |
|---|---|
| 时间格 | 7 天 × 13 节 = **91 格/周** |
| 单格空闲教室 | 抽样 1582–1747，均值约 **1690** |
| 教室全集 | 至少 1747 间（单格最大空闲数） |
| 一周记录 | 约 **15.4 万条**（1690 × 91） |
| 请求数（`pageSize=500`） | 364 次/周（每格 4 页） |
| 请求数（放开到 2000） | 91 次/周，流量基本不变 |

### 3.2 网络流量

实测单页 500 条 = 103,334 B，约 **206.7 B/条**（清洗后的 JSON）：

| 范围 | 未压缩 | gzip |
|---|---|---|
| 1 周 | 约 **31.8 MB** | 约 **1.3 MB**（实测压缩比 24.6×） |
| 1 学期（20 周） | 约 620 MB | 约 26 MB |

注意：

- 当前后端响应**没有 `Content-Encoding`**，不压缩就是 31.8 MB/周；
- 上游原始报文大小未能实测（直接打正方被 483 挡住），估计与清洗后同量级；
- `EmptyClassroomService` 里残留 `console.log(res)`，每次查询打印上游完整响应，跑 91 格快照会产生 **27 MB+ 日志/次**，应先删掉。

### 3.3 放开 `pageSize` 的真实收益

- **不减少流量，也不减少数据库量**；
- 只是把每格 4 次请求变成 1 次，请求头开销从约 180 KB/周降到约 45 KB/周；
- 单次响应约 335 KB，后端内存/超时要跟上；
- 正方自身可能还有 `showCount` 上限，需要先验证（直接测被 483 挡了）。

---

## 4. 表结构设计

### 4.1 推荐：三张表

```ts
import {
    index,
    integer,
    primaryKey,
    sqliteTable,
    text,
    uniqueIndex,
} from "drizzle-orm/sqlite-core";

// 教室维度
export const emptyClassroom = sqliteTable(
    "emptyClassroom",
    {
        id: integer("id").primaryKey({autoIncrement: true}),
        name: text("name").notNull(),
        building: text("building").notNull(),
        placeType: text("placeType").notNull(),
        seatCount: integer("seatCount"),
        seatCountForExam: integer("seatCountForExam"),
        owner: text("owner").notNull().default(""),
        allowToUse: text("allowToUse").notNull().default(""),
        updatedAt: integer("updatedAt", {mode: "timestamp"}).notNull(),
    },
    table => ({
        uniqueRoom: uniqueIndex("emptyClassroom_room_unique").on(table.building, table.name),
        buildingIdx: index("emptyClassroom_building_idx").on(table.building, table.placeType),
    }),
);

// 教室-时间事实表（只存空闲记录）
export const emptyClassroomSlot = sqliteTable(
    "emptyClassroomSlot",
    {
        year: integer("year").notNull(),
        term: integer("term").notNull(),
        week: integer("week").notNull(),
        day: integer("day").notNull(),
        period: integer("period").notNull(),
        roomId: integer("roomId").notNull(),
    },
    table => ({
        pk: primaryKey({
            columns: [table.year, table.term, table.week, table.day, table.period, table.roomId],
        }),
    }),
);

// 快照元数据
export const emptyClassroomSnapshot = sqliteTable(
    "emptyClassroomSnapshot",
    {
        year: integer("year").notNull(),
        term: integer("term").notNull(),
        week: integer("week").notNull(),
        fetchedAt: integer("fetchedAt", {mode: "timestamp"}).notNull(),
        slotCount: integer("slotCount").notNull(),
        roomCount: integer("roomCount").notNull(),
        complete: integer("complete", {mode: "boolean"}).notNull(),
    },
    table => ({pk: primaryKey({columns: [table.year, table.term, table.week]})}),
);
```

### 4.2 关键点

- **教室唯一键用 `(building, name)`**：当前接口没有暴露正方的 `cdbh`（教室编号）。建议后端在适配器里把 `cdbh` 作为 `classroomId` 返回，之后改用稳定编号。
- **只存空闲记录**：占用 = 全集 − 空闲；全集取所有时间格空闲集合的并集（整周排满的教室不会出现，实际几乎不会）。
- **快照元数据**区分「没抓过」和「抓过但 0 条」；需要断点续抓时再加一张 91 行/周的 `emptyClassroomSlotFetch`。
- **写入**：按 `(building, name)` upsert 教室 → 同一个事务里删除旧周 + 批量插入；每批 100–150 行（6 列 × 150 = 900 个参数，避开旧 SQLite 的 999 变量上限）。
- **保留策略**：只留当前周（约 5.5 MB），或按学期保留、删旧学期。

---

## 5. 单表 vs 教室抽离（实测）

测试数据：真实「周一第 1 节」1622 条，按 `(building, name)` 去重后 **1621 间**；整周 91 格 = **147,511 行**。

### 5.1 单格（1621 行）

| 结构 | 文件 | 插入 | 单格全量 | 单教室 | 楼栋 |
|---|---|---|---|---|---|
| 单表 | **0.13 MB** | **16 ms** | **2.17 ms** | **0.252 ms** | 0.52 ms |
| 抽离 | 0.22 MB | 24 ms | 3.33 ms | 0.367 ms | 0.38 ms |

**单格场景抽离没有优势**：多一张教室表/索引，join 还多约 1 ms。

### 5.2 整周（147,511 行）

| 结构 | 文件 | 插入 | 整周全量 | 单教室 | 单格 | 楼栋 |
|---|---|---|---|---|---|---|
| 单表（只 slot 索引） | 10.96 MB | 670 ms | 187.5 ms | 23.6 ms | 1.34 ms | 25.5 ms |
| 单表 + 教室索引 | 16.99 MB | 1636 ms | 249.1 ms | 0.125 ms | 1.97 ms | 32.2 ms |
| 单表 + 教室 + 楼栋索引 | 21.18 MB | 2643 ms | 229.2 ms | 0.060 ms | 1.23 ms | 2.19 ms |
| **抽离（基础）** | **5.55 MB** | **456 ms** | **149.4 ms** | 9.2 ms | 1.27 ms | 16.4 ms |
| 抽离 + 教室索引 | 8.32 MB | 805 ms | 150.8 ms | **0.049 ms** | 1.31 ms | 16.4 ms |
| 抽离 + 教室 + 楼栋索引 | 8.36 MB | 864 ms | 147.4 ms | 0.050 ms | 1.33 ms | **1.67 ms** |

结论：

- 整周场景抽离明显更好：文件约 **省 49%**，全索引时省 **60%**；插入快 1.5–3 倍；整周扫描快约 20%。
- 单表上的教室索引要复制文本，约 +6 MB；抽离表的索引只有整数，约 +2.8 MB。
- 抽离表的楼栋查询要写成「从 `room` 驱动 + `INDEXED BY idx_norm_room`」，否则会走普通 join，16 ms；改好后 1.67 ms。

---

## 6. 索引实测

基准：`N91_base`，147,511 行，5.55 MB。

### 6.1 教室相关索引

查询：`WHERE roomId=? AND year=? AND term=? AND week=?`

| 索引 | 增量空间 | 查询耗时 | 说明 |
|---|---|---|---|
| 不加（走 PK） | 0 | ~10 ms | 扫一周 147k 条 |
| `(roomId)` | **+1.52 MB** | **0.098 ms** | 需要 `ANALYZE` 后才会用 |
| `(roomId, year, term, week)` | +2.23 MB | 0.095 ms | 需要 `ANALYZE` |
| `(roomId, year, term, week, period)` | +2.50 MB | 0.099 ms | 需要 `ANALYZE` |
| `(roomId, year, term, week, day, period)` 覆盖 | +2.77 MB | **0.061 ms** | 不需要 `ANALYZE`，计划稳定 |

关键：**不执行 `ANALYZE` 时，非覆盖索引可能完全不被使用**，10 ms 一点没降，空间白花；覆盖索引 `(roomId, ...)` 会被稳定使用。

### 6.2 时间相关索引

查询：`WHERE year=? AND term=? AND week=? AND period=?`（某周某节次所有教室，跨天）

| 索引 | 增量空间 | 查询耗时 |
|---|---|---|
| 不加（走 PK） | 0 | ~13–16 ms |
| `(year, term, week, period)` 非覆盖 | +2.09 MB | 没被使用，仍 ~16 ms |
| `(year, term, week, period, day, roomId)` 覆盖 | +2.76 MB | **5.29 ms** |

主键 `(year, term, week, day, period, roomId)` 已经覆盖「某天某节次」场景（~1.3 ms）；只有跳过 `day` 的「某节次跨天」才受益。

### 6.3 索引的本质

- 索引不是「把重复值合并」：147,511 行、1,621 个不同 `roomId`，`(roomId)` 索引里仍是 **147,511 条**记录，只是按 roomId 排好序。
- 真正去重的是**维表**：`room` 表存 1,621 行，`building/name` 只出现一次。
- 索引的成本 = 空间 + 每次写入的维护成本；收益只在查询真正用上它时才存在。

---

## 7. 三维模型与替代方案

### 7.1 「教室-楼栋-空闲」不是三个并列维度

每间教室只属于一栋楼，楼栋是教室的上级维度。真正的三维是：

> 楼栋 → 教室 → 时间，度量为「空闲 / 占用」

| 部分 | 行数 | 空间 |
|---|---|---|
| 楼栋维表 | ≤61 | 约 5 KB |
| 教室维表 | 1,621 | 约 0.2 MB |
| 教室-时间事实表 | 147,511 | 5.55 MB（基础）/ 8.36 MB（含索引） |

把 `buildingId` 冗余塞进事实表：每行多 2 字节，约 **+0.3 MB/周**；放进主键索引再 +0.3 MB/周；查询收益为 0（楼栋已经在教室维表）。

### 7.2 不带时间

`(教室, 楼栋, 空闲)` 只是当前快照：1,621 行，约 30–100 KB，只能表达一个时段。要表达一周，必须把时间放回维度，规模回到 147k 行。

### 7.3 稠密三维立方体

61 楼栋 × 1,621 教室 × 91 时间格 ≈ **900 万格**，有效格只有 147,511 个（每间教室只属于一栋楼），**密度 1.64%**。即使 1 字节/格也要 9 MB/周，98% 是空。不要存稠密立方体。

### 7.4 每教室 91 位掩码

1,621 行/周，约 **50–60 KB/周**；查询用位运算。属于「合并」，如果坚持一行一个教室-时间就不选。

---

## 8. 最终建议

### 8.1 存储优先

以用户体验看，**查询时间不是瓶颈，空间才是**：

- 单格 1.3 ms、单教室 10 ms、楼栋 16–25 ms，全部低于人的感知阈值；
- 整周 150–187 ms 是一次性加载，配骨架屏即可；
- 为 0.1 ms vs 10 ms 多花 2.8 MB/周不值得。

| 方案 | 每周 | 一学期（20 周） |
|---|---|---|
| **只建主键（推荐）** | **5.55 MB** | **111 MB** |
| + `(roomId)` 索引 | 7.07 MB | 141 MB |
| + 覆盖教室索引 | 8.32 MB | 166 MB |
| `WITHOUT ROWID` | 约 2.6 MB | 约 53 MB |
| 只存占用记录 | 约 0.3 MB | 约 6 MB |
| 每教室 91 位掩码 | 约 0.05 MB | 约 1 MB |

### 8.2 落地顺序

1. **不建额外索引**，只保留主键；
2. **只保留当前周**（或当前 + 下一周），旧周删除，磁盘稳定在 5.5 MB 左右；
3. 如果必须保留整学期：111 MB 是「不合并」的底价；能接受反转就只存占用（约 6 MB/学期），能接受合并就存掩码（约 1 MB/学期）；
4. 真要为按教室查询加索引，先加 `(roomId)` 并执行 `ANALYZE`；再加覆盖索引前先确认确实需要；
5. **真正的 UX 瓶颈是把 15 万行渲染到 RN 列表**，应在 SQL 里按楼栋/天聚合，或只加载当前可见范围。

### 8.3 后端可改进项

- 删除 `EmptyClassroomService` 里的 `console.log(res)`；
- 开启 gzip/Brotli：31.8 MB/周 → 1.3 MB/周；
- 在适配器中暴露正方的 `cdbh` 作为 `classroomId`，让缓存有稳定主键；
- 如需支持「一周一次取回」，可加后端聚合接口（按天并发查 7 次 + 按周缓存）。

---

## 9. 测试脚本与产物

脚本：根目录 `test.ts`（凭据在 `test-credentials.local.ts`，已 gitignore）。

```bash
npx tsx test.ts                 # 冒烟测试（选项、查询、分页、参数校验）
npx tsx test.ts --relations     # 参数与结果的与/或关系实验
npx tsx test.ts --bench-sqlite  # SQLite 单表 vs 抽离基准
npx tsx test.ts --check-unauth  # 未登录是否返回 401
```

产物：

- `.bench-cache/latest.txt`：最近一次基准结果；
- `.bench-cache/sqlite/*.db`：可直接用 SQLite 工具打开的对比库；
- `docs/empty-classroom-research.md`：本文档。

> 基准脚本使用 Node 内置 `node:sqlite`（SQLite 3.50，需 Node ≥ 22.5）；文件格式与 App 的 op-sqlite 一致，因此相对大小和查询耗时的对比是有效的。op-sqlite 的实际 SQLite 版本可能略有差异，绝对数值以真机为准。

---

## 10. 过程时间线

| 时间 | 内容 |
|---|---|
| 2026-10-25 | 阅读 mono 仓库接口代码，整理接口文档、内部处理与优化点 |
| 2026-10-25 | 编写 `test.ts` 冒烟测试，覆盖选项、查询、分页、参数校验 |
| 2026-10-25 | 用真实账号实测：登录 201、分页正常但 `currentPage` 恒为 1、`year/term` 必须成对 |
| 2026-10-25 | 参数关系实验：确认 `weekDay` / `weekList` / `timeList` 及过滤器全部为「与」 |
| 2026-10-25 | 讨论全量采集：91 次/周、31.8 MB/周、gzip 24.6×、SQLite 体积 |
| 2026-10-26 | SQLite 实测：单格、整周、单表 vs 抽离；索引空间/时间对比与 `ANALYZE` 影响 |
| 2026-10-26 | 三维模型分析；确定「空间优先、索引省掉、只留当前周」的最终方案 |
