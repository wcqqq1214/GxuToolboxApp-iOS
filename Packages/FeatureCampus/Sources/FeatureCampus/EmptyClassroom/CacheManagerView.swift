import GxuAuth
import GxuDesign
import GxuFoundation
import SwiftUI

struct CacheManagerView: View {
    @Bindable var model: EmptyClassroomModel
    let cache: EmptyClassroomCacheController
    @Environment(\.services) private var services
    @State private var confirmClear: ClearKind?
    @State private var usage: (rooms: Int, availability: Int) = (0, 0)

    enum ClearKind: Identifiable { case weeks, all; var id: Self { self } }

    var body: some View {
        List {
            progressSection
            Section {
                if model.context.terms.count > 1 {
                    Picker("学期", selection: Binding(get: { model.term ?? model.context.terms[0] }, set: { term in Task { await model.select(term: term) } })) {
                        ForEach(model.context.terms, id: \.self) { Text($0.displayName).tag($0) }
                    }
                }
            } footer: {
                Text("缓存会占用本机存储：\(Self.sizeText(usage.rooms + usage.availability))（教室 \(Self.sizeText(usage.rooms))，空闲时段 \(Self.sizeText(usage.availability))）。")
            }
            Section("教学周") {
                ForEach(1...EmptyClassroomConstants.maxWeeks, id: \.self) { week in
                    WeekCacheRow(model: model, cache: cache, week: week, start: { start(week) })
                        .swipeActions {
                            if model.snapshot(week: week) != nil {
                                Button("删除", role: .destructive) { Task { try? await model.repository?.deleteWeek(year: model.year, term: model.logicalTerm, week: week); await model.cacheChanged(); await loadUsage() } }
                            }
                        }
                }
            }
            if let error = failure { Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) } }
        }
        .navigationTitle("缓存管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("清空所有周的缓存", systemImage: "trash", role: .destructive) { confirmClear = .weeks }
                    Button("清空全部（含教室列表）", systemImage: "trash.slash", role: .destructive) { confirmClear = .all }
                } label: { Image(systemName: "ellipsis.circle") }
                .disabled(cache.isRunning)
                .accessibilityLabel("清理缓存")
            }
        }
        .confirmationDialog("确定清空缓存吗？", isPresented: Binding(get: { confirmClear != nil }, set: { if !$0 { confirmClear = nil } }), titleVisibility: .visible) {
            Button("清空", role: .destructive) {
                let kind = confirmClear
                Task {
                    if kind == .all { try? await model.repository?.clearAll() } else { try? await model.repository?.clearWeeks() }
                    await model.cacheChanged()
                    await loadUsage()
                }
            }
        } message: { Text(confirmClear == .all ? "已缓存的空闲时段和教室列表都会删除，需要重新缓存才能查询。" : "已缓存的空闲时段会删除，教室列表保留。") }
        .task { await loadUsage() }
        .onChange(of: model.cacheRevision) { Task { await loadUsage() } }
    }

    private var failure: String? { if case .failed(let message) = cache.state { message } else { nil } }

    @ViewBuilder
    private var progressSection: some View {
        switch cache.state {
        case .running(let week, let day, let period):
            Section {
                VStack(alignment: .leading, spacing: GxuDesign.Spacing.s) {
                    Text("正在缓存第 \(week) 周").font(.headline)
                    ProgressView(value: Double(cache.completedDays.count) + Double(period) / Double(EmptyClassroomConstants.periods), total: Double(EmptyClassroomConstants.days))
                    Text("第 \(min(day, 7))/7 天 · 第 \(period)/13 节 · 已完成 \(cache.completedDays.count) 天").font(.footnote).foregroundStyle(.secondary)
                    Button("取消", role: .destructive) { cache.cancel() }.buttonStyle(.borderless)
                }
            } footer: { Text("取消后，已经缓存完的天会保留，下次继续。") }
        case .finished(let week, let complete, let canceled):
            Section { Label(complete ? "第 \(week) 周缓存完成" : canceled ? "第 \(week) 周缓存已取消，已缓存的天会保留" : "第 \(week) 周没有缓存完整", systemImage: complete ? "checkmark.circle" : "pause.circle").foregroundStyle(complete ? .green : .secondary) }
        default:
            EmptyView()
        }
    }

    private func start(_ week: Int) {
        guard let term = model.term else { return }
        cache.start(week: week, term: term, services: services, model: model)
    }

    private func loadUsage() async {
        guard let usage = try? await model.repository?.storageUsage() else { return }
        self.usage = (usage.roomsBytes, usage.availabilityBytes)
    }

    static func sizeText(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

private struct WeekCacheRow: View {
    @Bindable var model: EmptyClassroomModel
    let cache: EmptyClassroomCacheController
    let week: Int
    let start: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let cooldown = cache.remainingCooldown(now: context.date)
            let snapshot = model.snapshot(week: week)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("第 \(week) 周").font(.body.weight(.medium))
                    Text(status(snapshot)).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                if cache.isRunning, case .running(let running, _, _) = cache.state, running == week {
                    ProgressView()
                } else {
                    Button(snapshot?.complete == true ? "更新" : snapshot == nil ? "缓存" : "继续") { start() }
                        .buttonStyle(.bordered)
                        .disabled(cache.isRunning || cooldown > 0)
                        .accessibilityHint(cooldown > 0 ? "冷却中，还需 \(Int(cooldown.rounded(.up))) 秒" : "")
                }
            }
            if cooldown > 0, week == 1 {
                Text("为减轻教务系统压力，两次缓存之间需间隔 \(Int(EmptyClassroomConstants.cooldown)) 秒，还需 \(Int(cooldown.rounded(.up))) 秒。").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func status(_ snapshot: WeekSnapshot?) -> String {
        guard let snapshot else { return "未缓存" }
        let when = snapshot.fetchedAt.formatted(.dateTime.month().day().hour().minute().locale(Locale(identifier: "zh_CN")))
        return snapshot.complete ? "已缓存 · \(snapshot.roomCount) 间教室 · \(when)" : "已缓存 \(snapshot.completedDays)/7 天 · \(when)"
    }
}
