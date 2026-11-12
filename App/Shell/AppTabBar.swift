import GxuDesign
import SwiftUI

enum AppTab: String, CaseIterable, Hashable {
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

struct AppTabChrome: ViewModifier {
    @Binding var selection: AppTab
    let showsEvent: Bool
    let home: HomeModel

    func body(content: Content) -> some View {
        content.gxuBottomChrome {
            HStack(spacing: 0) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    Button {
                        var transaction = Transaction(animation: nil)
                        transaction.disablesAnimations = true
                        withTransaction(transaction) { selection = tab }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.systemImage).font(.title3)
                            Text(tab.title).font(.caption2)
                        }
                        .foregroundStyle(selection == tab ? Color.accentColor : .secondary)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.title)
                    .accessibilityAddTraits(selection == tab ? .isSelected : [])
                    .accessibilityIdentifier("tab-\(tab.rawValue)")
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("app-tab-bar")
        } accessory: {
            if showsEvent {
                NextEventAccessory(model: home).padding(.vertical, GxuDesign.Spacing.s)
            }
        }
    }
}
