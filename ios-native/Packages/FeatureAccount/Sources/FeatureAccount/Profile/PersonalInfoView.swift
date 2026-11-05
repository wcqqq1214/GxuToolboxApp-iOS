import GxuAuth
import GxuDesign
import GxuFoundation
import Observation
import SwiftUI

@MainActor @Observable
final class PersonalInfoModel {
    private(set) var profile: UserProfile?
    private(set) var isLoading = false
    private(set) var error: GxuError?

    private let services: AppServices

    init(services: AppServices) {
        self.services = services
        if let id = services.accounts.studentId { profile = services.profiles.cached(studentId: id) }
    }

    func load() async {
        guard let id = services.accounts.studentId else { error = .notLoggedIn(.jw); return }
        isLoading = true
        defer { isLoading = false }
        do {
            profile = try await services.profiles.load(studentId: id)
            error = nil
        } catch is CancellationError {
            return
        } catch let error as GxuError {
            self.error = error
        } catch {
            self.error = .network("加载失败")
        }
    }
}

/// 设置 → 个人信息：展示教务用户资料（不包含身份证号等敏感字段）
public struct PersonalInfoView: View {
    @Environment(\.services) private var services
    public init() {}
    public var body: some View { Content(model: PersonalInfoModel(services: services)) }

    private struct Content: View {
        @State var model: PersonalInfoModel

        var body: some View {
            List {
                if let error = model.error, model.profile != nil {
                    GxuStaleBanner(updatedAt: nil, message: error.userMessage)
                        .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                }
                if let p = model.profile {
                    Section {
                        LabeledContent("姓名", value: p.name)
                        LabeledContent("学号", value: p.studentId)
                        LabeledContent("学院", value: p.college)
                        LabeledContent("专业", value: p.major)
                        LabeledContent("班级", value: p.className)
                        LabeledContent("入学年份", value: String(p.enrollmentYear))
                        LabeledContent("学制", value: "\(p.studyYears) 年")
                    }
                }
            }
            .overlay {
                if model.profile == nil {
                    if model.isLoading {
                        GxuLoadingView("正在加载…")
                    } else if let error = model.error {
                        GxuErrorView(error.userMessage) { Task { await model.load() } }
                    }
                }
            }
            .navigationTitle("个人信息")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await model.load() }
            .task { await model.load() }
        }
    }
}
