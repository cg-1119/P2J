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
        _taskStore = State(initialValue: TaskStore(preferences: .standard, didChange: { sync.publish($0) }))
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

        Settings {
            P2JSettingsView().environment(taskStore)
        }

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


struct P2JSettingsView: View {
    @Environment(TaskStore.self) private var store
    var body: some View {
        Form {
            Section {
                Toggle("상세 기록 모드", isOn: Binding(
                    get: { store.recordingMode == .detailed },
                    set: { store.setRecordingMode($0 ? .detailed : .normal) }
                ))
                Text("켜면 시작·종료 버튼과 시간 기록, 소요 시간 통계를 사용할 수 있어요. 끄면 완료 체크 중심의 일반 모드로 돌아가요.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("기존 시간 기록은 보존되며 상세 모드를 켜면 다시 볼 수 있어요.")
                    .font(.caption).foregroundStyle(.secondary)
            } header: { Text("기록 방식") }
            Section {
                LabeledContent("하루의 시작", value: "오전 6시")
                Text("종료를 누르지 않은 상세 기록은 하루가 지나도 미완료로 남아요.")
                    .font(.caption).foregroundStyle(.secondary)
            } header: { Text("작업일") }

        }
        .formStyle(.grouped).frame(width: 490, height: 370)
    }
}
