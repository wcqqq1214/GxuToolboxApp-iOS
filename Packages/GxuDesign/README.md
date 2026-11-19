# GxuDesign

项目的视觉与基础组件库，负责集中管理主题、玻璃材质封装、内容卡片、状态视图和课程配色。业务页面的界面统一通过这里提供的组件来写，这样 iOS 26 的 Liquid Glass 效果和 iOS 18 的 Material 降级只需要在这一个包里维护。

最低支持系统为 iOS 18。iOS 26 才有的接口（`glassEffect`、`GlassEffectContainer`、`glassEffectID`、`tabBarMinimizeBehavior`、`tabViewBottomAccessory`）都收口在 `Glass.swift` 里，并用 `#available(iOS 26, *)` 隔离；运行在 iOS 18 上时自动退回到 Material 材质。

## 界面规范

1. **玻璃只用在导航和浮动层**：包括标签栏、工具栏、浮动按钮、sheet 和底部附件；课程块、成绩列表和卡片正文不要用玻璃。
2. **不要在玻璃上再叠玻璃**：相邻的浮动玻璃控件放进同一个 `GlassGroup`，方便系统合并与形变。
3. **保留系统默认材质**：系统的 `TabView`、`NavigationStack` 工具栏和 `.sheet` 默认自带玻璃效果，不要手动设背景色或覆盖 `toolbarBackground`。
4. **禁止绕开封装**：业务模块里不要直接调用 `.glassEffect`、`.buttonStyle(.glass)` 或 `GlassEffectContainer`，一律使用本包提供的封装。
5. **字体与色彩**：主题色只用作强调色（`tint`），图标统一用 SF Symbols，文字使用系统动态字号样式（`.headline`、`.body` 等），不要写死字号以保证支持 Dynamic Type。

RN 上游只用来对照功能逻辑、数据结构和边界条件，界面本身遵循 iOS 原生交互习惯，优先选用 `List`、`Form`、`Picker`、`Menu`、`.sheet` + detents、`.contextMenu`、`.swipeActions`、`.refreshable` 和 `.searchable`。

## 用法

### 主题

```swift
@State private var theme = GxuTheme()          // 根视图里创建一次（App/Shell/RootView 已配置）
RootView().gxuTheme(theme)                     // 下发强调色与外观模式

@Environment(GxuTheme.self) private var theme  // 读取或修改：theme.accentHex = 0xE5484D
```

视图里使用强调色请写 `Color.accentColor` 或 `.tint`，不要拿 `theme.accent` 大面积铺页面底色。

课表和工具箱的根页加上 `.gxuPageBackground(inNavigation: true)`，让页面底色与自定义背景图延伸到导航栏下方。

### 玻璃控件

```swift
// 浮动控件（相邻控件放进同一 GlassGroup 并共用 @Namespace 才能形变）
@Namespace private var ns
GlassGroup {
    HStack {
        GlassButton(systemImage: "chevron.left", accessibilityLabel: "上一周") { … }
            .gxuGlassID("prev", in: ns)
        if away { GlassButton("本周", systemImage: "arrow.uturn.backward", prominent: true) { … }
            .gxuGlassID("today", in: ns) }
    }
}

// 自定义浮动面板
Text("…").padding().gxuGlass(in: RoundedRectangle(cornerRadius: 20))

// 标签栏
TabView { … }.gxuTabBarFixed()                        // 系统标签栏，iOS 26 保留液态玻璃且不随滚动收起
TabView { … }.gxuTabAccessory { NextCourseBar() }     // 标签栏上方附件，iOS 18 降级为底部材质条
SomeTabContent.gxuAccessoryInset()                    // iOS 18 降级时为附件留出底部空间
DetailView().gxuHidesTabChrome()
```

无标题的 `GlassButton` 默认是 44pt 圆形图标按钮，调用时必须传入 `accessibilityLabel`。

### 内容卡片与配色

```swift
ContentCard { VStack(alignment: .leading) { … } }      // 纯色圆角卡片，不用玻璃材质
CourseTint(hex: 0xB5EAD7).fill / .text / .marker       // 课程块配色，浅深色分别校准，文字对比度不低于 4.5:1
```

课程基色统一从 `ScheduleKit` 的 `CoursePalette` 获取，不要在视图里自己改透明度。

### 状态视图

```swift
GxuLoadingView("加载中…")
GxuEmptyView("没有考试", systemImage: "calendar", message: "…", actionTitle: "去登录") { … }
GxuErrorView(error.userMessage) { retry() }            // 直接传入 GxuError.userMessage
GxuStaleBanner(updatedAt: date, message: "网络不可用")  // 刷新失败时贴在页面顶部，不阻断浏览
```

所有数据页保持一致的行为：先展示本地缓存，再在后台静默刷新；支持下拉刷新；离线或刷新失败时留住原有缓存，并用 `GxuStaleBanner` 提示最后更新时间，只有完全没有缓存时才整页显示 `GxuErrorView`。

### 布局常量

`GxuDesign.Spacing.{xs,s,m,l,xl}`、`GxuDesign.Radius.{block,card}`。

## 自查清单

- [ ] 浅色和深色模式都截图核对过
- [ ] 没有绕开封装直接写 `.glassEffect`、`.buttonStyle(.glass)` 或给系统导航栏强行设背景色
- [ ] 可点击热区不小于 44pt，纯图标按钮都补齐了 `accessibilityLabel`
- [ ] 文本全部使用系统字体样式，没有硬编码字号（定高网格内可用 `.dynamicTypeSize(...xLarge)` 限制上限）

## 页面排版与文案规范

1. **两条左对齐参考线**（`GxuDesign.Layout`）：**A 线**（`pageMargin`，卡片外边缘）对齐页面大标题、日期行以及卡片和色带的左边缘；**B 线**（`A + cardInset`）对齐分组标题和卡片内部的文字与图标。系统 `List` 与 `Form` 默认满足，自拼页面使用 `Layout` 常量、`ContentCard` 和 `.gxuSectionHeader()`，不要写死边距数值。
2. **不要把列表行的左右内边距设成 0**：否则文字贴着圆角边缘会被裁切（此前首页日期行踩过这个坑）。需要贴近 A 线的文字请放在分组标题里。
3. **同一张卡片或同一行内不重复表达同一信息**：右侧已经标出具体时刻（例如「明天 09:00」），左侧就不再写时间；已有「今天放假」提示时，不再同时显示「今天没有课」。
4. **座位号格式**：纯数字显示「8 号」，其余格式显示「座位 A12」，空值不显示，统一调用 `Exam.seatText`。
5. **课程块样式**：用纯色底，不加左侧竖线（首页「今日课程」和小组件保留竖线）；课程名用 `.caption`，教室和教师用小一号的 `.caption2`；深色模式通过 `CourseTint` 使用提亮饱和度的暗色底。
6. **课表时间列**：每节同时列出上下课时间；第 9、10 节在显示层合并成「9-10」一行（由 `PeriodRows` 负责，共 12 行），`ClassPeriods` 底层的 13 节数据与计算逻辑保持不变。同一时段重叠的课程并排分栏展示。
7. **日历叠色**：全天色带（如假期）上不再叠加「今天」整列的底色，只保留表头日期的高亮。
8. **带下拉箭头的标题**：箭头用 overlay 布局，保证标题文字与下方日期范围沿同一条中轴线居中。
9. **精简提示文案**：去掉没有实际信息的学年、学期套话。
10. **二级页面收起底栏**：从工具箱点进去的二级页面统一加上 `.gxuHidesTabChrome()`，隐藏标签栏和底部附件。
