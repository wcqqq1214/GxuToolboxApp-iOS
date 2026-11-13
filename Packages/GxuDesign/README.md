# GxuDesign

设计系统：主题、玻璃封装、内容卡片、状态视图、课程配色。**所有 feature 的界面都要通过它来写**，这样 iOS 26 的 Liquid Glass 和 iOS 18 的降级只在这一个包里处理。

最低系统 iOS 18。iOS 26 才有的 API（`glassEffect`、`GlassEffectContainer`、`glassEffectID`、`tabBarMinimizeBehavior`、`tabViewBottomAccessory`）只出现在 `Glass.swift`，用 `#available(iOS 26, *)` 包装，iOS 18 降级为 Material。

## 界面设计

1. **玻璃只用在导航层和浮动控件上**：标签栏、工具栏、浮动按钮、sheet、底部附件。课程块、成绩列表、卡片正文**不用玻璃**。
2. **玻璃上不要再叠玻璃。** 相邻的玻璃控件放进同一个 `GlassGroup`，让它们能合并、变形。
3. 系统的 `TabView`、`NavigationStack` 工具栏、`.sheet` 自动是玻璃，**不要**给它们设背景色或 `toolbarBackground`。
4. feature 里**禁止直接写** `.glassEffect`、`.buttonStyle(.glass)`、`GlassEffectContainer`，只能用本包的封装。
5. 主题色只作强调色（`tint`）；图标只用 SF Symbols；文字用系统字体样式（`.headline`、`.body` …），不要写死字号，以支持 Dynamic Type。

RN 用于对照功能、数据和边界行为，界面按 iOS 的交互习惯设计。优先用系统控件：`List`、`Form`、`Picker`、`Menu`、`.sheet` + detents、`.contextMenu`、`.swipeActions`、`.refreshable`、`.searchable`。

## 用法

### 主题

```swift
@State private var theme = GxuTheme()          // 根视图里创建一次（App/Shell/RootView 已经做了）
RootView().gxuTheme(theme)                     // 下发强调色、外观模式

@Environment(GxuTheme.self) private var theme  // 读取 / 修改：theme.accentHex = 0xE5484D
```

在视图里要用强调色，写 `Color.accentColor` 或 `.tint`，不要用 `theme.accent` 去给背景大面积着色。

课表和工具箱的根页用 `.gxuPageBackground(inNavigation: true)`，让页面底色和自定义背景图延伸到导航栏后方。

### 玻璃

```swift
// 浮动控件（相邻的放进一个 GlassGroup，共用 @Namespace 才能变形）
@Namespace private var ns
GlassGroup {
    HStack {
        GlassButton(systemImage: "chevron.left", accessibilityLabel: "上一周") { … }
            .gxuGlassID("prev", in: ns)
        if away { GlassButton("本周", systemImage: "arrow.uturn.backward", prominent: true) { … }
            .gxuGlassID("today", in: ns) }
    }
}

// 自定义的浮动面板
Text("…").padding().gxuGlass(in: RoundedRectangle(cornerRadius: 20))

// 标签栏
TabView { … }.gxuTabBarFixed()                        // 系统标签栏，iOS 26 保留液态玻璃且不随滚动收起
TabView { … }.gxuTabAccessory { NextCourseBar() }     // 标签栏上方的附件，iOS 18 降级为底部材质条
SomeTabContent.gxuAccessoryInset()                    // iOS 18 降级时为附件留出底部空间
DetailView().gxuHidesTabChrome()
```

`GlassButton` 无标题时是 44pt 圆形图标按钮，必须传 `accessibilityLabel`。

### 内容

```swift
ContentCard { VStack(alignment: .leading) { … } }      // 纯色圆角卡片，不是玻璃
CourseTint(hex: 0xB5EAD7).fill / .text / .marker       // 课程块配色，浅 / 深色各自校准，文字对比度 ≥ 4.5:1
```

课程基色来自 ScheduleKit 的 `CoursePalette`；不要自己再调透明度。

### 状态视图

```swift
GxuLoadingView("加载中…")
GxuEmptyView("没有考试", systemImage: "calendar", message: "…", actionTitle: "去登录") { … }
GxuErrorView(error.userMessage) { retry() }            // message 直接传 GxuError.userMessage
GxuStaleBanner(updatedAt: date, message: "网络不可用")  // 刷新失败时贴在内容上方，非阻塞
```

数据页的统一约定：**先显示本地缓存，再后台刷新；下拉刷新；离线或刷新失败时保留缓存，用 `GxuStaleBanner` 标注最后更新时间**。只有完全没有缓存时才整页显示 `GxuErrorView`。

### 常量

`GxuDesign.Spacing.{xs,s,m,l,xl}`、`GxuDesign.Radius.{block,card}`。

## 自查清单

- [ ] 浅色、深色模式都截图看过
- [ ] 没有直接写 `.glassEffect` / `.buttonStyle(.glass)` / 背景色覆盖系统导航层
- [ ] 点击热区 ≥ 44pt，图标按钮有 `accessibilityLabel`
- [ ] 文字用系统样式，没有写死字号（定高网格内可用 `.dynamicTypeSize(...xLarge)` 限制）

## 页面对齐与文字规则（用户审查后的硬性规则，以后的页面不要再自己判断）

1. **两条左对齐线**（`GxuDesign.Layout`）：**A 线**（`pageMargin`，卡片边）= 大标题、日期行、卡片 / 色带的左边缘；**B 线**（A + `cardInset`）= 分组标题、卡片里的文字和图标。系统 `List` / `Form` 自动遵守；自拼页面用 `Layout` 常量、`ContentCard` 和 `.gxuSectionHeader()`，不要写死边距数字。
2. **不要把列表行的左右内边距设成 0**：文字贴着行容器的圆角边缘，第一个字会被裁掉（首页日期行的 bug）。需要贴 A 线的文字放进分组标题里。
3. **同一张卡片 / 同一行里，同一个信息只出现一次。** 右边已经写了具体时刻（“明天 09:00”），左边就不再写时间；已有“今天放假”提示就不再显示“今天没有课”。
4. **座位号**：纯数字写“8 号”，其他写“座位 A12”，没有就不显示——统一用 `Exam.seatText`。
5. **课程块**：纯底色，**不加竖线**（首页“今日课程”和小组件的竖线保留）；课程名用 `.caption`，教室 / 教师用 `.caption2`（比课程名小一号）；深色模式用提高饱和度的暗色底（`CourseTint`）。
6. **课表时间列**：每节同时显示上课和下课时间；第 9、10 节在显示层合并成一行“9-10”（`PeriodRows`，共 12 行），`ClassPeriods` 的 13 节数据和计算逻辑不变。同行里重叠的课并排分栏显示。
7. **叠色**：整天色带（假期）上不再叠“今天”列的底色，只保留表头日期的高亮。
8. **标题**：带下拉箭头的标题，箭头用 overlay，文字和下面的日期范围保持在同一条中轴线上。
9. **页面文案**：省略没有额外信息的学年学期说明。
10. **二级页面**（工具箱里点进去的页面）隐藏标签栏和底部附件：`.gxuHidesTabChrome()`。
