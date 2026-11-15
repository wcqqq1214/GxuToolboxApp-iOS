import EventKitUI
import SwiftUI

struct ExamCalendarEditor: UIViewControllerRepresentable {
    let event: ExamCalendarEvent
    let onFinish: @MainActor @Sendable (Bool) -> Void

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = event.makeEvent(in: store)
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onFinish: @MainActor @Sendable (Bool) -> Void

        init(onFinish: @escaping @MainActor @Sendable (Bool) -> Void) {
            self.onFinish = onFinish
        }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            let saved = action == .saved
            let completion = onFinish
            Task { @MainActor in completion(saved) }
        }
    }
}
