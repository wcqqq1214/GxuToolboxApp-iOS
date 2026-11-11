import GxuAuth
import GxuDesign
import SwiftUI

public enum FeedbackFeatures {
    public static var showsMyFeedback: Bool {
        UserDefaults.standard.object(forKey: "feature.showsMyFeedback") as? Bool ?? false
    }
}

public struct FeedbackView: View {
    @Environment(\.services) private var services
    public init() {}
    public var body: some View { Content(model: FeedbackFormModel(services: services)) }

    private struct Content: View {
        @State var model: FeedbackFormModel
        @State private var showsSuccess = false

        var body: some View {
            Form {
                Section("类别") {
                    Picker("反馈类型", selection: $model.draft.type) {
                        Text("请选择").tag("")
                        ForEach(FeedbackOptions.types, id: \.value) { Text($0.label).tag($0.value) }
                    }
                    Picker("问题模块", selection: $model.draft.feature) {
                        Text("请选择").tag("")
                        ForEach(FeedbackOptions.features, id: \.value) { Text($0.label).tag($0.value) }
                    }
                }
                Section {
                    TextEditor(text: $model.draft.content)
                        .frame(minHeight: 140)
                } header: {
                    Text("反馈内容")
                } footer: {
                    Text("至少 \(FeedbackOptions.minContentLength) 个字，请尽量描述清楚遇到的问题或建议。")
                }
                Section {
                    Picker("联系方式", selection: $model.draft.contactType) {
                        Text("请选择").tag("")
                        ForEach(FeedbackOptions.contactTypes, id: \.value) { Text($0.label).tag($0.value) }
                    }
                    TextField("QQ号 / 微信号 / 邮箱", text: $model.draft.contact)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("联系方式")
                } footer: {
                    if let message = model.errorMessage { Text(message).foregroundStyle(.red) }
                }
                Section {
                    Button {
                        Task { await model.submit() }
                    } label: {
                        HStack {
                            Text("提交")
                            if model.isSubmitting { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(!model.canSubmit)
                }
            }
            .navigationTitle("意见反馈")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if FeedbackFeatures.showsMyFeedback {
                    NavigationLink("我的反馈") { FeedbackListView() }
                }
            }
            .onChange(of: model.submittedID) { _, id in showsSuccess = id != nil }
            .alert("提交成功", isPresented: $showsSuccess) {
                Button("好") { model.submittedID = nil }
            } message: {
                Text("感谢反馈，可以在「我的反馈」里查看回复。")
            }
        }
    }
}

public struct FeedbackListView: View {
    @Environment(\.services) private var services
    public init() {}
    public var body: some View { Content(model: FeedbackListModel(services: services)) }

    private struct Content: View {
        @State var model: FeedbackListModel

        var body: some View {
            List {
                ForEach(model.items) { item in
                    NavigationLink { FeedbackDetailView(item: item) } label: { Row(item: item) }
                        .task { await model.loadMoreIfNeeded(current: item) }
                }
                if model.isLoading && !model.items.isEmpty {
                    HStack { Spacer(); ProgressView(); Spacer() }.listRowBackground(Color.clear)
                }
            }
            .overlay {
                if model.items.isEmpty {
                    if model.isLoading {
                        GxuLoadingView("正在加载…")
                    } else if let error = model.error {
                        GxuErrorView(error.userMessage) { Task { await model.reload() } }
                    } else {
                        GxuEmptyView("还没有反馈", systemImage: "bubble.left.and.text.bubble.right")
                    }
                }
            }
            .navigationTitle("我的反馈")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await model.reload() }
            .task { await model.reload() }
        }
    }

    private struct Row: View {
        let item: FeedbackItem
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.isReplied ? "已回复" : "待回复")
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(item.isReplied ? Color.green.opacity(0.18) : Color.orange.opacity(0.18), in: Capsule())
                        .foregroundStyle(item.isReplied ? Color.green : Color.orange)
                    Text("\(FeedbackOptions.typeLabel(item.type)) · \(FeedbackOptions.featureLabel(item.feature))")
                        .font(.footnote).foregroundStyle(.secondary)
                    Spacer()
                    if let date = item.createdDate { Text(date, format: .dateTime.month().day()).font(.footnote).foregroundStyle(.secondary) }
                }
                Text(item.content).lineLimit(2)
            }
            .padding(.vertical, 2)
        }
    }
}

public struct FeedbackDetailView: View {
    let item: FeedbackItem
    public init(item: FeedbackItem) { self.item = item }

    public var body: some View {
        List {
            Section {
                LabeledContent("状态", value: item.isReplied ? "已回复" : "待回复")
                LabeledContent("类型", value: FeedbackOptions.typeLabel(item.type))
                LabeledContent("模块", value: FeedbackOptions.featureLabel(item.feature))
                if let date = item.createdDate { LabeledContent("提交时间", value: date.formatted(date: .abbreviated, time: .shortened)) }
            }
            Section("我的反馈") { Text(item.content).textSelection(.enabled) }
            Section("官方回复") {
                if let note = item.adminNote, !note.isEmpty {
                    Text(note).textSelection(.enabled)
                } else {
                    Text("暂无回复").foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("反馈详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}
