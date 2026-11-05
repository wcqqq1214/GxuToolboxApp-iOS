import GxuAuth
import GxuFoundation
import SwiftUI

public struct GpaView: View {
    @Environment(\.services) private var services
    private let initial: ScoreViewModel.Query?

    public init() { initial = nil }
    init(initial: ScoreViewModel.Query) { self.initial = initial }

    public var body: some View {
        Content(services: services, initial: initial)
    }

    private struct Content: View {
        @State private var model: ScoreViewModel
        @State private var showsWam = false
        @State private var showsMethod = false

        init(services: AppServices, initial: ScoreViewModel.Query?) {
            _model = State(initialValue: ScoreViewModel(services: services, query: initial))
        }

        var body: some View {
            let result = model.gpa
            List {
                Section {
                    TermPicker(
                        year: Binding(get: { model.query.year }, set: { model.query.year = $0 }),
                        term: Binding(get: { model.query.term }, set: { model.query.term = $0 }),
                        allowsWholeYear: true
                    )
                    if let error = model.error {
                        ErrorBanner(message: error.userMessage) { Task { await model.load() } }
                    }
                }
                Section {
                    VStack(spacing: 4) {
                        Text(showsWam ? "加权平均成绩" : "平均学分绩点").font(.footnote).foregroundStyle(.secondary)
                        Text(showsWam ? String(format: "%.2f", result.wam) : String(format: "%.3f", result.gpa))
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                    }
                    .frame(maxWidth: .infinity)
                    Picker("指标", selection: $showsWam) {
                        Text("平均学分绩点").tag(false)
                        Text("加权平均成绩").tag(true)
                    }
                    .pickerStyle(.segmented)
                }
                if !model.scores.isEmpty {
                    Section {
                        ForEach(model.scores) { s in
                            HStack {
                                Text(s.courseName)
                                Spacer()
                                Text(GpaCalculator.pointText(for: s.score)).bold().frame(width: 56)
                                Text(s.credit.map { String(format: "%.1f", $0) } ?? "—")
                                    .foregroundStyle(.secondary).frame(width: 40, alignment: .trailing)
                            }
                        }
                    } header: {
                        Text("课程")
                    } footer: {
                        Text("右两列依次为绩点、学分")
                    }
                }
            }
            .navigationTitle("绩点计算器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("计算方法", systemImage: "questionmark.circle") { showsMethod = true }
            }
            .sheet(isPresented: $showsMethod) { GpaMethodSheet() }
            .task(id: model.query) { await model.load() }
            .refreshable { await model.load() }
        }
    }
}

private struct GpaMethodSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(GpaMethodText.full)
                    .padding()
            }
            .navigationTitle("计算方法")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("关闭") { dismiss() } }
        }
        .presentationDetents([.medium, .large])
    }
}

enum GpaMethodText {
    static let full = """
    文本来源：《广西大学普通本科学生课程修读、考核及成绩管理办法（2019年修订）》

    为了检查学生学习质量，学校采用课程学分绩点、平均学分绩点、加权平均成绩来衡量学生学习的质量。

    （一）课程学分绩点按以下简化公式计算：
    课程的学分绩点＝[（课程考核成绩÷课程考核满分值）×100]/10－5
    其中，考核不合格未取得学分的课程，其学分绩点为零。

    （二）平均学分绩点按下式计算：
    平均学分绩点＝∑（课程学分绩点×取得的课程学分×K）/ ∑ 修读课程学分
    其中，取得的课程学分，指修读课程中已及格课程所对应的学分；课程考核总评成绩（或折算成绩）达到合格标准（即百分制60分及以上或五级制及格及以上）的即取得学分；K为课程系数，没有特别说明时，K取值为1。

    （三）加权平均成绩按下式计算：
    加权平均成绩＝∑[（课程考核成绩÷课程考核满分值）×100×修读课程学分×K] / ∑ 修读课程学分

    （四）平均学分绩点按学期计算的为学期平均学分绩点，按学年计算的为学年平均学分绩点，从入学后不分学期累计计算的为累计平均学分绩点，按入学后至毕业计算的为毕业平均学分绩点。加权平均成绩的计算方法与上述方法一致。

    （五）原则上计算学生课程学分绩点、平均学分绩点、加权平均成绩时，计算结果一般按四舍五入法保留至小数后两位。
    """
}
