import SwiftUI

@main
struct TODOFirstApp: App {
    var body: some Scene {
        Window("TODO First", id: "main") {
            TodayView()
        }
        .defaultSize(width: 720, height: 520)

        MenuBarExtra("TODO First", systemImage: "checklist") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)
    }
}
