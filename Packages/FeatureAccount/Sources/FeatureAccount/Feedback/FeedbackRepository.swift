import Foundation
import GxuAuth
import GxuFoundation
import GxuNetworking
import UIKit

public struct FeedbackItem: Decodable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let userId: String
    public let type: String
    public let feature: String
    public let content: String
    public let contactType: String
    public let contact: String
    public let status: String
    public let deviceModel: String
    public let appVersion: String
    public let adminNote: String?
    public let createdAt: String
    public let updatedAt: String

    public var isReplied: Bool { status == "accept" }
    public var createdDate: Date? { Self.parse(createdAt) }

    static func parse(_ text: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }
}

public enum FeedbackOptions {
    public static let types: [(label: String, value: String)] = [
        ("报告 Bug", "bug"), ("功能建议", "suggestion"), ("体验问题", "experience"), ("其他", "other"),
    ]
    public static let features: [(label: String, value: String)] = [
        ("课表", "schedule"), ("成绩", "score"), ("考试", "exam"), ("账号登录", "auth"), ("其他", "other"),
    ]
    public static let contactTypes: [(label: String, value: String)] = [("QQ", "qq"), ("微信", "wechat"), ("邮箱", "email")]
    public static let minContentLength = 10

    public static func typeLabel(_ value: String) -> String { types.first { $0.value == value }?.label ?? value }
    public static func featureLabel(_ value: String) -> String {
        value == "class_schedule" ? "课表" : (features.first { $0.value == value }?.label ?? value)
    }
}

public struct FeedbackDraft: Sendable, Equatable {
    public var type = ""
    public var feature = ""
    public var content = ""
    public var contactType = ""
    public var contact = ""
    public init() {}

    public var validationMessage: String? {
        if type.isEmpty { return "请选择反馈类型" }
        if feature.isEmpty { return "请选择问题模块" }
        if content.trimmingCharacters(in: .whitespacesAndNewlines).count < FeedbackOptions.minContentLength {
            return "反馈内容至少 \(FeedbackOptions.minContentLength) 个字"
        }
        if contactType.isEmpty { return "请选择联系方式类型" }
        if contact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "请填写联系方式" }
        return nil
    }
}

private struct SubmitBody: Encodable, Sendable {
    let userId: String
    let type: String
    let feature: String
    let content: String
    let contactType: String
    let contact: String
    let deviceModel: String
    let appVersion: String
}
private struct SubmitResult: Decodable, Sendable { let id: Int }

private struct LossyList: Decodable, Sendable {
    let list: [FeedbackItem]
    private enum Keys: String, CodingKey { case list }
    private struct Skip: Decodable {}
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        var array = try container.nestedUnkeyedContainer(forKey: .list)
        var items: [FeedbackItem] = []
        while !array.isAtEnd {
            if let item = try? array.decode(FeedbackItem.self) { items.append(item) } else { _ = try? array.decode(Skip.self) }
        }
        list = items
    }
}

public struct FeedbackRepository: Sendable {
    private let backend: any BackendAPI
    public static let pageSize = 10

    public init(backend: any BackendAPI) {
        self.backend = backend
    }

    @discardableResult
    public func submit(_ draft: FeedbackDraft, studentId: String) async throws -> Int {
        let body = SubmitBody(
            userId: studentId, type: draft.type, feature: draft.feature,
            content: draft.content.trimmingCharacters(in: .whitespacesAndNewlines),
            contactType: draft.contactType, contact: draft.contact.trimmingCharacters(in: .whitespacesAndNewlines),
            deviceModel: DeviceInfo.model, appVersion: AnalyticsTracker.appVersion
        )
        return try await backend.postData("/feedback", body: body, auth: nil, as: SubmitResult.self).id
    }

    public func myList(studentId: String, page: Int) async throws -> [FeedbackItem] {
        try await backend.getData(
            "/feedback/\(studentId)", query: ["page": String(page), "pageSize": String(Self.pageSize)], auth: nil, as: LossyList.self
        ).list
    }
}

enum DeviceInfo {
    static var model: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return simulated }
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}
