import SwiftUI
import Foundation

@main struct DemoRecorderApp: App {
    var body: some Scene {
        WindowGroup("P2J Demo Recorder") { RecordingView() }
            .windowResizability(.contentSize)
    }
}
struct RecordingView: View {
    @State private var name = "registration"
    @State private var status = "P2J Demo 창만 녹화 · 커서 및 오디오 제외"
    @State private var recording = false
    private var output: URL {
        Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("\(name).mp4")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("P2J 시연 촬영").font(.title2.bold())
            TextField("영상 이름", text: $name).textFieldStyle(.roundedBorder).disabled(recording)
            Text(status).font(.callout).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("녹화 시작") {
                    let path = output.path
                    recording = true
                    status = "녹화 중 — 예시 앱에서 조작하세요"
                    Task {
                        do {
                            try await Recorder.record(arguments: ["record", "auto", path])
                            status = "저장 완료: \(name).mp4"
                        } catch { status = "녹화 실패: \(error.localizedDescription)" }
                        recording = false
                    }
                }.disabled(recording || name.isEmpty || name.contains("/")).buttonStyle(.borderedProminent)
                Button("녹화 종료") {
                    FileManager.default.createFile(atPath: output.path + ".stop", contents: Data())
                }.disabled(!recording)
            }
        }.padding(24).frame(width: 430)
    }
}
