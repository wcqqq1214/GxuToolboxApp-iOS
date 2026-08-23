# AGENTS.md

> 本文件是项目的**现状地图**：如实描述代码当前的结构、新旧边界和硬性约定。
> 它是给人看的速览，也是给 AI 编码助手的上下文。
> 工程规范与目标见 [`best_practice.md`](./best_practice.md)；当两者冲突时，**以本文件的现状描述为准判断"代码现在是什么样"，以 best_practice 判断"应该变成什么样"**。

## 项目是什么

**西大工具箱**——广西大学的 React Native（仅 Android）校园工具 App。
把教务、统一认证、考勤、文件等分散的外部系统整合到一个 App，转成稳定的本地模型供页面与桌面小组件展示。
本质：从不可信的外部系统取数据 → 落地为稳定模型 → 喂给 UI 和 widget。

## 技术栈

- **框架**：React Native 0.84 + React 19 + TypeScript 5.9
- **状态**：Zustand（内存态）/ MMKV（`src/store`）/ react-native-storage + AsyncStorage（旧 key-value）
- **数据库**：op-sqlite + drizzle-orm（schema 集中在 `src/core/schema.ts`）
- **UI**：@rneui/themed + 自研 `src/components/un-ui`
- **导航**：@react-navigation v7（native-stack + bottom-tabs）
- **校验**：Zod（接住外部响应）
- **HTTP**：axios（`src/core/http.ts`）
- **小组件**：react-native-android-widget（`src/widget`）
- **包管理**：pnpm（lockfile 已提交）；`@/` 路径别名指向 `./src`（tsconfig + babel 双配置）

## 入口与启动链路

```
index.js                      注册 App + widget task handler
└─ App.tsx                    ThemeProvider + SafeAreaProvider
   └─ useEffect: initDB → 并行(getCurrentStartDay / migrateTemplates / JwMachine.loadAccount → syncInfo) + OTA 检查
      └─ src/screens/Root.tsx   用户配置/课表配置/冲突 store + 导航容器
         └─ src/route/RootStack.tsx → screens/{HomeStack, ToolboxStack, SettingStack}
```

启动逻辑必须轻量，启动阶段不要发会改认证态/Cookie 的业务请求。所有初始化任务用 `safe()` 包裹做错误隔离。

## 目录地图（含迁移状态）

> 图例：✅ 新架构主路径 | 🔄 迁移中（新旧并存，改动需谨慎） | 📦 遗留（不要新增代码，维护时再迁）

```
src/
├── core/                 ✅ 跨 feature 基础设施（新代码必须走这里）
│   ├── http.ts              全局 axios + 拦截器
│   ├── db.ts                op-sqlite + drizzle 初始化，导出 initDB()
│   ├── schema.ts            ★ drizzle 表定义集中地（6 张表，见下文「数据库现状」）
│   ├── store.ts             react-native-storage 封装（旧 key-value）
│   ├── ota.ts               OTA 热更新（版本/下载/清理）
│   ├── auth/                认证状态机层（见下文「认证现状」）
│   │   ├── createAuthCore.ts   通用认证状态机工厂
│   │   ├── Jw/                 教务：JwMachine + JwAuthClient + hooks
│   │   ├── attendance/         考勤
│   │   └── unified/            统一认证
│   ├── gateway/jw/          教务请求网关：run.ts 按 mode 在「后端代理 / 本地直连」切换并兜底
│   ├── repo/                跨 feature 的 SQLite repository（如 userProfileRepo）
│   └── user/                旧 userInfo 存储桥接
├── features/            ✅ 新功能放这里（16 个模块，结构尚不一致，见下文「feature 结构」）
├── components/          ✅ 跨 feature 复用组件，含 un-ui/ 自研基础 UI 库
├── hooks/              🔄 全局 hooks（useUserConfig / useCourseData / useGpa 等）
├── shared/             ✅ 通用工具（color / domParser / rasPassword / theme）
├── store/              ✅ mmkv 持久化封装
├── utils/              ✅ objectUtils
├── route/              ✅ 导航配置（RootStack + 3 个子 Stack）
├── widget/             ✅ Android 桌面小组件（独立子系统）
├── api/schema/         📦 旧 schema 碎片（examScoreSchema）
├── screens/            📦 ★旧页面目录★（仍大量使用，新代码不要往这里堆业务）
├── js/                 📦 ★旧业务层★（19 文件：jw/ auth/ mgr/ be/ wjxt/ info/ HTMLparser/）
├── class/              📦 旧 class 封装（4 文件）
└── type/               📦 旧类型目录（19 文件：api/ infoQuery/ app/）
```

**关键边界**：新代码进 `features/` + `core/`；`src/js`、`src/class`、`src/type`、`src/screens` 是遗留区，只在维护旧页面时才碰。路由同时指向新旧两套目录，这是渐进迁移的正常状态。

## 认证现状（⚠️ 最容易踩坑的地方）

**两套认证路径目前并存**，这是当前最大的技术债：

| 路径 | 位置 | 状态 |
|---|---|---|
| ✅ 新 | `src/core/auth/` 三套状态机（Jw/attendance/unified）+ `createAuthCore` | 主路径，新代码必须用 |
| 🔄 旧 | `src/js/jw/jwxt.ts`（testToken/refreshToken/unifiedLogin） | **仍存在，被 8 处引用**，待废弃 |

新代码请这样判断教务登录态：

```ts
const ok = await ensureJwAuthenticated();
if (!ok) return null;
```

**不要**继续把 `src/js/jw/jwxt.ts` 当自动重登入口——它和 `JwMachine` 并存会造成 Cookie 与状态竞争。修改认证相关代码前，先确认你触达的是哪一套。

> 注：`best_practice.md` P0 要求删除 `jwxt.ts`、移除 `http.ts` 里的 Toast，**截至本文档撰写时尚未完成**。改这两处时注意它们仍是"活的"。

## 数据库现状

schema 集中在 `src/core/schema.ts`（drizzle 定义），迁移产物在 `drizzle/migrations/`，配置见 `drizzle.config.ts`。`App.tsx` 只调 `initDB()`，不再散落建表逻辑。

**实际有的 6 张表**：

| 表 | 主键 | 用途 | repository |
|---|---|---|---|
| `evaluationTemplates` | id(自增) | 评教模板 | `features/evaluation/store/` |
| `userProfiles` | studentId | 用户档案 | `core/repo/userProfileRepo.ts` |
| `termStartDay` | (year, term) 复合 | 学期开学日 | `features/courseSchedule/repo/startDay.ts` |
| `examScore` | id | 考试成绩 | `features/examScore/repo/ScoreRepo.ts` |
| `examInfo` | (id, studentId, year, term) 复合 | 考试信息 | `features/examInfo/repo/ExamInfoRepo.ts` |
| `selectedCourses` | (studentId, year, term, classId) 复合 | 已选课程 | `features/selectedCourse/repo/SelectedCourseRepo.ts` |

**与 best_practice 的偏差**（改库相关代码时务必知晓）：

- ❌ **没有 `schedule_items` 表**：best_practice P1 要求把课表/考试/考勤/物理实验统一为不同 source 存入此表，目前**未实现**。课表数据仍在 react-native-storage，不在 SQLite。
- ⚠️ **`userProfiles` 主键是单字段 `studentId`**，非 best_practice 建议的复合主键 `(account_type, username)`，多账号切换存在污染风险。
- ⚠️ **`examScore` 没有 `studentId`**，成绩缓存仍可能跨账号污染；`examInfo` 与 `selectedCourses` 已按学号隔离。
- ⚠️ **`initDB()` 仍尝试删除 4 个历史 snake_case 表名**，但当前 drizzle 表使用 camelCase；这段清理不是正式迁移机制，应逐步移除而不是扩展。

规则：**不在组件里写 SQL**；多行写入用事务；刷新按 `source/year/term` 替换，不要混写半新半旧；页面先读本地库展示旧数据，再后台刷新网络。

## 数据流硬规则

主路径（必须遵守）：

```
screen/component → hook → feature api / repository → core http/auth/db → 外部系统 / SQLite
```

禁止主路径：

```
screen/component → 直接 http / sql / cookie / storage
```

外部系统不可信。外部响应必须先进 schema/parser（Zod），输出稳定内部模型，UI 只消费内部模型。原始响应需保留时放 `raw` / `raw_json`，不要让 UI 依赖原始字段。转换函数保持纯函数。

## 错误处理硬规则

```
api/repository → throw / return null
hook          → 转成 loading/error/data 状态
screen        → 显示一次提示或降级界面
```

底层 API **不弹 Toast、不 Alert**。同一轮刷新最多提示一次；有缓存时优先展示缓存，不因网络失败清空页面。（注：`core/http.ts` 当前仍违反此规则，待清理。）

## feature 结构约定

`src/features/` 下 16 个模块，**结构目前不一致**：子目录命名混用 `screen`/`screens`、`component`/`components`、`hook`/`hooks`、`type`/`types`；多数 feature 缺 hooks/schema/utils 层，逻辑可能仍混在 screen 里。

新增 feature 或文件时：**就近匹配同 feature 已有命名**，不要引入第三种风格。理想结构（best_practice 目标）为 `api/hooks/components/screens/type/schema/utils`，但不必为统一而大面积重命名旧目录。

复杂 feature 参考 `courseSchedule` 和 `evaluation`，它们最接近目标结构。

## 命名与注释

- 函数名说明责任，不讲故事；名字需要 `And`/`Then` 时先考虑拆函数。
- 新增有意义函数推送前补中文契约注释（作用/入参/出参/修改注意），见 best_practice 模板。
- UI 优先复用 `un-ui`：`UnCard` / `UnPressable` / `UnText` / `Flex` / `Icon` / `UnRefreshControl`。
- 主题色从 `@rneui/themed` 和 `useUserConfig` 读，不要散落硬编码大面积颜色。
- 工具按钮用现有 `Icon`，不要手写图标。调试入口隔离（如 `TestPage`），不要混进业务页面。

## 组件文档约定

可复用组件按复杂度分三档决定文档形式，避免一刀切：

| 档位 | 适用对象 | 文档形式 | 例子 |
|---|---|---|---|
| 重 | 有设计决策、被多处复用、交互逻辑非显然 | **同目录同名 `.md`**（`Foo.tsx` + `Foo.md`） | `ChooseTerm` |
| 轻 | 薄封装的基础 UI、单一职责 | 文件顶部 JSDoc 注释块即可 | `UnCard` / `Flex` |
| 无 | 单一用途、只被一个页面使用 | 不需要单独文档 | 多数 screen 内组件 |

写 `.md` 时的内容要点（按需取用，不必凑齐）：

1. **它解决什么问题**：一句话职责边界，避免重复造轮子。
2. **设计思路**：钉死非显然的决策--为什么这么编码、为什么用空值代表某状态、边界怎么推算。这些是看代码看不出的"为什么"。
3. **API**：props 的类型与语义，标注易踩坑的约定值（如 `year: number | ""` 的空字符串）。
4. **数据依赖**：组件靠什么外部数据（repo/hook/store），缺失时的降级行为。
5. **使用方对照**：被哪些页面复用、各调用方传参差异一览，改组件时能立刻评估影响面。
6. **已知问题 / 改进方向**：给后续维护留路标。

两条硬规则：

- `.md` 紧贴 `.tsx` 放在**同一目录**，不要集中到 `docs/`。同目录才能保证"改组件时必然看见文档"，不易腐烂。
- 写文档时若发现组件**位置与职责错位**（如放在 `examInfo/` 下却被课表复用），在文档开头标注"位置待迁移"并说明目标位置，不要假装问题不存在。参考 `ChooseTerm.md`。

## 测试现状

项目目前**无有效项目内测试**，只有 `jest.config.js`（`react-native` preset）。优先补测试的位置：纯转换函数（`normalizeCourse`/`normalizeExam`/`parseWeeks`）、认证状态机流转、repository 读写、HTML/parser。不要从页面快照开始。

## 文档导航

| 想了解什么 | 看哪里 |
|---|---|
| 工程规范与目标（数据流/认证/持久化/错误处理细则） | [`best_practice.md`](./best_practice.md) |
| 各外部系统接口逆向（教务/统一认证/考勤/教师/OA/后端代理等） | [`docs/api-docs/`](./docs/api-docs/) |
| 后端代理登录方案（提案，尚未落地） | [`login-proxy.md`](./login-proxy.md) |
| 快速开始 / 功能特性 / 项目结构（对外门面） | [`README.md`](./README.md) |
| RN 环境搭建与旧目录说明（部分过时） | [`React.md`](./React.md) |
| **代码现状、新旧边界、硬性约定** | 本文件 |

## 给 AI 助手的最短摘要

- React Native Android-only 校园工具 App；包管理 pnpm；`@/` = `src/`。
- 新代码进 `features/` + `core/`；`src/js`、`src/class`、`src/type`、`src/screens` 是遗留区，勿新增。
- 认证走 `core/auth/` 状态机，**不要**用 `src/js/jw/jwxt.ts`（旧路径，仍被引用但待废弃）。
- DB schema 在 `src/core/schema.ts`（drizzle，6 张表）；**没有 `schedule_items` 表**；迁移必须生成并注册到 `migrations.ts`。
- 外部响应先过 Zod schema → normalize 成稳定模型 → 才给 UI；页面不直接碰 http/sql/cookie。
- 底层不弹 Toast；hook 转 loading/error/data；screen 提示一次。
- feature 结构不统一，新增文件就近匹配同 feature 命名。
- `best_practice.md` 是目标态，本文件是现状态；冲突时本文件描述现状。

<!-- OPENWIKI:START -->

## OpenWiki

This repository has a generated `openwiki/` evidence index. It is optional just-in-time context, not required startup reading.

- Treat source code and tests as authoritative. A brief's unknowns and review items are verification gaps, not automatic requirements.
- Prefer the narrowest quiet validation that proves the changed behavior. Preserve complete failure output.

The scheduled OpenWiki GitHub Actions workflow refreshes the repository wiki. Do not hand-edit generated OpenWiki pages unless explicitly asked; prefer updating source code/docs and letting OpenWiki regenerate.

<!-- OPENWIKI:END -->
