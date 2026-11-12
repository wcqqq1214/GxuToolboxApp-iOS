import SwiftUI

enum AppTab: Hashable {
    case home, schedule, toolbox, settings

    var showsNextEventAccessory: Bool { self == .schedule }

    var title: String {
        switch self {
        case .home: "今天"
        case .schedule: "课表"
        case .toolbox: "工具箱"
        case .settings: "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "sun.horizon"
        case .schedule: "calendar"
        case .toolbox: "square.grid.2x2"
        case .settings: "gearshape"
        }
    }
}
