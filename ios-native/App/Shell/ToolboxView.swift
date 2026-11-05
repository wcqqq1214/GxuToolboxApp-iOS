import GxuDesign
import SwiftUI

/// 工具箱：功能网格。已上线的功能可以进入，其余标“即将上线”。
struct ToolboxView: View {
    @State private var query = ""

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
                            VStack(alignment: .leading, spacing: GxuDesign.Spacing.m) {
                                Text(section.rawValue)
                                    .font(.title3.weight(.semibold))
                                    .accessibilityAddTraits(.isHeader)
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: GxuDesign.Spacing.m)], spacing: GxuDesign.Spacing.m) {
                                    ForEach(items) { ToolboxCell(item: $0) }
                                }
                            }
                        }
                    }
                    if filtered.isEmpty {
                        ContentUnavailableView.search(text: query)
                    }
                }
                .padding(.horizontal, GxuDesign.Spacing.l)
                .padding(.vertical, GxuDesign.Spacing.s)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("工具箱")
            .searchable(text: $query, prompt: "搜索功能")
        }
    }
}

private struct ToolboxCell: View {
    let item: ToolboxItem

    var body: some View {
        if let destination = item.destination {
            NavigationLink { destination().navigationTitle(item.title) } label: { cell }
                .buttonStyle(.plain)
        } else {
            cell
                .accessibilityElement(children: .combine)
                .accessibilityHint("即将上线")
        }
    }

    private var cell: some View {
        HStack(spacing: GxuDesign.Spacing.m) {
            Image(systemName: item.systemImage)
                .font(.title3)
                .foregroundStyle(item.isAvailable ? Color.accentColor : Color.secondary)
                .frame(width: 40, height: 40)
                .background(
                    (item.isAvailable ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.10)),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.subheadline.weight(.medium)).lineLimit(1)
                if !item.isAvailable {
                    Text("即将上线").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(GxuDesign.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: GxuDesign.Radius.card, style: .continuous)
        )
        .opacity(item.isAvailable ? 1 : 0.7)
        .contentShape(RoundedRectangle(cornerRadius: GxuDesign.Radius.card, style: .continuous))
    }
}
