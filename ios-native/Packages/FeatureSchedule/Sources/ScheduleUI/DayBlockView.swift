import GxuDesign
import ScheduleKit
import SwiftUI

/// 假期 / 调休休息日的整天块。内容层，不用玻璃；用系统绿色的淡色底，深浅色自动适配。
struct DayBlockView: View {
    let block: DayBlock

    private var systemImage: String {
        switch block.kind {
        case .rest: "moon.zzz"
        case .holiday(.school): "figure.run"
        case .holiday: "sun.max"
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.footnote)
            Text(block.title)
                .font(.caption2.weight(.semibold))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(Color.green.mix(with: .primary, by: 0.35))
        // 居中而不是贴顶：课表默认滚到当前时间，贴顶的标题会被滚出屏幕
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: GxuDesign.Radius.block, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(block.title)，\(block.kind == .rest ? "调休休息" : "放假")")
    }
}
