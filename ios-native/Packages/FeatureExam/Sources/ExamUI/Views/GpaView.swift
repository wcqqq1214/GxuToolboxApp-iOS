import ExamKit
import GxuAuth
import GxuDesign
import GxuFoundation
import SwiftUI

public struct GpaView: View {
    @Environment(\.services) private var services

    /// 默认显示全部学期的总绩点（无论从哪里进入，都不沿用成绩页选的学期）；在本页切换学年 / 学期只在本页生效
    public init() {}

    public var body: some View {
        Content(services: services)
    }

    private struct Content: View {
        @State private var model: ScoreViewModel
        @State private var showsWam = false
        @State private var showsMethod = false

        init(services: AppServices) {
            _model = State(initialValue: ScoreViewModel(services: services, query: .all))
        }

        /// 全部学期、某学年的全学年：按学期分组；单个学期：平铺
        private var grouped: Bool { model.query.isAll || model.query.term == nil }

        private var summaryTitle: String {
            let metric = showsWam ? "加权平均成绩" : "平均学分绩点"
            return model.query.isAll ? "全部学期 · \(metric)" : metric
        }

        /// 第一个分组的标题行右侧标出两列的含义
        private func header(_ title: String) -> some View {
            HStack {
                Text(title)
                Spacer()
                Text("绩点").frame(width: 56)
                Text("学分").frame(width: 40, alignment: .trailing)
            }
        }

        var body: some View {
            let result = model.gpa
            List {
                Section {
                    TermMenu(
                        years: model.years,
                        year: Binding(get: { model.query.year }, set: { model.query.year = $0; model.query.isAll = false }),
                        term: Binding(get: { model.query.term }, set: { model.query.term = $0; model.query.isAll = false }),
                        allowsWholeYear: true,
                        isAll: Binding(get: { model.query.isAll }, set: { model.query.isAll = $0 })
                    )
                }
                if model.error != nil {
                    errorSection(model.error, hasData: !model.scores.isEmpty, updatedAt: model.lastSyncedAt) {
                        Task { await model.load() }
                    }
                    
                    .listRowBackground(Color.clear)
                }
                // 请求失败又没有缓存时不显示数字（0.000 会被当成真的绩点）
                if !(model.error != nil && model.scores.isEmpty) {
                Section {
                    VStack(spacing: 4) {
                        Text(summaryTitle).font(.footnote).foregroundStyle(.secondary)
                        Text(model.scores.isEmpty ? "—" : (showsWam ? String(format: "%.2f", result.wam) : String(format: "%.3f", result.gpa)))
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                    }
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    Picker("指标", selection: $showsWam) {
                        Text("平均学分绩点").tag(false)
                        Text("加权平均成绩").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .listRowSeparator(.hidden)
                }
                }
                if !model.scores.isEmpty {
                    if grouped {
                        // 汇总范围课程多：按学期分组，每门课属于哪个学期一目了然，行内不再重复学期
                        ForEach(Array(ScoreGroup.group(model.scores).enumerated()), id: \.element.id) { index, group in
                            Section {
                                ForEach(group.scores) { ScoreLine(score: $0) }
                            } header: {
                                if index == 0 { header(group.title) } else { Text(group.title) }
                            }
                        }
                    } else {
                        Section {
                            ForEach(model.scores) { ScoreLine(score: $0) }
                        } header: {
                            header("课程")
                        }
                    }
                }
            }
            .navigationTitle("绩点计算器")
            .navigationBarTitleDisplayMode(.inline)
            .gxuHidesTabChrome()
            .toolbar {
                Button("计算方法", systemImage: "questionmark.circle") { showsMethod = true }
            }
            .sheet(isPresented: $showsMethod) { GpaMethodSheet() }
            .task { await model.resolveInitialTerm() }
            .task(id: LoadKey(value: model.query, ready: model.isReady)) { await model.load() }
            .refreshable { await model.load() }
        }
    }
}

private struct ScoreLine: View {
    let score: Score

    var body: some View {
        HStack {
            Text(score.courseName)
            Spacer()
            Text(GpaCalculator.pointText(for: score.score)).bold().frame(width: 56)
            Text(score.credit.map { String(format: "%.1f", $0) } ?? "—")
                .foregroundStyle(.secondary).frame(width: 40, alignment: .trailing)
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
