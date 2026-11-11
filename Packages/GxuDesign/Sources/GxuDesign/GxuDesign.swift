import SwiftUI

public enum GxuDesign {
    public static let useModernGlass: Bool = {
        #if DEBUG
        if CommandLine.arguments.contains("-GxuForceLegacy") { return false }
        #endif
        if #available(iOS 26, *) { return true }
        return false
    }()

    public enum Radius {
        public static let block: CGFloat = 8
        public static let card: CGFloat = 16
    }

    public enum Layout {
        public static let pageMargin: CGFloat = 16
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
