import SwiftUI

/// 设计系统入口：间距、圆角等常量。用法和规则见 `Packages/GxuDesign/README.md`。
public enum GxuDesign {
    public enum Radius {
        /// 课程块等小型内容块
        public static let block: CGFloat = 8
        /// 卡片
        public static let card: CGFloat = 16
    }

    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
        public static let xl: CGFloat = 24
    }
}
