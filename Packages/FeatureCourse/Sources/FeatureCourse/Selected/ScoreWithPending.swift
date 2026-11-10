import ExamUI
import GxuAuth
import SwiftUI

/// 成绩页 + "未出分科目"（已选课程来自本包）。工具箱的"成绩查询"用它。
public struct ScoreWithPendingView: View {
    @Environment(\.services) private var services

    public init() {}

    public var body: some View {
        ScoreView(pendingSource: SelectedCoursePendingSource(backend: services.backend, database: services.database))
    }
}
