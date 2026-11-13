import Foundation
import GxuAuth
import GxuFoundation
import GxuTestSupport
import Testing
@testable import FeatureAccount

private func pageJSON(page: Int, totalPages: Int, ids: [Int]) -> String {
    let items = ids.map { id in
        #"{"id":\#(id),"userId":"20******01","type":"bug","feature":"score","content":"成绩页面打不开了怎么办","status":"pending","adminNote":null,"createdAt":"2026-11-05T08:00:00.000Z","updatedAt":"2026-11-05T08:00:00.000Z"}"#
    }
    return #"{"code":200,"message":"success","data":{"list":[\#(items.joined(separator: ","))],"meta":{"total":\#(ids.count),"page":\#(page),"pageSize":10,"totalPages":\#(totalPages)}}}"#
}

private let listJSON = """
{"code":200,"message":"success","data":{"list":[
 {"id":2,"userId":"20******01","type":"bug","feature":"score","content":"成绩页面打不开了怎么办","status":"accept","adminNote":"已修复","createdAt":"2026-11-05T08:00:00.000Z","updatedAt":"2026-11-05T09:00:00.000Z"},
 {"id":"bad"},
 {"id":1,"type":"other","feature":"class_schedule","content":"建议增加深色模式支持","status":"pending","adminNote":null,"createdAt":"2026-11-04T08:00:00Z","updatedAt":"2026-11-04T08:00:00Z"}
],"meta":{"total":2,"page":1,"pageSize":10,"totalPages":1}}}
"""

@MainActor
struct FeedbackTests {
    @Test func listDropsMalformedItemsAndParsesDates() async throws {
        let mock = MockBackendAPI()
        mock.stub("GET /feedback/public", json: listJSON)
        let page = try await FeedbackRepository(backend: mock).publicList(page: 1)
        let items = page.items
        #expect(page.totalPages == 1)
        #expect(items.map(\.id) == [2, 1])
        #expect(items[0].maskedStudentId == "20******01" && items[1].maskedStudentId == nil)
        #expect(items[0].isReplied && !items[1].isReplied)
        #expect(items[0].createdDate != nil && items[1].createdDate != nil)
        #expect(items[1].adminNote == nil)
        #expect(FeedbackOptions.featureLabel(items[1].feature) == "课表")
    }

    @Test func draftValidationFollowsRNRules() {
        var draft = FeedbackDraft()
        #expect(draft.validationMessage == "请选择反馈类型")
        draft.type = "bug"; #expect(draft.validationMessage == "请选择问题模块")
        draft.feature = "score"; draft.content = "太短"
        #expect(draft.validationMessage == "反馈内容至少 10 个字")
        draft.content = "成绩页面一直转圈圈打不开啦"
        #expect(draft.validationMessage == "请选择联系方式类型")
        draft.contactType = "qq"; #expect(draft.validationMessage == "请填写联系方式")
        draft.contact = "12345"; #expect(draft.validationMessage == nil)
    }

    @Test func submitReturnsIdAndRequiresLogin() async throws {
        let services = AppServices.preview(signedIn: true)
        (services.backend as! MockBackendAPI).stub("POST /feedback", json: #"{"code":200,"data":{"id":77}}"#)
        let model = FeedbackFormModel(services: services)
        model.draft = { var d = FeedbackDraft(); d.type = "bug"; d.feature = "exam"; d.content = "考试倒计时显示的时间不对啊"; d.contactType = "qq"; d.contact = "1"; return d }()
        await model.submit()
        #expect(model.submittedID == 77)
        #expect(model.draft.content.isEmpty)

        let formWithoutAcademicAccount = FeedbackFormModel(services: AppServices.preview(signedIn: false))
        formWithoutAcademicAccount.draft = model.draft
        formWithoutAcademicAccount.draft.content = "考试倒计时显示的时间不对啊"
        await formWithoutAcademicAccount.submit()
        #expect(formWithoutAcademicAccount.errorMessage == "请先到设置里登录教务账号")
    }

    @Test func listLoadsWithoutLoginAndPagesUntilTheLastPage() async {
        let mock = MockBackendAPI()
        let model = FeedbackListModel(services: AppServices.preview(backend: mock, signedIn: false))
        mock.stub("GET /feedback/public", json: pageJSON(page: 1, totalPages: 2, ids: [3, 2]))
        await model.reload()
        #expect(model.items.map(\.id) == [3, 2] && model.error == nil && model.hasMore)

        mock.stub("GET /feedback/public", json: pageJSON(page: 2, totalPages: 2, ids: [2, 1]))
        await model.loadMoreIfNeeded(current: model.items[1])
        #expect(model.items.map(\.id) == [3, 2, 1])
        #expect(!model.hasMore)
        await model.loadMoreIfNeeded(current: model.items[2])
        #expect(mock.calls == ["GET /feedback/public", "GET /feedback/public"])
    }

    @Test func listFailureShowsTheError() async {
        let mock = MockBackendAPI()
        mock.stub("GET /feedback/public", error: .network("offline"))
        let model = FeedbackListModel(services: AppServices.preview(backend: mock, signedIn: false))
        await model.reload()
        #expect(model.items.isEmpty && model.error == .network("offline"))
    }
}

struct VersionCheckTests {
    private func json(_ entries: String) -> Data { Data(#"{"beta":[],"ios":[\#(entries)]}"#.utf8) }

    @Test func picksNewestIosBuildWithStoreLink() {
        let data = json("""
        {"versionName":"1.0.1","versionCode":2,"desc":"a","ori":{"testFlight":"https://testflight.apple.com/join/x"}},
        {"versionName":"1.0.2","versionCode":3,"desc":"b","ori":{"appStore":"https://apps.apple.com/app/id1","testFlight":"https://testflight.apple.com/join/x"}}
        """)
        let update = VersionCheck.newestUpdate(in: data, currentBuild: 1)
        #expect(update?.versionName == "1.0.2")
        #expect(update?.url.host == "apps.apple.com")
    }

    @Test func silentWhenVersionJsonHasNoIosChannel() {
        let androidOnly = Data(#"{"beta":[{"versionName":"beta 2.2.0","versionCode":20200,"desc":"x","ori":{"official":"https://a.b/x.apk"}}],"release":[]}"#.utf8)
        #expect(VersionCheck.newestUpdate(in: androidOnly, currentBuild: 1) == nil)
        #expect(VersionCheck.newestUpdate(in: Data("not json".utf8), currentBuild: 1) == nil)
        #expect(VersionCheck.newestUpdate(in: Data(), currentBuild: 1) == nil)
    }

    @Test func noUpdateWhenCurrentOrNoLinkOrNoIosChannel() {
        #expect(VersionCheck.newestUpdate(in: json(#"{"versionName":"1","versionCode":1,"ori":{"appStore":"https://a.b"}}"#), currentBuild: 1) == nil)
        #expect(VersionCheck.newestUpdate(in: json(#"{"versionName":"2","versionCode":2,"ori":{}}"#), currentBuild: 1) == nil)
        #expect(VersionCheck.newestUpdate(in: Data(#"{"release":[]}"#.utf8), currentBuild: 1) == nil)
        #expect(VersionCheck.newestUpdate(in: json(#"{"versionName":"2","versionCode":2,"ori":{"appStore":"http://insecure.example"}}"#), currentBuild: 1) == nil)
    }
}
