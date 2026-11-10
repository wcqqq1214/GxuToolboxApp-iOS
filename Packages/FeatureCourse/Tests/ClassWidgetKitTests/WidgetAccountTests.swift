import Foundation
import GxuAuth
import GxuTestSupport
import ScheduleKit
import FeatureCampus
import ClassWidgetKit
import Testing

@MainActor
struct WidgetAccountTests {
    @Test func logoutWhileForegroundMustClearActiveWidgetAccount() async throws {
        let services = AppServices.preview(features: [ScheduleKit.migrations, CampusFeature.migrations], studentId: "review-student-A")
        let bridge = Task { await WidgetBridge.run(services: services) }
        defer { bridge.cancel() }
        for _ in 0..<500 where services.shared.value(WidgetShared.activeStudentIdKey) == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(services.shared.value(WidgetShared.activeStudentIdKey) == "review-student-A")
        await services.accounts.logout(.jw)
        for _ in 0..<100 where services.shared.value(WidgetShared.activeStudentIdKey) != nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(WidgetShared.currentSnapshot(store: services.shared) == nil)
        #expect(services.shared.value(WidgetShared.activeStudentIdKey) == nil)
    }
}
