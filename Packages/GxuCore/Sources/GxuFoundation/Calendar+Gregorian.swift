import Foundation

public extension Calendar {
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
