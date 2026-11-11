import GxuAuth
import GxuDesign
import GxuFoundation
import Observation
import SwiftUI

@MainActor @Observable
final class EvaluationTemplatesModel {
    private(set) var templates: [EvaluationTemplate] = []
    private(set) var error: GxuError?
    private let repo: EvaluationTemplateRepository
    private let services: AppServices

    init(services: AppServices) {
        self.services = services
        repo = EvaluationTemplateRepository(database: services.database)
    }

    private var studentId: String? { services.accounts.studentId }

    func load() async {
        guard let studentId else { return }
        templates = (try? await repo.list(studentId: studentId)) ?? []
    }

    func save(_ template: EvaluationTemplate) async -> String? {
        guard let studentId else { return GxuError.notLoggedIn(.jw).userMessage }
        do {
            try await repo.save(template, studentId: studentId)
            await load()
            return nil
        } catch {
            return ((error as? GxuError) ?? .network(error.localizedDescription)).userMessage
        }
    }

    func delete(_ template: EvaluationTemplate) async {
        guard let studentId, let id = template.id else { return }
        try? await repo.delete(id: id, studentId: studentId)
        await load()
    }
}

public struct EvaluationTemplatesView: View {
    @Environment(\.services) private var services

    public init() {}

    public var body: some View { Content(services: services) }

    private struct Content: View {
        @State private var model: EvaluationTemplatesModel
        @State private var editing: EvaluationTemplate?

        init(services: AppServices) { _model = State(initialValue: EvaluationTemplatesModel(services: services)) }

        var body: some View {
            List {
                if model.templates.isEmpty {
                    GxuEmptyView("还没有评教模板", systemImage: "doc.text", message: "模板记录每道题的等级和评语，评教时可以直接套用。")
                        .listRowBackground(Color.clear)
                }
                ForEach(model.templates) { template in
                    Button { editing = template } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.name).font(.headline).foregroundStyle(.primary)
                            Text(summary(template)).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions { Button("删除", role: .destructive) { Task { await model.delete(template) } } }
                }
            }
            .navigationTitle("评教模板")
            .navigationBarTitleDisplayMode(.inline)
            .gxuHidesTabChrome()
            .toolbar { Button("新建模板", systemImage: "plus") { editing = EvaluationTemplate(name: "") } }
            .sheet(item: $editing) { template in
                TemplateEditor(template: template) { await model.save($0) }
            }
            .task { await model.load() }
        }

        private func summary(_ t: EvaluationTemplate) -> String {
            let counts = Dictionary(grouping: t.answers, by: { $0 }).mapValues(\.count)
            return counts.keys.sorted().map { "\(EvaluationQuestions.levels[$0]) \(counts[$0] ?? 0)" }.joined(separator: " · ")
        }
    }
}

private struct TemplateEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var template: EvaluationTemplate
    let onSave: (EvaluationTemplate) async -> String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("名称") { TextField("例如：全部满意", text: $template.name) }
                Section {
                    Picker("全部设为", selection: Binding(get: { -1 }, set: { level in
                        if level >= 0 { template.answers = Array(repeating: level, count: template.answers.count) }
                    })) {
                        Text("选择等级").tag(-1)
                        ForEach(EvaluationQuestions.levels.indices, id: \.self) { Text(EvaluationQuestions.levels[$0]).tag($0) }
                    }
                }
                ForEach(Array(sections.enumerated()), id: \.offset) { index, range in
                    Section("第 \(index + 1) 类") {
                        ForEach(range, id: \.self) { question in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(EvaluationQuestions.items[question]).font(.subheadline)
                                Picker("等级", selection: $template.answers[question]) {
                                    ForEach(EvaluationQuestions.levels.indices, id: \.self) { Text(EvaluationQuestions.levels[$0]).tag($0) }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                    }
                }
                Section("评语") { TextField("评语", text: $template.comment, axis: .vertical).lineLimit(3...8) }
                if let errorMessage { Section { Text(errorMessage).foregroundStyle(.red) } }
            }
            .navigationTitle(template.id == nil ? "新建模板" : "编辑模板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            if let message = await onSave(template) { errorMessage = message } else { dismiss() }
                        }
                    }
                }
            }
        }
    }

    private var sections: [Range<Int>] {
        var start = 0
        return EvaluationQuestions.categorySizes.map { size in
            defer { start += size }
            return start..<(start + size)
        }
    }
}
