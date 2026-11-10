import GxuFoundation
import ExamKit
import Foundation

/// "下一场考试"的口语化文案（App Intent、小组件共用）
public enum NextExamSpeech {
    public static func describe(_ item: ExamItem?, now: Date = .now, calendar: Calendar = .current) -> String {
        guard let item, let date = item.date else {
            return "没有查到还没结束的考试。在西大工具箱里打开「考试信息」可以同步最新安排。"
        }
        let f = DateFormatter()
        f.calendar = calendar.gregorianEquivalent
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 HH:mm"
        var text = "下一场考试是\(item.exam.course)，\(f.string(from: date))"
        if !item.exam.classroom.isEmpty { text += "，在\(item.exam.classroom)" }
        if let countdown = item.countdownText(now: now, calendar: calendar) { text += "（\(countdown)）" }
        return text + "。"
    }
}
