import Foundation

public extension Calendar {
    /// 同时区、同一周起始日设置的公历。已经是公历就原样返回。
    var gregorianEquivalent: Calendar {
        if identifier == .gregorian { return self }
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = timeZone
        gregorian.locale = locale
        gregorian.firstWeekday = firstWeekday
        gregorian.minimumDaysInFirstWeek = minimumDaysInFirstWeek
        return gregorian
    }
}
