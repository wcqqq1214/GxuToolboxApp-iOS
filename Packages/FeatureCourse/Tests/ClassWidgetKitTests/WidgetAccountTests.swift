import Foundation
import GxuAuth
import GxuTestSupport
import ScheduleKit
import FeatureCampus
@testable import ClassWidgetKit
import Testing

@MainActor
struct WidgetAccountTests {
    @Test func logoutWhileForegroundMustClearActiveWidgetAccount() async throws {
        let services = AppServices.preview(features: [ScheduleKit.migrations, CampusFeature.migrations], studentId: "review-student-A")
        let (activityRelease, releaseActivity) = AsyncStream<Void>.makeStream()
        let bridge = Task {
            await WidgetBridge.run(services: services) { _, _ in
                for await _ in activityRelease {}
            }
        }
        defer {
            bridge.cancel()
            releaseActivity.finish()
        }
        for _ in 0..<500 where services.shared.value(WidgetShared.activeStudentIdKey) == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(services.shared.value(WidgetShared.activeStudentIdKey) == "review-student-A")
        await services.accounts.logout(.jw)
        for _ in 0..<500 where services.shared.value(WidgetShared.activeStudentIdKey) != nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(WidgetShared.currentSnapshot(store: services.shared) == nil)
        #expect(services.shared.value(WidgetShared.activeStudentIdKey) == nil)
    }
}
