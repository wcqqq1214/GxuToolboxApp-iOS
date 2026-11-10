import GxuAuth
import GxuDesign
import GxuFoundation
import Observation
import SwiftUI

/// 评教总览：列出每门课的评教状态。详情、评语、提交需要直连教务（后端没有代理），暂不接入。
@MainActor @Observable
final class EvaluationOverviewModel {
    private(set) var tasks: [EvaluationTask] = []
    private(set) var isLoading = false
    private(set) var error: GxuError?
    private(set) var loaded = false
    private let services: AppServices

    init(services: AppServices) { self.services = services }

    var summary: EvaluationSummary { EvaluationSummary(tasks) }

    func load() async {
        guard services.accounts.studentId != nil else { error = .notLoggedIn(.jw); return }
        error = nil
        isLoading = true
        defer { isLoading = false }
        do {
            tasks = EvaluationSummary.sorted(try await EvaluationAPI(backend: services.backend).tasks())
            loaded = true
        } catch is CancellationError {
        } catch {
            self.error = (error as? GxuError) ?? .network(error.localizedDescription)
        }
    }
}

public struct EvaluationOverviewView: View {
    @Environment(\.services) private var services

    public init() {}

    public var body: some View { Content(services: services) }

    private struct Content: View {
        @State private var model: EvaluationOverviewModel

        init(services: AppServices) { _model = State(initialValue: EvaluationOverviewModel(services: services)) }

        var body: some View {
            List {
                if let error = model.error {
                    if model.tasks.isEmpty {
                        GxuErrorView(EvaluationAPI.message(for: error)) { Task { await model.load() } }.listRowBackground(Color.clear)
                    } else {
                        GxuStaleBanner(updatedAt: nil, message: EvaluationAPI.message(for: error)).listRowBackground(Color.clear)
                    }
                }
                if model.tasks.isEmpty {
                    if model.isLoading {
                        GxuLoadingView("正在查询评教任务…").frame(minHeight: 240).listRowBackground(Color.clear)
                    } else if model.error == nil, model.loaded {
                        GxuEmptyView("目前没有评教任务", systemImage: "text.bubble", message: "评教开放期间这里会列出每门课的评教状态。")
                            .listRowBackground(Color.clear)
                    }
                } else {
                    Section { SummaryRow(summary: model.summary) } header: { Text("共 \(model.summary.total) 门") }
                    Section {
                        ForEach(model.tasks) { TaskRow(task: $0) }
                    }
                }
                Section {
                    NavigationLink { EvaluationTemplatesView() } label: { Label("评教模板", systemImage: "doc.text") }
                } footer: {
                    Text("请在教务系统填写并提交评教。")
                }
            }
            .navigationTitle("期末评教")
            .navigationBarTitleDisplayMode(.inline)
            .gxuHidesTabChrome()
            .task { await model.load() }
            .refreshable { await model.load() }
        }
    }
}

private struct SummaryRow: View {
    let summary: EvaluationSummary

    var body: some View {
        HStack {
            stat("未评", summary.pending, .red)
            stat("未评完", summary.partial, .orange)
            stat("已评完", summary.done, .green)
        }
    }

    private func stat(_ title: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.title3.bold()).foregroundStyle(color)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TaskRow: View {
    let task: EvaluationTask

    private var tint: Color {
        switch task.status {
        case .pending: .red
        case .partial: .orange
        case .done: .green
        case .other: .secondary
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(task.courseName).font(.headline)
                Text([task.teacherName, task.courseTypeName].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Text(task.submitStatus).font(.subheadline).foregroundStyle(tint)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
