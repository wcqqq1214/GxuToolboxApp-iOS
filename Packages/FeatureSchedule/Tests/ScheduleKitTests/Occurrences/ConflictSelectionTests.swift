import Foundation
import Testing
@testable import ScheduleKit

struct ConflictSelectionTests {
    @Test func sameNameConflictCanSelectSecond() {
        let a = course("自习", weekday: 1, 1, 2, venue: "A楼")
        let b = course("自习", weekday: 1, 2, 3, venue: "B楼")
        let occ = ScheduleExpander.occurrences(of: Schedule(theoryList: [a, b]), in: term)
        let group = ScheduleExpander.conflictGroups(occ)[0]
        #expect(group.items.count == 2)
        let second = group.items[1]
        let picked = group.selected(choices: [group.key: ScheduleExpander.selectionKey(second.course)])
        #expect(picked.id == second.id)
    }
}
