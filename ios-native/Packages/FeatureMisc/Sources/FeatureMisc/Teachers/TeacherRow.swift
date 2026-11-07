import SwiftUI

/// 教师查询结果的一行：竖版头像 + 姓名 + 单位（单位可换行，最多两行）
struct TeacherRow: View {
    let teacher: TeacherSummary

    var body: some View {
        HStack(spacing: 14) {
            TeacherAvatar(url: teacher.avatarURL, name: teacher.name, size: CGSize(width: 52, height: 68), cornerRadius: 8)
            VStack(alignment: .leading, spacing: 4) {
                Text(teacher.name).font(.headline)
                if !teacher.unit.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Image(systemName: "building.2").imageScale(.small)
                        Text(teacher.unit).lineLimit(2)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
