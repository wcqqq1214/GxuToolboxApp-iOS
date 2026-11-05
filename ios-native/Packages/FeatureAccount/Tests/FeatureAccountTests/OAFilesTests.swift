import Foundation
import Testing
@testable import FeatureAccount

struct OAFilesParsingTests {
    @Test func parsesListPage() throws {
        let json = #"""
        {"page":1,"pageSize":20,"total":2,"totalPages":1,"hasNextPage":true,"hasPrevPage":false,"items":[
          {"id":11,"fileName":"关于做好期末工作的通知","fileNum":"西大党〔2026〕27号","typeName":"党委文件","showTime":"2026-11-03 09:10:11","isUrgent":true,"isRead":false,"deptName":"党办"},
          {"id":"12","fileName":"另一份","fileNum":"","typeName":"","showTime":"2026-11-02 08:00:00","isUrgent":false,"isRead":true,"deptName":""},
          {"fileName":"缺 id 的条目会被丢弃"}
        ]}
        """#
        let page = try OAFilesAPI.parseList(Data(json.utf8))
        #expect(page.rows.map(\.id) == [11, 12])
        #expect(page.hasNext)
        #expect(page.rows[0].date == "2026-11-03" && page.rows[0].isUrgent && !page.rows[0].isRead)
        #expect(page.rows[0].department == "党办")
    }

    @Test func parsesSearchResultWhetherObjectOrArray() throws {
        let item = #"{"id":5,"title":"搜索到的文件","fileNum":"校办〔2026〕1号","department":"校办","docTime":"2026-09-01 10:00:00","typeName":"行政文件","isUrgent":false}"#
        let asObject = #"{"items":[\#(item)],"hasNextPage":false}"#
        let asArray = "[\(asObject)]"
        for json in [asObject, asArray] {
            let page = try OAFilesAPI.parseSearch(Data(json.utf8))
            #expect(page.rows.count == 1 && page.rows[0].title == "搜索到的文件" && page.rows[0].date == "2026-09-01")
            #expect(!page.hasNext)
        }
    }

    @Test func parsesDetailWithAttachments() throws {
        let json = #"{"id":9,"fileName":"通知","fileNum":"x","typeName":"t","deptName":"d","showTime":"2026-11-01 00:00:00","fileBody":"<p>正文</p>","pdfUrl":"https://oa.gxu.edu.cn/f/9.pdf","docxUrl":null}"#
        let detail = try OAFilesAPI.parseDetail(Data(json.utf8))
        #expect(detail.html == "<p>正文</p>")
        #expect(detail.pdfURL?.lastPathComponent == "9.pdf" && detail.docxURL == nil)
    }

    @Test func emptyBodyBecomesNil() throws {
        let detail = try OAFilesAPI.parseDetail(Data(#"{"id":1,"fileBody":null}"#.utf8))
        #expect(detail.html == nil)
    }

    @Test func malformedDetailThrows() {
        #expect(throws: (any Error).self) { try OAFilesAPI.parseDetail(Data(#"{"fileName":"no id"}"#.utf8)) }
        #expect(throws: (any Error).self) { try OAFilesAPI.parseList(Data("not json".utf8)) }
    }
}
