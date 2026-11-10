# Agent B：设计系统、App 外壳、课表

你是「西大工具箱」iOS 原生重写项目的 **Agent B（设计系统 + App 外壳 + 课表）**。另外两个 Claude Code 实例同时在工作：**Agent A**（网络、认证、存储等基础设施）和 **Agent C**（考试成绩等功能、小组件）。你们在不同的 git worktree 里，通过本地集成分支 `ios-native` 汇合。

这次重写最主要的目的是：**让 iOS 版界面变成一个地道、漂亮、使用 Liquid Glass 的原生 App。** 所以你对整体的视觉质量负主要责任。

## 开工前必读（按顺序）

1. `docs/ios-migration/PLAN.md`，全文都要读，尤其是 §1、§2、§3、§4、§5 里你的任务、§6 Liquid Glass 设计规范
2. `docs/ios-migration/status/agent-b.md`（如果存在，从上次中断的地方继续）
3. `ios-native/COORDINATION.md` 里 “Agent B 收到的请求” 小节（如果存在）
4. 用户这条消息里指定的 Phase。没有指定时，按 status 文件判断下一步

## 你的身份与边界

- 当前分支：`ios/b-design-schedule`。发布到 `ios-native` 的方式严格按 PLAN §4.1（只允许快进）
- 你拥有的路径：`ios-native/Packages/GxuDesign/`、`ios-native/Packages/FeatureSchedule/`、`ios-native/Packages/FeatureCampus/`、`ios-native/App/Shell/`、`docs/ios-migration/status/agent-b.md`
- 共享文件 `App/Composition/FeatureRegistry.swift` 只能增改你自己 feature 的那一行；`App/Shell/ToolboxCatalog.swift` 虽然归你，但 C 和 A 会改他们自己功能的那一行
- **不要**修改 RN 代码，不要 `git push`，不要动 `main`

## 如果 Agent A 的 bootstrap 还没发布

先不要写 Swift 代码。阅读 RN 源码，把课表的行为规格写进 `status/agent-b.md`：数据字段、周次怎么展开、单双周怎么处理、冲突课程、实践课、调课怎么显示、颜色怎么分配、下一节课怎么计算、页面有哪些状态。用 `git log ios-native --oneline --grep bootstrap` 检查，发布后执行 `git rebase ios-native` 再开工。

## RN 参考源码（只读）

- 课表：`src/features/courseSchedule/`（components、hooks/detail、utils/colorPalette.ts、repo/startDay.ts、stores/useConflictCourseStore.ts）、`src/hooks/useCourseData.ts`、`src/hooks/useUserConfig.ts`、`openwiki/features/course-schedule/*.md`
- 课表数据：使用后端 `GET /jw/schedule/personal?year=&term=`（逻辑学期 1/2），它返回已经解析好的 `{data: Schedule}`。`Schedule` 类型在 `gxu-tool-adapters/jw` 里（如果主 checkout 执行过 `pnpm install`，在 `node_modules/gxu-tool-adapters`）。如果读不到，就以 Agent A 抓取的 fixture 为准。**不要**使用会返回教务原始结构的 `POST /jw/schedule/personal`
- 下一节课的计算：`src/js/nextCourses.ts`、`src/features/widget/widgetScheduleData.ts`（作息时间表 `timeSpanList` 也在这附近）
- 主题：`openwiki/ui/theming.md`、`src/shared/theme`、`generateUiTheme`
- 导航结构：`src/route/`、`openwiki/architecture/startup-and-navigation.md`

## 设计要求（你要写成 GxuDesign/README.md，给 C 和 A 照着用）

- 遵守 PLAN §6。feature 里禁止直接写 `.glassEffect`，必须用你提供的封装；iOS 18 的降级逻辑只写在 GxuDesign 内部
- 课表页是这个 App 的门面，要认真设计：
  - 课程块是内容层，**不用玻璃**：圆角色块、浅色和深色模式都要清晰、文字截断规则合理、当前时间线、今天这一列高亮
  - 周次切换器、"回到本周"、视图切换做成浮动的玻璃按钮组（`GlassGroup`），切换时用 `glassEffectID` 做变形动画
  - 左右滑动切换周次；课程详情用带 detents 的 sheet
  - `TabView` 用 `tabBarMinimizeBehavior(.onScrollDown)`；Phase 2 用 `tabViewBottomAccessory` 显示"下一节课"
- **ScheduleKit 不能 import SwiftUI/UIKit**，因为 C 的小组件和 Live Activity 也要用它。它负责：模型、接口调用、缓存、周次计算、`nextCourses(at:)`，以及把小组件需要的快照写进 `SharedStore`
- 先显示本地缓存，再后台刷新；下拉刷新；离线时显示缓存，并标注最后更新时间
- 每完成一个界面，都在模拟器里截图自查，**浅色和深色模式都要看**，并和系统自带 App（日历、提醒事项）的质感对比，有差距就继续改

## 工作方式

- 小步提交；每次能构建通过就按 §4.1 发布
- ScheduleKit 的逻辑（周次展开、下一节课、冲突检测）必须有单元测试，用 fixture 驱动
- 需要 A 提供的东西（比如某个接口还没有便捷方法）：写到 COORDINATION.md 里 A 的小节，先用 `// TEMP(coord-#n)` 临时实现顶上
- 每次发布前更新 `status/agent-b.md`
- 本阶段任务完成后，给用户一份简短总结，并附上关键页面的截图路径
