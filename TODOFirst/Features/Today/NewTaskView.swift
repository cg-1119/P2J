import SwiftUI
import AppKit

struct NewTaskView: View {
    @Environment(TaskStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @FocusState private var titleFocused: Bool
    @State private var title = ""
    @State private var note = ""
    @State private var repeatRule: TaskRepeat = .once
    @State private var priority: TaskPriority = .normal
    @State private var date = TaskClock.dayDate()

    @State private var endDate = TaskClock.dayDate()
    @State private var subtasks: [Subtask] = []
    private let editingItem: TodoItem?

    init(item: TodoItem? = nil) {
        editingItem = item
        _endDate = State(initialValue: item?.endDay?.date() ?? item?.startDay.date() ?? TaskClock.dayDate())
        _subtasks = State(initialValue: item?.subtasks ?? [])
        _title = State(initialValue: item?.title ?? "")
        _note = State(initialValue: item?.note ?? "")
        _repeatRule = State(initialValue: item?.repeatRule == .weekdays ? .daily : (item?.repeatRule ?? .once))
        _priority = State(initialValue: item?.priority ?? .normal)
        _date = State(initialValue: item?.startDay.date() ?? TaskClock.dayDate())
    }

    private var valid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (repeatRule != .period || TaskDay(endDate) >= TaskDay(date))
            && subtasks.allSatisfy { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.title.count <= 120 }
            && title.count <= 120 && note.count <= 2000 && store.isReady
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(editingItem == nil ? "새로운 할 일" : "할 일 수정").font(.title2.bold())
                Text(editingItem == nil ? "오늘 한 번, 또는 꾸준히 할 일을 정해보세요." : "변경할 내용을 확인하고 저장하세요.")
                    .foregroundStyle(.secondary)
            }
            .padding(24)

            Form {
                Section("무엇을 할까요?") {
                    LiveTitleField(text: $title)
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
                    if editingItem?.repeatRule == .weekdays {
                        Text("기존 평일 일정은 저장 시 선택한 새 일정으로 변경돼요. 취소하면 그대로 유지돼요.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Picker("일정", selection: $repeatRule) {
                        ForEach(TaskRepeat.selectable) { rule in
                            Text(rule.title).tag(rule)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("taskRepeat")

                    DatePicker(repeatRule == .once ? "할 날짜" : "시작일", selection: $date, displayedComponents: .date)
                        .accessibilityIdentifier("taskDate")
                    if repeatRule == .period {
                        DatePicker("종료일", selection: $endDate, displayedComponents: .date)
                        if TaskDay(endDate) < TaskDay(date) {
                            Text("종료일은 시작일 이후로 선택해주세요.").foregroundStyle(.red)
                        }
                    }
                    HStack {
                        Text(repeatRule.explanation)
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("오늘", action: { date = TaskClock.dayDate() })
                            .controlSize(.small)
                    }
                }
                Section("하위 TODO") {
                    ForEach($subtasks) { $subtask in
                        HStack {
                            TextField("하위 할 일", text: $subtask.title)
                            Button { subtasks.removeAll { $0.id == subtask.id } } label: { Image(systemName: "minus.circle") }
                                .buttonStyle(.borderless).accessibilityLabel("하위 할 일 삭제")
                        }
                    }
                    if subtasks.contains(where: { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || $0.title.count > 120 }) {
                        Text("하위 제목은 1~120자로 입력하거나 빈 항목을 삭제해주세요.").font(.caption).foregroundStyle(.red)
                    }
                    Button("하위 TODO 추가", systemImage: "plus") { subtasks.append(Subtask(title: "")) }
                    Text("하위 항목은 개별 체크하며, 상위 작업 완료는 직접 체크해요.").font(.caption).foregroundStyle(.secondary)
                }
                if editingItem != nil {
                    Section {
                        Text("반복 일정 전체에 적용돼요. 완료 기록은 유지되며, 날짜·반복 변경 시 과거 계획 수가 다시 계산돼요.")
                            .font(.caption).foregroundStyle(.secondary)
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
                Button(editingItem == nil ? "등록" : "저장") {
                    NSApp.keyWindow?.makeFirstResponder(nil)
                    let saved: Bool
                    if let editingItem {
                        saved = store.update(editingItem, title: title, note: note, repeatRule: repeatRule,
                                             startDate: date, priority: priority, endDate: repeatRule == .period ? endDate : nil, subtasks: subtasks)
                    } else {
                        saved = store.add(TodoItem(title: title, note: note, repeatRule: repeatRule,
                                                  startDate: date, priority: priority, endDate: repeatRule == .period ? endDate : nil, subtasks: subtasks))
                    }
                    if saved { dismiss() }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!valid)
                .accessibilityIdentifier("saveTask")
            }
            .padding(20)
        }
        .frame(width: 520, height: 720)
        .onAppear { titleFocused = true }
    }
}

/// 편집 중 공백·한글 조합을 매번 전달하고 활성 편집기의 문자열을 덮어쓰지 않습니다.
private struct LiveTitleField: NSViewRepresentable {
    @Binding var text: String
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = "할 일 제목"
        field.delegate = context.coordinator
        field.isContinuous = true
        field.setAccessibilityLabel("할 일 제목")
        return field
    }
    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        if field.currentEditor() == nil && field.stringValue != text { field.stringValue = text }
    }
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: LiveTitleField
        init(_ parent: LiveTitleField) { self.parent = parent }
        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }
        func controlTextDidEndEditing(_ notification: Notification) { controlTextDidChange(notification) }
    }
}
