import GxuAuth
import GxuDesign
import GxuFoundation
import SwiftUI

public struct SelectedCoursesView: View {
    @Environment(\.services) private var services

    public init() {}

    public var body: some View { Content(services: services) }

    private struct Content: View {
        @State private var model: SelectedCoursesViewModel
        @State private var keyword = ""

        init(services: AppServices) {
            _model = State(initialValue: SelectedCoursesViewModel(services: services))
        }

        private var groups: [SelectedCourseGroup] { SelectedCourseGroup.group(model.courses, matching: keyword) }

        var body: some View {
            List {
                if let error = model.error {
                    if model.courses.isEmpty {
                        GxuErrorView(error.userMessage) { Task { await model.load() } }.listRowBackground(Color.clear)
                    } else {
                        GxuStaleBanner(updatedAt: nil, message: error.userMessage)
                            .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                    }
                }
                if model.courses.isEmpty {
                    if model.isLoading {
                        GxuLoadingView("正在查询已选课程…").frame(minHeight: 240).listRowBackground(Color.clear)
                    } else if model.error == nil {
                        GxuEmptyView("暂无已选课程", systemImage: "books.vertical").listRowBackground(Color.clear)
                    }
                } else if groups.isEmpty {
                    GxuEmptyView("没有匹配的课程", systemImage: "magnifyingglass").listRowBackground(Color.clear)
                }
                ForEach(groups) { group in
                    Section {
                        ForEach(group.courses) { SelectedCourseRow(course: $0) }
                    } header: {
                        Text("\(group.title) · \(group.courses.count)门 · \(ElectiveStrategy.number(group.credits))学分")
                    }
                }
            }
            .navigationTitle("已选课程")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $keyword, prompt: "课程、教师或模块")
            .toolbar { scopeMenu }
            .task { await model.resolveYears() }
            .task(id: model.scope) { await model.load() }
            .refreshable { await model.load() }
        }

        private var scopeMenu: some View {
            Menu {
                Picker("范围", selection: $model.scope) {
                    Text("全部学期").tag(SelectedCourseScope.all)
                    ForEach(model.years.sorted(by: >), id: \.self) { year in
                        Text(verbatim: "\(year)–\(year + 1) 春季").tag(SelectedCourseScope.term(AcademicTerm(year: year, term: 2)))
                        Text(verbatim: "\(year)–\(year + 1) 秋季").tag(SelectedCourseScope.term(AcademicTerm(year: year, term: 1)))
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(scopeTitle)
                    Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
                }
            }
        }

        private var scopeTitle: String {
            switch model.scope {
            case .all: "全部学期"
            case .term(let t): "\(t.year)–\(t.year + 1) \(t.term == 1 ? "秋季" : "春季")"
            }
        }
    }
}

private struct SelectedCourseRow: View {
    let course: SelectedCourse

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(course.courseName).font(.headline)
                Spacer()
                Text("\(ElectiveStrategy.number(course.credit)) 学分").font(.subheadline).foregroundStyle(.secondary)
            }
            Text([course.teacher, course.system, course.selectionType].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.subheadline).foregroundStyle(.secondary)
            if course.isOnline {
                Label("网课", systemImage: "wifi").font(.caption).foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 2)
    }
}
