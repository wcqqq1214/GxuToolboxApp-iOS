import Foundation
import GxuAuth
import GxuFoundation

public struct OAFileRow: Identifiable, Hashable, Sendable {
    public let id: Int
    public let title: String
    public let fileNum: String
    public let typeName: String
    public let department: String
    public let date: String
    public let isUrgent: Bool
    public let isRead: Bool
}

public struct OAFilePage: Sendable {
    public let rows: [OAFileRow]
    public let hasNext: Bool
}

public struct OAFileDetail: Sendable, Equatable {
    public let id: Int
    public let title: String
    public let fileNum: String
    public let typeName: String
    public let department: String
    public let date: String
    public let html: String?
    public let pdfURL: URL?
    public let docxURL: URL?
}

public enum OAFileType {
    public static let all: [(label: String, id: Int)] = [
        ("全部文件", 0), ("党群行政部门", 102), ("教学单位", 103), ("行政文件", 11), ("党委文件", 13), ("科研单位", 105), ("教辅单位", 104),
    ]
}

public struct OAFilesAPI: Sendable {
    private let session: OASession
    public static let pageSize = 20

    public init(session: OASession) {
        self.session = session
    }

    public func list(page: Int, typeId: Int, keyword: String) async throws -> OAFilePage {
        let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        if !keyword.isEmpty { return try await search(keyword: keyword, page: page) }
        var body: [String: Any] = ["page": page, "pageSize": Self.pageSize, "keyword": "", "selectedDepartmentId": NSNull(), "keywordType": "title"]
        body["fileTypeId"] = typeId == 0 ? NSNull() : typeId
        let data = try await session.json("POST", path: "/wenjian/page", body: try JSONSerialization.data(withJSONObject: body))
        return try Self.parseList(data)
    }

    public func search(keyword: String, page: Int) async throws -> OAFilePage {
        let data = try await session.json("GET", path: "/document-search/search", query: [
            "_wv": "20250701-2200", "searchType": "deptDoc", "keyword": keyword, "keywordType": "title",
            "page": String(page), "pageSize": "10",
        ])
        return try Self.parseSearch(data)
    }

    public func detail(id: Int) async throws -> OAFileDetail {
        let data = try await session.json("GET", path: "/wenjian/detail", query: ["_wv": "20250701-2200", "id": String(id), "isAdmin": "false"])
        return try Self.parseDetail(data)
    }

    public func localFile(for url: URL, preferredExtension: String? = nil) async throws -> URL {
        try await session.download(url, preferredExtension: preferredExtension)
    }


    private static func string(_ dict: [String: Any], _ key: String) -> String {
        if let value = dict[key] as? String { return value }
        if let value = dict[key] as? NSNumber { return value.stringValue }
        return ""
    }

    private static func day(_ text: String) -> String { String(text.prefix(10)) }

    private static func object(_ data: Data) throws -> [String: Any] {
        if let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] { return dict }
        if let array = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]], let first = array.first { return first }
        throw GxuError.decoding("OA 响应格式不符")
    }

    static func parseList(_ data: Data) throws -> OAFilePage {
        let result = try object(data)
        let items = result["items"] as? [[String: Any]] ?? []
        let rows = items.compactMap { item -> OAFileRow? in
            guard let id = (item["id"] as? Int) ?? Int(string(item, "id")) else { return nil }
            return OAFileRow(
                id: id, title: string(item, "fileName"), fileNum: string(item, "fileNum"), typeName: string(item, "typeName"),
                department: string(item, "deptName"), date: day(string(item, "showTime")),
                isUrgent: item["isUrgent"] as? Bool ?? false, isRead: item["isRead"] as? Bool ?? true
            )
        }
        return OAFilePage(rows: rows, hasNext: result["hasNextPage"] as? Bool ?? false)
    }

    static func parseSearch(_ data: Data) throws -> OAFilePage {
        let result = try object(data)
        let items = result["items"] as? [[String: Any]] ?? []
        let rows = items.compactMap { item -> OAFileRow? in
            guard let id = (item["id"] as? Int) ?? Int(string(item, "id")) else { return nil }
            return OAFileRow(
                id: id, title: string(item, "title"), fileNum: string(item, "fileNum"), typeName: string(item, "typeName"),
                department: string(item, "department"), date: day(string(item, "docTime")),
                isUrgent: item["isUrgent"] as? Bool ?? false, isRead: true
            )
        }
        return OAFilePage(rows: rows, hasNext: result["hasNextPage"] as? Bool ?? false)
    }

    static func parseDetail(_ data: Data) throws -> OAFileDetail {
        let item = try object(data)
        guard let id = (item["id"] as? Int) ?? Int(string(item, "id")) else { throw GxuError.decoding("OA 文件详情缺少 id") }
        func url(_ key: String) -> URL? {
            let text = string(item, key)
            return text.isEmpty ? nil : URL(string: text)
        }
        let body = string(item, "fileBody")
        return OAFileDetail(
            id: id, title: string(item, "fileName"), fileNum: string(item, "fileNum"), typeName: string(item, "typeName"),
            department: string(item, "deptName"), date: day(string(item, "showTime")),
            html: body.isEmpty ? nil : body, pdfURL: url("pdfUrl"), docxURL: url("docxUrl")
        )
    }
}
