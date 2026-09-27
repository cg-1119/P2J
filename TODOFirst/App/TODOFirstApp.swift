import AppKit
import SwiftUI

@main
struct TODOFirstApp: App {
    @AppStorage("hasCompletedTutorial") private var hasCompletedTutorial = false
    @State private var presentedTutorial = false
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
                .task {
                    guard !hasCompletedTutorial, !presentedTutorial else { return }
                    presentedTutorial = true
                    openWindow(id: "tutorial")
                }
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

        Window("P2J 시작하기", id: "tutorial") {
            P2JTutorialView().environment(taskStore)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

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
    @Environment(\.openWindow) private var openWindow
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
            Section {
                Button("튜토리얼 다시 보기", systemImage: "sparkles") { openWindow(id: "tutorial") }
            } header: { Text("도움말") }
        }
        .formStyle(.grouped).frame(width: 490, height: 370)
    }
}

struct P2JTutorialView: View {
    @Environment(TaskStore.self) private var store
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    @AppStorage("hasCompletedTutorial") private var hasCompletedTutorial = false
    @State private var step = 0
    @State private var detailed = false
    private let titles = ["생각을 오늘의 계획으로", "나에게 맞는 기록 방식", "하루의 기준은 오전 6시"]
    private let symbols = ["checklist", "clock.badge.checkmark", "sun.horizon"]
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("P2J 시작하기").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Text("\(step + 1) / 3").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            Image(systemName: symbols[step]).font(.system(size: 44, weight: .medium))
                .foregroundStyle(.teal).frame(width: 84, height: 84)
                .background(.teal.opacity(0.10), in: RoundedRectangle(cornerRadius: 24))
            Text(titles[step]).font(.largeTitle.bold())
            Group {
                if step == 0 {
                    Text("할 일을 적고 우선순위를 정해보세요. 작은 실행을 쌓아 P에서 J로, 나만의 리듬을 만들어요.")
                    tip("plus.circle", "할 일 추가", "하루만·매일·매주·기간 작업을 등록해요.")
                    tip("flag", "중요한 것부터", "우선순위와 하위 TODO로 작업을 나눠요.")
                } else if step == 1 {
                    Text("기본은 간단한 완료 체크예요. 시간이 필요하다면 상세 기록을 켜보세요.")
                    Toggle("상세 기록 모드로 시작", isOn: $detailed).toggleStyle(.switch)
                        .padding(18).background(.teal.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                    tip(detailed ? "timer" : "checkmark.circle", detailed ? "시작 → 종료" : "완료 체크", detailed ? "직접 시작하고 종료하면 시각과 소요 시간을 확인할 수 있어요." : "시간 입력 없이 할 일을 완료 표시해요.")
                    Text("언제든 P2J → 설정… (⌘,)에서 바꿀 수 있어요.").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("새벽에 끝낸 일도 전날의 기록으로 이어져요. 오전 6시부터 새로운 작업일이 시작됩니다.")
                    tip("moon", "자동으로 완료하지 않아요", "상세 모드에서 종료하지 않은 기록은 미완료로 남아요.")
                    tip("menubar.rectangle", "빠르게 확인하기", "메뉴 막대에서 체크하고, 위젯과 통계로 흐름을 확인해요.")
                }
            }
            .font(.body)
            Spacer(minLength: 0)
            HStack {
                Button("건너뛰기") { finish(applyMode: false) }.buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                if step > 0 { Button("이전") { step -= 1 } }
                Button(step == 2 ? "P2J 시작하기" : "다음") {
                    if step < 2 { step += 1 } else { finish(applyMode: true) }
                }
                .buttonStyle(.borderedProminent).tint(.teal).keyboardShortcut(.defaultAction)
            }
        }
        .padding(32).frame(width: 560, height: 550)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { step = 0; detailed = store.recordingMode == .detailed }
    }
    private func tip(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(.teal).frame(width: 24)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(detail).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    private func finish(applyMode: Bool) {
        if applyMode { store.setRecordingMode(detailed ? .detailed : .normal) }
        hasCompletedTutorial = true
        openWindow(id: "main")
        dismissWindow(id: "tutorial")
    }
}
