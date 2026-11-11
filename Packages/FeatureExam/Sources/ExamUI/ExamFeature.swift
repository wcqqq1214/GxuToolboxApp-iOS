import ExamKit
import GxuStorage
import SwiftUI

public enum ExamFeature {
    public static let migrations = ExamRepository.migrations

    @MainActor
    public static func makeRootView() -> some View {
        List {
            NavigationLink { ExamInfoView() } label: { Label("考试信息", systemImage: "calendar.badge.clock") }
            NavigationLink { ScoreView() } label: { Label("成绩查询", systemImage: "list.bullet.clipboard") }
            NavigationLink { GpaView() } label: { Label("绩点计算器", systemImage: "function") }
        }
        .navigationTitle("考试与成绩")
    }
}
