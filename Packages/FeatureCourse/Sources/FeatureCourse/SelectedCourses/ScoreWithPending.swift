import ExamUI
import GxuAuth
import SwiftUI

public struct ScoreWithPendingView: View {
    @Environment(\.services) private var services

    public init() {}

    public var body: some View {
        ScoreView(pendingSource: SelectedCoursePendingSource(backend: services.backend, database: services.database))
    }
}
