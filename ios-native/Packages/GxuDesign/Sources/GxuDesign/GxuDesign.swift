import SwiftUI

/// 设计系统入口：间距、圆角等常量。用法和规则见 `Packages/GxuDesign/README.md`。
public enum GxuDesign {
    /// 是否使用 iOS 26 的玻璃 API。系统低于 iOS 26 时恒为 false；
    /// DEBUG 构建可加启动参数 `-GxuForceLegacy`，在 iOS 26+ 的模拟器上强制走 iOS 18 的降级路径（Material），方便对比。
    /// 只影响 GxuDesign 自己的封装（`GlassGroup`、`GlassButton`、`.gxuGlass()`、标签栏附件等）；
    /// 系统控件（TabView、sheet、工具栏）在 iOS 26 上始终是系统玻璃，无法强制降级。
    public static let useModernGlass: Bool = {
        #if DEBUG
        if CommandLine.arguments.contains("-GxuForceLegacy") { return false }
        #endif
        if #available(iOS 26, *) { return true }
        return false
    }()

    public enum Radius {
        /// 课程块等小型内容块
        public static let block: CGFloat = 8
        /// 卡片
        public static let card: CGFloat = 16
    }

    /// 页面水平对齐规则（所有页面共用，不要自己写边距数字）。两条线：
    /// - **A 线（卡片边）**：大标题、卡片 / 色带 / 整行背景的左边缘，距屏幕 `pageMargin`；
    /// - **B 线（内容边）**：分组标题、日期行、卡片里的文字和图标的左边缘 = A 线 + `cardInset`。
    /// 系统 `List` / `Form` 自动遵守这两条线；自己用 `ScrollView` + `VStack` 拼的页面要用下面的常量或 `gxuSectionHeader()` / `ContentCard`。
    public enum Layout {
        /// A 线：页面左右边距，和系统 insetGrouped 列表的卡片边一致
        public static let pageMargin: CGFloat = 16
        /// A 线到 B 线的距离：系统列表行的内边距（iOS 26 是 20，更早的系统是 16）
        public static var cardInset: CGFloat {
            if #available(iOS 26, *) { return 20 }
            return 16
        }
    }

    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
        public static let xl: CGFloat = 24
    }
}
