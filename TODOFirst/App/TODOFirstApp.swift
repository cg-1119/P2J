import SwiftUI

@main
struct TODOFirstApp: App {
    @State private var taskStore = TaskStore()

    var body: some Scene {
        Window("P2J", id: "main") {
            TodayView()
                .environment(taskStore)
        }
        .defaultSize(width: 780, height: 600)

        MenuBarExtra("P2J", systemImage: "checklist") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)
    }
}
