# gxu_tool_app Best Practice

本文档记录当前项目里值得保留的工程做法，以及旧代码迁移到这些做法的步骤。目标不是重写项目，而是给新代码和必要维护代码设定清楚边界。

## 一句话结论

这个项目本质上是一个 React Native 校园工具 App：从教务、统一认证、考勤、文件、反馈等外部系统取数据，转成稳定的本地模型，再给页面和小组件展示。

最重要的工程原则：外部系统不可信，UI 不应该直接承受外部接口的混乱。所有新代码必须先建立边界，再进入业务。

## 项目入口

- `index.js`：注册 React Native 根组件和 Android widget task handler。
- `App.tsx`：挂载 `ThemeProvider`、`SafeAreaProvider`，执行应用级初始化。
- `src/screens/Root.tsx`：初始化用户配置、课表配置、冲突课程 store，并挂载导航容器。
- `src/route/RootStack.tsx`、`src/route/screens/*.tsx`：页面导航入口。
- `src/screens/MainTab.tsx`：主 Tab 入口。

启动逻辑必须保持轻量。启动阶段只做必要初始化，不要发起多个会修改认证态或 Cookie 的业务请求。

## 目录职责

- `src/core/`：跨 feature 的基础设施。认证、HTTP、数据库、持久化都应该在这里有明确边界。
- `src/features/`：新功能优先放这里。每个 feature 自己管理 `api`、`hooks`、`components`、`screens`、`type/schema`、`utils`。
- `src/components/`：跨 feature 复用组件。`components/un-ui` 是当前已有 UI 基础层。
- `src/screens/`：旧页面目录。新代码不要继续把业务散进这里，除非是在维护旧页面。
- `src/js/`：历史工具和旧业务层。新增代码不要放这里；迁移时逐步把旧认证、请求、解析逻辑移出。
- `src/type/`：历史类型目录。新 feature 优先把类型放在 feature 内，公共类型再上移。
- `src/class/`：历史 class 封装。新代码优先使用普通对象和明确的转换函数，除非 class 真能表达稳定领域行为。

## 数据流规则

推荐主路径：

```text
screen/component
  -> hook
  -> feature api / repository
  -> core http/auth/db
  -> external system / SQLite
```

禁止主路径：

```text
screen/component
  -> http/sql/cookie/storage 直接操作
```

页面只负责展示、用户交互和少量组合逻辑。网络请求、认证检查、缓存读写、数据转换都不应该写在页面里。

## 外部数据处理

当前相对正确的做法在课表模块：

- `src/features/courseSchedule/type/schema/course.ts` 用 Zod 接住教务原始字段。
- `src/features/courseSchedule/utils/normalizeCourse.ts` 把外部响应转成 `ScheduleTableItem`。
- `src/features/courseSchedule/type/schedule.ts` 定义 UI 需要的稳定日程模型。

新代码必须遵守：

1. 外部响应先进入 schema/parser。
2. schema/parser 输出稳定内部模型。
3. UI 只消费内部模型。
4. 原始响应需要保留时，放在 `raw` 或 `raw_json`，不要让 UI 依赖原始字段。
5. 转换函数保持纯函数，方便测试。

反例：

- 在页面里直接判断接口字段。
- 在 hook 里混合解析、缓存、网络请求、Toast、状态更新。
- 使用 `any` 接住复杂业务响应后继续向下传。

## 认证边界

新代码必须走 `src/core/auth`。

当前推荐方向：

- `createAuthCore.ts`：通用认证状态机。
- `JwMachine.ts`：教务认证状态入口。
- `JwAuthClient.ts`：教务认证 HTTP 客户端。
- `unifiedMachine.ts` / `attendanceMachine.ts`：其他账号系统的状态入口。

认证边界规则：

1. 业务 API 只问一个问题：当前系统是否已认证。
2. 自动重登只能由对应 machine 负责。
3. Cookie 清理只能出现在“开始一次新登录”的边界，不允许藏在 `getPublicKey` 这类读函数里。
4. 不允许同时保留两套自动登录主路径。
5. 需要验证码的系统不要假装支持无感重登。
6. 认证失败返回状态，不在底层反复弹 Toast。

教务业务 API 应该依赖类似：

```ts
const ok = await ensureJwAuthenticated();
if (!ok) return null;
```

不要继续使用旧 `src/js/jw/jwxt.ts` 作为自动重登入口。它和 `JwMachine` 并存会造成 Cookie 和状态竞争。

## HTTP 规则

`src/core/http.ts` 是全局 HTTP 边界。它应该只做通用配置和错误传播，不应该弹账号配置 Toast。

规则：

1. response error interceptor 必须 reject 错误，不要把 error 当 response 返回。
2. request interceptor 不要做 UI 提示。
3. feature api 自己决定如何处理业务失败。
4. 底层 API 不弹 Toast，不 Alert。
5. 页面或 hook 做一次性错误提示。

坏路径：

```text
多个 API 同时失败 -> 每个底层函数 ToastAndroid.show -> 用户看到连续弹窗
```

好路径：

```text
多个 API 同时失败 -> hook 汇总为一个状态 -> 页面显示一次失败提示或降级 UI
```

## 持久化规则

当前有三类持久化：

- `react-native-storage` + AsyncStorage：适合小配置、简单 key-value。
- SQLite：适合结构化业务数据，例如日程项、用户档案、评价模板。
- Zustand：适合内存状态，不是持久化边界本身。

配置类数据可以沿用 `useUserConfig.ts` 的模式：

```text
default config
  -> storage load
  -> deepMerge
  -> zustand store
```

业务实体不要继续存成随意 JSON blob。主页课表、考试、考勤建议进入 SQLite。

推荐 SQLite 表：

```sql
CREATE TABLE IF NOT EXISTS schedule_items
(
    id         TEXT PRIMARY KEY,
    source     TEXT    NOT NULL,
    year       INTEGER NOT NULL,
    term       TEXT    NOT NULL,
    week       INTEGER NOT NULL,
    day        INTEGER NOT NULL,
    begin      INTEGER NOT NULL,
    end        INTEGER NOT NULL,
    title      TEXT    NOT NULL,
    subtitle   TEXT,
    location   TEXT,
    teacher    TEXT,
    kind       TEXT    NOT NULL,
    status     TEXT,
    raw_json   TEXT,
    updated_at INTEGER NOT NULL
);
```

用户档案建议：

```sql
CREATE TABLE IF NOT EXISTS user_profiles
(
    account_type TEXT    NOT NULL,
    username     TEXT    NOT NULL,
    name         TEXT,
    school       TEXT,
    grade        INTEGER,
    class_name   TEXT,
    subject      TEXT,
    subject_id   TEXT,
    raw_json     TEXT,
    updated_at   INTEGER NOT NULL,
    PRIMARY KEY (account_type, username)
);
```

SQLite 使用规则：

1. 不在组件里写 SQL。
2. SQL 放到 repository，例如 `scheduleRepository.ts`、`profileRepository.ts`。
3. 写入多行数据必须用事务。
4. 刷新数据按 `source/year/term` 替换，不要混写半新半旧数据。
5. 页面先读本地库展示旧数据，再后台刷新网络。
6. 数据库初始化必须可重复执行，使用 `CREATE TABLE IF NOT EXISTS` 和明确迁移步骤。

## Store 和 Hook 规则

Hook 的职责要窄：

- 数据读取 hook：负责读 store/repository，触发加载。
- 行为 hook：负责提交、刷新、批处理。
- UI hook：只封装页面交互状态。

不要把下面这些塞进同一个 hook：

```text
网络请求 + 认证刷新 + 数据解析 + 缓存写入 + Toast + UI 状态
```

当前 `useBaseCourse` 的方向可以保留：先读缓存，再请求网络，再 normalize，再更新 store。但业务实体缓存应该逐步从
`react-native-storage` 迁到 SQLite repository。

## UI 规则

优先复用：

- `UnCard`
- `UnPressable`
- `UnText`
- `Flex`
- `Icon`
- `UnRefreshControl`
- `UnJsonEditor`

UI 规则：

1. 页面组件不直接操作外部系统。
2. 列表项、详情卡、表单项拆成小组件。
3. 工具按钮使用现有 `Icon`，不要手写图标。
4. 主题色从 `@rneui/themed` 和 `useUserConfig` 读，不要散落硬编码大面积颜色。
5. 调试入口必须隔离，例如 `TestPage`，不要混进业务页面。

导航规则：

1. feature 页面注册在对应 stack。
2. 页面名保持短、稳定，不要随意改公开路由名。
3. `ToolboxIndex` 这种入口表已经膨胀，后续应抽出工具注册配置，不要继续堆 JSX 对象。

## 错误处理规则

底层只返回错误，不负责教育用户。

推荐：

```text
api/repository
  -> throw Error / return null
hook
  -> 转成 loading/error/data 状态
screen
  -> 显示一次提示或降级界面
```

禁止：

```text
api
  -> ToastAndroid.show
  -> return undefined
```

错误提示要做到：

1. 同一轮刷新最多提示一次。
2. 有缓存时优先展示缓存，不因网络失败清空页面。
3. 认证失效显示登录状态，不循环弹窗。

## 命名规则

函数名说明责任，不讲故事。

好：

- `normalizeCourse`
- `parseToken`
- `syncUserProfile`
- `replaceScheduleSource`
- `ensureJwAuthenticated`

坏：

- `parseTokenAndValidateUserThenCreateSession`
- `handleUserLoginWhenTokenExpiredAndFallbackEnabled`

如果函数名需要 `And` 或 `Then`，先检查是否应该拆函数。

## 注释规则

注释解释契约和边界，不复述代码。

新增有意义函数在准备推送前按项目要求补充中文契约注释：

```ts
/**
 * 作用：说明业务语义。
 * 入参：
 * - xxx：说明来源、含义、关键约束。
 * 出参：
 * - 返回值含义、失败或空值情况。
 * 修改注意：
 * - 说明调用方契约、兼容性和测试要求。
 */
```

不要写攻击性注释，不要写“AI 不准改”。

## 测试规则

当前项目没有有效的项目内测试文件，只有 `jest.config.js`。这是风险，不是小问题。

优先补测试的地方：

1. 纯转换函数：`normalizeCourse`、`normalizeExam`、`parseWeeks`。
2. 认证状态机：`createAuthCore` 的状态流转和并发复用。
3. repository：SQLite 的 `list`、`replaceSource`、`upsert`。
4. parser：个人信息、评教 HTML、成绩解析。

测试不应该先从页面快照开始。先测数据结构和边界函数，收益最大。

## Code Review Checklist

提交前至少检查：

- 是否新增了直接访问外部接口的页面代码？
- 是否新增了底层 Toast/Alert？
- 是否绕过了 auth machine？
- 是否把外部响应直接传给 UI？
- 是否把业务实体继续存成无结构 JSON blob？
- 是否引入了新的全局状态或隐式副作用？
- 是否有 schema/parser/normalize 边界？
- 是否有失败路径和缓存降级策略？
- 是否只改了当前任务需要的范围？

## TODO LIST

### P0：先止血

- [ ] 修正 `src/core/http.ts`：response error interceptor 必须 `Promise.reject(error)`。
- [ ] 移除 `src/core/http.ts` request interceptor 里的账号 Toast；账号状态由 auth UI 显示。
- [ ] 完成教务认证统一入口：业务 API 只调用 `ensureJwAuthenticated()`。
- [ ] 停止在业务路径使用 `src/js/jw/jwxt.ts` 的 `testToken`、`refreshToken`、`unifiedLogin`。
- [ ] 把旧 `jwxt.ts` 中的 Cookie 清理移到登录边界，最终删除旧认证入口。
- [ ] 清理底层 API 的 `ToastAndroid.show`，改成返回状态或抛错。

### P1：稳定主页数据

- [ ] 建立 SQLite schema 管理模块，不要继续在 `App.tsx` 里散落建表逻辑。
- [ ] 新增 `schedule_items` 表和 `scheduleRepository`。
- [ ] `useBaseCourse` 启动时先读 SQLite，再后台刷新网络。
- [ ] 网络成功后按 `source/year/term` 事务替换课程数据。
- [ ] 把考试数据迁入同一张 `schedule_items` 表，source 使用 `jw_exam`。
- [ ] 把考勤数据作为 `attendance` source 存入 SQLite。
- [ ] 把物理实验数据作为 `phy_exp` source 存入 SQLite，先在 UI 合并，不直接覆盖课程源数据。

### P2：用户档案和账号状态

- [ ] 新增 `user_profiles` 表和 `profileRepository`。
- [ ] 登录成功后后台同步教务个人信息。
- [ ] 个人信息页先读 SQLite 展示，再后台刷新。
- [ ] 为每个 profile 记录 `account_type`、`username`、`updated_at`。
- [ ] 账号切换时避免旧 profile 污染新账号。

### P3：收敛旧目录

- [ ] 新功能禁止放进 `src/js`。
- [ ] 将 `src/js/jw/course.ts` 中仍保留的业务 API 迁到 `src/features/courseSchedule/api`。
- [ ] 将 `src/js/jw/exam.ts` 迁到对应 feature api。
- [ ] 将工具箱入口数据从 `ToolboxIndex.tsx` 抽成配置文件。
- [ ] 将大型页面拆成 screen + hook + components。

### P4：补测试和质量门槛

- [ ] 给 `normalizeCourse`、`normalizeExam`、`parseWeeks` 补 Jest 测试。
- [ ] 给 `createAuthCore` 补状态流转测试。
- [ ] 给 SQLite repository 补基础读写测试。
- [ ] 修复 `npx tsc --noEmit` 当前全局类型错误。
- [ ] 将 lint warning 逐步收紧，至少禁止新代码 unused vars。
- [ ] CI 中加入 `npm test`、`eslint`、类型检查。

### P5：删除旧实现

- [ ] 全局 `rg "jwxt"`，清空剩余引用。
- [ ] 删除 `src/js/jw/jwxt.ts`。
- [ ] 删除已被 SQLite 替代的 `react-native-storage` 业务缓存 key。
- [ ] 删除只服务旧路径的重复 parser、class 或 helper。
- [ ] 删除不再使用的调试代码和注释块。
