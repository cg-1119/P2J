import SwiftUI

struct NewTaskView: View {
    @Environment(TaskStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @FocusState private var titleFocused: Bool
    @State private var title = ""
    @State private var note = ""
    @State private var repeatRule: TaskRepeat = .once
    @State private var priority: TaskPriority = .normal
    @State private var date = Date.now

    private var valid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && title.count <= 120 && note.count <= 2000 && store.isReady
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("새로운 할 일").font(.title2.bold())
                Text("오늘 한 번, 또는 꾸준히 할 일을 정해보세요.")
                    .foregroundStyle(.secondary)
            }
            .padding(24)

            Form {
                Section("무엇을 할까요?") {
                    TextField("할 일 제목", text: $title, prompt: Text("예: 책 10쪽 읽기"))
                        .focused($titleFocused)
                        .accessibilityIdentifier("taskTitle")
                    TextField("메모 (선택)", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                        .accessibilityIdentifier("taskNote")
                    if title.count > 120 || note.count > 2000 {
                        Text("제목은 120자, 메모는 2,000자까지 입력해주세요.")
                            .font(.caption).foregroundStyle(.red)
                    }
                }
                Section("무엇부터 할까요?") {
                    Picker("우선순위", selection: $priority) {
                        ForEach(TaskPriority.allCases) { priority in
                            Text(priority.title).tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("taskPriority")
                }
                Section("언제 할까요?") {
                    Picker("반복", selection: $repeatRule) {
                        ForEach(TaskRepeat.allCases) { rule in
                            Text(rule.title).tag(rule)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("taskRepeat")

                    DatePicker(repeatRule == .once ? "할 날짜" : "시작일", selection: $date, displayedComponents: .date)
                        .accessibilityIdentifier("taskDate")
                    HStack {
                        Text(repeatRule.explanation)
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("오늘", action: { date = .now })
                            .controlSize(.small)
                    }
                }
                if let error = store.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Text("이 Mac에 저장돼요")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("취소") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("등록") {
                    let item = TodoItem(title: title, note: note, repeatRule: repeatRule, startDate: date, priority: priority)
                    if store.add(item) { dismiss() }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!valid)
                .accessibilityIdentifier("saveTask")
            }
            .padding(20)
        }
        .frame(width: 520, height: 550)
        .onAppear { titleFocused = true }
    }
}
