import GxuDesign
import SwiftUI

/// 工具箱：功能网格。已上线的功能可以进入，其余标“即将上线”。
struct ToolboxView: View {
    /// 切换标签页（“课表”入口用）
    let onSelectTab: (AppTab) -> Void
    @State private var query = ""
    #if DEBUG
    /// 截图自查：`-GxuOpen <工具箱项 id>` 直接打开对应页面
    @State private var debugOpen = ToolboxView.debugItem != nil
    private static var debugItem: ToolboxItem? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-GxuOpen"), i + 1 < args.count else { return nil }
        return ToolboxCatalog.items.first { $0.id == args[i + 1] && $0.isAvailable }
    }
    #endif

    private var filtered: [ToolboxItem] {
        query.isEmpty ? ToolboxCatalog.items : ToolboxCatalog.items.filter { $0.title.localizedStandardContains(query) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: GxuDesign.Spacing.xl, pinnedViews: []) {
                    ForEach(ToolboxItem.Section.allCases) { section in
                        let items = filtered.filter { $0.section == section }
                        if !items.isEmpty {
                            VStack(alignment: .leading, spacing: GxuDesign.Spacing.s) {
                                // 分组标题在 B 线，卡片在 A 线，卡片里的图标也在 B 线
                                Text(section.rawValue).gxuSectionHeader()
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: GxuDesign.Spacing.m)], spacing: GxuDesign.Spacing.m) {
                                    ForEach(items) { ToolboxCell(item: $0, onSelectTab: onSelectTab) }
                                }
                            }
                        }
                    }
                    if filtered.isEmpty {
                        ContentUnavailableView.search(text: query)
                    }
                }
                .padding(.horizontal, GxuDesign.Layout.pageMargin)
                .padding(.vertical, GxuDesign.Spacing.s)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("工具箱")
            .searchable(text: $query, prompt: "搜索功能")
            #if DEBUG
            .navigationDestination(isPresented: $debugOpen) {
                if let item = Self.debugItem, let view = item.pushedView { view.navigationTitle(item.title).gxuHidesTabChrome() }
            }
            #endif
        }
    }
}

private struct ToolboxCell: View {
    let item: ToolboxItem
    let onSelectTab: (AppTab) -> Void

    var body: some View {
        switch item.action {
        case .push(let destination):
            NavigationLink { destination().navigationTitle(item.title).gxuHidesTabChrome() } label: { cell }
                .buttonStyle(.plain)
        case .tab(let tab):
            Button { onSelectTab(tab) } label: { cell }
                .buttonStyle(.plain)
        case nil:
            cell
                .accessibilityElement(children: .combine)
                .accessibilityHint("即将上线")
        }
    }

    private var cell: some View {
        HStack(spacing: GxuDesign.Spacing.m) {
            Image(systemName: item.systemImage)
                .accessibilityHidden(true)
                .font(.title3)
                .foregroundStyle(item.isAvailable ? Color.accentColor : Color.secondary)
                .frame(width: 40, height: 40)
                .background(
                    (item.isAvailable ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.10)),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.subheadline.weight(.medium)).lineLimit(2)
                if !item.isAvailable {
                    Text("即将上线").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, GxuDesign.Spacing.m)
        .padding(.horizontal, GxuDesign.Layout.cardInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: GxuDesign.Radius.card, style: .continuous)
        )
        .opacity(item.isAvailable ? 1 : 0.7)
        .contentShape(RoundedRectangle(cornerRadius: GxuDesign.Radius.card, style: .continuous))
    }
}
