import SwiftUI

/// 教师详情头部：左边照片，右边姓名（主题色）、职称 / 工号标签、性别 / 政治面貌 / 职务、通讯地址、更新时间。
/// 布局沿用 RN 版（照片在左、文字在右），没有值的项不显示。
struct TeacherHeaderCard: View {
    let info: TeacherHeader?
    let name: String
    let unit: String
    let photo: URL?

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            TeacherAvatar(url: photo, name: name, size: CGSize(width: 100, height: 136), cornerRadius: 10)
            VStack(alignment: .leading, spacing: 8) {
                Text(name).font(.title2.bold()).foregroundStyle(Color.accentColor)
                if !unit.isEmpty { Text(unit).font(.subheadline).foregroundStyle(.secondary) }
                if let info {
                    if !info.badges.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(info.badges, id: \.self) { badge in
                                Text(badge)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                            }
                        }
                    }
                    if !info.infoLine.isEmpty { Text(info.infoLine.joined(separator: " · ")).font(.subheadline) }
                    if !info.address.isEmpty {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Image(systemName: "mappin.and.ellipse").imageScale(.small)
                            Text(info.address)
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                    if !info.updatedAt.isEmpty {
                        Text("更新于 \(info.updatedAt)").font(.caption).foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
    }
}
