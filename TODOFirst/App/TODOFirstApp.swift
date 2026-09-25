import AppKit
import SwiftUI

@main
struct TODOFirstApp: App {
    @State private var taskStore: TaskStore
    @State private var widgetSync: WidgetSync
    @Environment(\.openWindow) private var openWindow

    init() {
        try? TaskAutomation.prepare()
        let sync = WidgetSync()
        _widgetSync = State(initialValue: sync)
        _taskStore = State(initialValue: TaskStore(didChange: { sync.publish($0) }))
    }

    var body: some Scene {
        Window("P2J", id: "main") {
            TodayView()
                .environment(taskStore)
                .onOpenURL { url in
                    if url.scheme == "p2j", url.host == "automation" {
                        TaskAutomation.handle(url, store: taskStore)
                        return
                    }
                    guard url.scheme == "p2j", url.host == "today" else { return }
                    openWindow(id: "main")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }
        .defaultSize(width: 780, height: 600)
        .commands {
            CommandGroup(after: .windowArrangement) {
                Button("위젯 미리보기 및 연결") { openWindow(id: "widgets") }
            }
        }

        Window("P2J 위젯", id: "widgets") {
            WidgetGalleryView().environment(taskStore).environment(widgetSync)
        }
        .defaultSize(width: 720, height: 580)

        MenuBarExtra {
            MenuBarView().environment(taskStore)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "checklist")
                Text("P2J")
            }
            .accessibilityLabel("P2J 오늘 할 일")
        }
        .menuBarExtraStyle(.window)
    }
}
