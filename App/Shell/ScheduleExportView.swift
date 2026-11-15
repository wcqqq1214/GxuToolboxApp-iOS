import ScheduleUI
import SwiftUI

struct ScheduleExportView: View {
    var body: some View {
        ScheduleFeature.makeExportView()
            .toolbar {
                ToolbarItem(placement: .secondaryAction) {
                    NavigationLink("教务原版课表") { JwScheduleExportView() }
                }
            }
    }
}
