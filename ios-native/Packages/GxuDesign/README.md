# GxuDesign

设计系统：主题、玻璃封装、内容卡片、状态视图、课程配色。**所有 feature 的界面都要通过它来写**，这样 iOS 26 的 Liquid Glass 和 iOS 18 的降级只在这一个包里处理。

最低系统 iOS 18。iOS 26 才有的 API（`glassEffect`、`GlassEffectContainer`、`glassEffectID`、`tabBarMinimizeBehavior`、`tabViewBottomAccessory`）只出现在 `Glass.swift`，用 `#available(iOS 26, *)` 包装，iOS 18 降级为 Material。

## 五条规则（PLAN §6）

1. **玻璃只用在导航层和浮动控件上**：标签栏、工具栏、浮动按钮、sheet、底部附件。课程块、成绩列表、卡片正文**不用玻璃**。
2. **玻璃上不要再叠玻璃。** 相邻的玻璃控件放进同一个 `GlassGroup`，让它们能合并、变形。
3. 系统的 `TabView`、`NavigationStack` 工具栏、`.sheet` 自动是玻璃，**不要**给它们设背景色或 `toolbarBackground`。
4. feature 里**禁止直接写** `.glassEffect`、`.buttonStyle(.glass)`、`GlassEffectContainer`，只能用本包的封装。
5. 主题色只作强调色（`tint`）；图标只用 SF Symbols；文字用系统字体样式（`.headline`、`.body` …），不要写死字号，以支持 Dynamic Type。

优先用系统控件：`List`、`Form`、`Picker`、`Menu`、`.sheet` + detents、`.contextMenu`、`.swipeActions`、`.refreshable`、`.searchable`。

## 用法

### 主题

```swift
@State private var theme = GxuTheme()          // 根视图里创建一次（App/Shell/RootView 已经做了）
RootView().gxuTheme(theme)                     // 下发强调色、外观模式

@Environment(GxuTheme.self) private var theme  // 读取 / 修改：theme.accentHex = 0xE5484D
```

在视图里要用强调色，写 `Color.accentColor` 或 `.tint`，不要用 `theme.accent` 去给背景大面积着色。

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
TabView { … }.gxuTabBarMinimizeOnScroll()             // 随滚动收起（iOS 26）
SomeTabContent.gxuTabAccessory { NextCourseBar() }    // 标签栏上方的常驻附件，iOS 18 降级为底部材质条
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
