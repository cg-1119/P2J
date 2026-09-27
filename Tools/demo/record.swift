// macOS 15+ / ScreenCaptureKit. 데모 앱의 창만 녹화하며 커서·오디오는 수집하지 않습니다.
import Foundation
import CoreGraphics
import ScreenCaptureKit
import AVFoundation

final class RecordingDelegate: NSObject, SCRecordingOutputDelegate, @unchecked Sendable {
    var finished = false
    var error: Error?
    func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) { print("RECORDING"); fflush(stdout) }
    func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) { finished = true }
    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        self.error = error; finished = true
    }
}
struct Recorder {
    static func main() async {
        do { try await record() }
        catch {
            fputs("녹화 실패: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
    static func record(arguments: [String] = CommandLine.arguments) async throws {
        if arguments.contains("--request-permission") {
            print(CGRequestScreenCaptureAccess() ? "화면 기록 권한 허용됨" : "화면 기록 권한이 필요합니다. 시스템 설정에서 녹화 도구를 허용해주세요.")
            return
        }
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        let windows = content.windows.filter { $0.owningApplication?.bundleIdentifier == "com.cg1119.p2j.demo" }
        if arguments.count < 3 {
            for w in windows { print("\(w.windowID) \(w.title ?? "") \(w.frame)") }
            return
        }
        let id = arguments[1] == "auto" ? windows.filter { $0.title == "P2J" }.max(by: { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height })?.windowID : UInt32(arguments[1])
        guard let window = windows.first(where: { $0.windowID == id }),
              let app = window.owningApplication,
              let display = content.displays.first(where: { $0.frame.intersects(window.frame) }) else {
            throw NSError(domain: "P2JDemoWindowNotFound", code: 1)
        }
        let destination = URL(fileURLWithPath: arguments[2])
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw NSError(domain: "OutputAlreadyExists", code: 2)
        }
        let filter = SCContentFilter(display: display, including: [app], exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.sourceRect = window.frame.offsetBy(dx: -display.frame.minX, dy: -display.frame.minY)
        config.width = Int(window.frame.width) * 2
        config.height = Int(window.frame.height) * 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.showsCursor = false
        config.capturesAudio = false
        config.captureMicrophone = false
        config.includeChildWindows = true
        config.ignoreShadowsDisplay = true
        let outputConfig = SCRecordingOutputConfiguration()
        outputConfig.outputURL = destination
        outputConfig.outputFileType = .mp4
        outputConfig.videoCodecType = .h264
        let delegate = RecordingDelegate()
        let output = SCRecordingOutput(configuration: outputConfig, delegate: delegate)
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addRecordingOutput(output)
        try await stream.startCapture()
        let deadline = Date().addingTimeInterval(180)
        let stop = destination.path + ".stop"
        while Date() < deadline && !FileManager.default.fileExists(atPath: stop) && !delegate.finished {
            try await Task.sleep(for: .milliseconds(200))
        }
        try await stream.stopCapture()
        for _ in 0..<100 where !delegate.finished { try await Task.sleep(for: .milliseconds(100)) }
        if let error = delegate.error { throw error }
        guard delegate.finished else { throw NSError(domain:"RecordingDidNotFinish",code:3) }
        print("SAVED \(destination.lastPathComponent)")
    }
}
