import AppIntents
import ClassWidgetKit
import ExamKit
import Foundation
import GxuAuth
import GxuStorage
import ScheduleKit
import SwiftUI

public struct ToolboxIntentsPackage: AppIntentsPackage {}

enum IntentEnvironment {
    static func open() throws -> (studentId: String, database: AppDatabase) {
        let shared = UserDefaultsSharedStore()
        guard let studentId = shared.value(WidgetShared.activeStudentIdKey)
            ?? KeychainCredentialStore().load(.jw)?.username
        else { throw IntentFailure.notSignedIn }
        let database = try AppDatabase.openReadOnly()
        return (studentId, database)
    }
}

enum IntentFailure: Error, CustomLocalizedStringResourceConvertible {
    case notSignedIn, noSchedule

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notSignedIn: "请先在西大工具箱里登录教务账号。"
        case .noSchedule: "还没有课表数据，请先打开西大工具箱同步一次课表。"
        }
    }
}

private func coursesDialog(offset: Int, name: String) async throws -> (String, [WidgetCourse]) {
    let (studentId, database) = try IntentEnvironment.open()
    let calendar = Calendar.current
    let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: .now)) ?? .now
    do {
        let username = KeychainCredentialStore().load(.unified)?.username
        let courses = try await ScheduleQuery.courses(on: day, studentId: studentId, database: database, unifiedUsername: username)
        return (ScheduleQuery.describe(dayName: name, courses: courses), courses)
    } catch {
        throw IntentFailure.noSchedule
    }
}

public struct TodayCoursesIntent: AppIntent {
    public static let title: LocalizedStringResource = "今天的课"
    public static let description = IntentDescription("查看今天有什么课。")

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let (text, _) = try await coursesDialog(offset: 0, name: "今天")
        return .result(value: text, dialog: IntentDialog(stringLiteral: text))
    }
}

public struct TomorrowCoursesIntent: AppIntent {
    public static let title: LocalizedStringResource = "明天的课"
    public static let description = IntentDescription("查看明天有什么课。")

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let (text, _) = try await coursesDialog(offset: 1, name: "明天")
        return .result(value: text, dialog: IntentDialog(stringLiteral: text))
    }
}

public struct NextExamIntent: AppIntent {
    public static let title: LocalizedStringResource = "下一场考试"
    public static let description = IntentDescription("查看最近一场还没结束的考试。")

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let (studentId, database) = try IntentEnvironment.open()
        let item = try await ExamRepository(database: database).nextExam(studentId: studentId)
        let text = NextExamSpeech.describe(item)
        return .result(value: text, dialog: IntentDialog(stringLiteral: text))
    }
}
