import GxuDesign
import GxuFoundation
import ScheduleKit
import SwiftUI

struct ManualAdjustmentEditor: View {
    enum Scope: String, CaseIterable { case once = "仅本次", weeks = "指定周次" }

    let request: ManualAdjustmentRequest
    let weekCount: Int
    let onSave: ([ManualCourseAdjustment]) async throws -> Void
    let onRestore: () async throws -> Void
    @State private var scope = Scope.once
    @State private var weeksText: String
    @State private var week: Int
    @State private var weekday: Int
    @State private var begin: Int
    @State private var end: Int
    @State private var location: String
    @State private var isSaving = false
    @State private var message: String?
    @State private var confirmRestore = false
    @Environment(\.dismiss) private var dismiss

    init(request: ManualAdjustmentRequest, weekCount: Int,
         onSave: @escaping ([ManualCourseAdjustment]) async throws -> Void,
         onRestore: @escaping () async throws -> Void) {
        self.request = request
        self.weekCount = weekCount
        self.onSave = onSave
        self.onRestore = onRestore
        _weeksText = State(initialValue: String(request.source.week))
        _week = State(initialValue: request.existing?.week ?? request.source.week)
        _weekday = State(initialValue: request.existing?.weekday ?? request.source.weekday)
        _begin = State(initialValue: request.existing?.begin ?? request.source.begin)
        _end = State(initialValue: request.existing?.end ?? request.source.end)
        _location = State(initialValue: request.existing?.location ?? request.source.course.locationText)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(request.source.course.courseName).font(.headline)
                    Text("原安排：第 \(request.source.week) 周 \(WeekdayName.full(request.source.weekday)) 第 \(request.source.begin)-\(request.source.end) 节")
                    if !request.source.course.locationText.isEmpty { Text(request.source.course.locationText) }
                } footer: {
                    Text("仅修改本机课表，不会提交到教务或改变考勤要求。刷新课表后仍保留；可恢复原安排。")
                }
                Section {
                    Picker("调整范围", selection: $scope) {
                        ForEach(Scope.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    if scope == .weeks {
                        TextField("原课次周次，例如 1-8,10", text: $weeksText)
                            .keyboardType(.numbersAndPunctuation)
                            .autocorrectionDisabled()
                    }
                } footer: {
                    if scope == .weeks {
                        Text("可选原课次周次：\(TeachingWeeks.format(request.related.map(\.week)))。所选课次分别调整到各自周内的新时间。")
                    }
                }
                Section("调整后") {
                    if scope == .once {
                        Picker("教学周", selection: $week) {
                            ForEach(1...weekCount, id: \.self) { Text("第 \($0) 周").tag($0) }
                        }
                    }
                    Picker("星期", selection: $weekday) {
                        ForEach(1...7, id: \.self) { Text(WeekdayName.full($0)).tag($0) }
                    }
                    Picker("开始节次", selection: $begin) {
                        ForEach(ClassPeriods.all, id: \.number) { Text("第 \($0.number) 节 \($0.startText)").tag($0.number) }
                    }
                    Picker("结束节次", selection: $end) {
                        ForEach(ClassPeriods.all.filter { $0.number >= begin }, id: \.number) { Text("第 \($0.number) 节 \($0.endText)").tag($0.number) }
                    }
                    TextField("地点（选填）", text: $location, axis: .vertical)
                        .accessibilityLabel("地点（选填）")
                        .accessibilityIdentifier("manual-adjustment-location")
                }
                if let message { Section { Text(message).foregroundStyle(.red) } }
                if request.existing != nil {
                    Section {
                        Button("恢复本次原安排", role: .destructive) { confirmRestore = true }
                    }
                }
            }
            .disabled(isSaving)
            .navigationTitle("本地调课")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.disabled(isSaving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await save() } } label: {
                        if isSaving { ProgressView() } else { Text("保存") }
                    }.disabled(isSaving)
                }
            }
            .onChange(of: begin) { _, value in end = max(end, value) }
            .confirmationDialog("恢复本次原安排？", isPresented: $confirmRestore, titleVisibility: .visible) {
                Button("恢复原安排", role: .destructive) { Task { await restore() } }
            } message: {
                Text("只删除本次课的本地调整，其他课次保持不变。")
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    private func save() async {
        message = nil
        isSaving = true
        defer { isSaving = false }
        do {
            let sources: [CourseOccurrence]
            if scope == .once {
                sources = [request.source]
            } else {
                let weeks = try TeachingWeeks.parse(weeksText, weekCount: weekCount)
                sources = request.related.filter { weeks.contains($0.week) }
                guard Set(sources.map(\.week)) == Set(weeks) else { throw GxuError.invalidData("所选周次没有这门课的原课次") }
                guard sources.count == weeks.count else { throw GxuError.invalidData("所选周次包含同周补课，请分别调整每次课") }
            }
            let changes = sources.map {
                ManualCourseAdjustment(sourceID: $0.id, week: scope == .once ? week : $0.week,
                                       weekday: weekday, begin: begin, end: end, location: location)
            }
            try await onSave(changes)
            dismiss()
        } catch { message = (error as? GxuError)?.userMessage ?? error.localizedDescription }
    }

    private func restore() async {
        message = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await onRestore()
            dismiss()
        } catch { message = (error as? GxuError)?.userMessage ?? error.localizedDescription }
    }
}
