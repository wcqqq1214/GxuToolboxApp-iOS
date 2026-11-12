import GxuAuth
import SwiftUI

struct AnalyticsSettingsSection: View {
    let tracker: AnalyticsTracker
    @State private var isEnabled: Bool

    init(tracker: AnalyticsTracker) {
        self.tracker = tracker
        _isEnabled = State(initialValue: tracker.isEnabled)
    }

    var body: some View {
        Section {
            Toggle("分享使用统计", isOn: Binding(
                get: { isEnabled },
                set: {
                    tracker.isEnabled = $0
                    isEnabled = $0
                }
            ))
        } header: {
            Text("隐私")
        } footer: {
            Text("默认关闭。开启后向第三方服务发送应用启动、教务登录成功等使用事件和应用版本，事件内容不含学号或密码。关闭后停止发送新的统计请求，不影响正常使用。")
        }
    }
}
