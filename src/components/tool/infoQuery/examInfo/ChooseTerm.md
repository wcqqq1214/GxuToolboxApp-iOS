# ChooseTerm 学期选择器

> 组件位置：`src/components/tool/infoQuery/examInfo/ChooseTerm.tsx`
> 状态：**位置待迁移**。当前路径暗示它专属于"考试信息"，但实际上课表查询也在用。真实职责是**通用学期选择器**，计划日后迁到 `components/common/` 或共享区。迁移前请勿继续在此路径下堆新组件。

## 它解决什么问题

教务系统里，"学期"由两个维度组成：**学年**（如 2025）和**学期**（秋季/春季）。各查询页（考试、成绩、绩点、课表）都需要让用户选学期，但每个页面自己拼这套逻辑会造成重复且不一致。

`ChooseTerm` 把"选学期"收敛成一个受控组件：读用户档案拿到入学年份和学习年限，生成合法学年列表，通过 `onTermSelect` 回调把选择结果告诉父页面。父页面不需要关心学年怎么算、学期怎么编码。

## 设计思路

### term 编码：为什么是 3 和 12

教务系统用字符串 `"3"` 表示秋季学期、`"12"` 表示春季学期（源自教务接口的字段值，非人类习惯的 1/2）。组件内部统一用这套编码对外回调，**不在此处做转换**，由调用方按需 `+Term` 转 number。

```ts
const termOptions = [
    {label: "秋季学期", term: "3"},
    {label: "春季学期", term: "12"},
    ...(includeWholeYear ? [{label: "全学年", term: ""}] : []),
];
```

### year 传空字符串 = "全历史"

`onTermSelect` 的 `year` 参数类型是 `number | ""`。**空字符串是约定值**，表示"入学以来所有数据"（对应组件顶部的"入学以来所有数据"按钮）。

这是一个容易被误用的点：调用方如果只按 `number` 处理 `year`，会在用户点"全历史"时拿到 `""` 导致 `Number("")` 变 0。各调用方目前的处理见下文"使用方对照"。

### 当前学年的推算

教务学年跨自然年：2026 年 2 月属于 2025-2026 学年。组件用简单规则推算：

```ts
// 9 月之前算上一年的学年
const realAcademicYear = currentMonth < 9 ? currentYear - 1 : currentYear;
```

默认学期同理：3-8 月默认春季（`"12"`），其余默认秋季（`"3"`）。

### 三档过滤器

顶部有"当前 / 至今 / 全部"三档，控制学年列表的范围：

| filterType  | 含义                       | 默认 |
| ----------- | -------------------------- | ---- |
| `current`   | 只显示当前学年             |      |
| `no_future` | 排除未来学年（≤ 当前学年） | ✓    |
| `all`       | 全部学年                   |      |

### 交互细节

- 选中"全历史"时，下方学年/学期区半透明（`opacity: 0.5`），暗示当前生效的是顶部按钮。
- 在"全历史"状态下点学期按钮，会自动回退到最近一个学年，避免"选了学期却没反应"的困惑。
- 学期按钮用 `flex: 1` 平分宽度，2 个或 3 个按钮都能自适应。

## API

```ts
interface ChooseTermProps {
    /** 学期选中回调。year 为空字符串时表示"全历史"。
     *  term 编码："3"=秋季 "12"=春季 ""=全学年 */
    onTermSelect?: (year: number | "", term: string) => void;
    /** 是否显示"全学年"学期选项，默认 true */
    includeWholeYear?: boolean;
    /** 是否显示"入学以来所有数据"按钮，默认 true */
    includeWholeLife?: boolean;
}
```

组件**非受控于父页面的选择状态**：内部自管 `selected`，仅通过回调通知。首次挂载会自动选中"当前学年的当前学期"并触发一次回调。

## 数据依赖

- `useJwAccount()` 拿当前教务账号 username。
- `userProfileRepo.get(username)` 读 SQLite 的 `userProfiles` 表，取 `grade`（入学年份）和 `study_years`（学习年限）。
- profile 尚未同步时（如 OTA 后旧表被清），组件**不崩也不渲染**（`enrollmentYear && (...)`），等启动补拉到档案后再出现。

## 使用方对照

| 调用方                                    | includeWholeLife | includeWholeYear | year 处理         | term 处理         |
| ----------------------------------------- | ---------------- | ---------------- | ----------------- | ----------------- |
| `features/examInfo/screens/ExamInfo`      | false            | false            | `String(Year)`    | 原样 `Term`       |
| `features/examScore/screen/ExamScore`     | false            | false            | `String(Year)`    | 原样 `Term`       |
| `features/examScore/screen/GPAcalculator` | true（默认）     | true（默认）     | `Year`（number）  | `+Term`（number） |
| `screens/.../CourseScheduleQuery`         | false            | false            | `+Year`（number） | `+Term`（number） |

注意 `ExamInfo`/`ExamScore` 把 year 转成 `String` 再存，而 `GPAcalculator`/`CourseScheduleQuery` 转 number。这是调用方各自的本地状态类型差异，组件本身只回传 `number | ""`。

## 已知问题 / 改进方向

- **位置错位**：放在 `examInfo/` 下但被课表复用，应迁到通用目录。
- **year 空字符串约定脆弱**：`number | ""` 容易让调用方踩坑，可考虑改成显式枚举或对象回调。
- **profile 缺失时静默不渲染**：用户会看到页面少一块却不知原因，可加占位或提示。
- **样式内联**：`StyleSheet.create` 写在函数体内，每次渲染重建（违反 best_practice 的 no-inline-styles 精神，虽然这里不是内联对象）。可提到组件外。
- **缺测试**：学年生成、过滤器、默认学期推算都是纯逻辑，适合补单测。
