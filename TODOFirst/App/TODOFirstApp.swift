import SwiftUI

@main
struct TODOFirstApp: App {
    @State private var taskStore = TaskStore()

    var body: some Scene {
        Window("TODO First", id: "main") {
            TodayView()
                .environment(taskStore)
        }
        .defaultSize(width: 780, height: 600)

        MenuBarExtra("TODO First", systemImage: "checklist") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)
    }
}
