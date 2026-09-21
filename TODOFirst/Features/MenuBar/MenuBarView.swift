import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(AppIdentity.name, systemImage: "checklist")
                .font(.headline)
            Text(AppIdentity.tagline)
                .foregroundStyle(.secondary)
            Text("빠른 목록은 다음 개발 단계에서 연결됩니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            Button("앱 열기", systemImage: "macwindow") {
                openWindow(id: "main")
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("o")
            Button("종료", systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(20)
        .frame(width: 280)
    }
}
