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
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: editingItem == nil ? "plus" : "pencil")
                    .font(.title2.weight(.semibold)).foregroundStyle(.teal)
                    .frame(width: 46, height: 46)
                    .background(.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 5) {
                    Text(editingItem == nil ? "작은 계획 하나" : "계획 다듬기").font(.title2.bold())
                    Text("오늘의 집중을 만들고, 하나씩 끝내보세요.").font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(24)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    card("무엇을 할까요?", symbol: "pencil.line") {
                        LiveTitleField(text: $title)
                            .focused($titleFocused)
                            .frame(height: 26).padding(12)
                            .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(titleFocused ? Color.teal.opacity(0.6) : Color.primary.opacity(0.08)))
                            .accessibilityIdentifier("taskTitle")
                        TextField("메모를 남겨보세요 (선택)", text: $note, axis: .vertical)
                            .textFieldStyle(.plain).lineLimit(2...4).padding(12)
                            .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
                            .accessibilityIdentifier("taskNote")
                        if title.count > 120 || note.count > 2000 {
                            warning("제목은 120자, 메모는 2,000자까지 입력해주세요.")
                        }
                    }
                    card("중요한 것부터", symbol: "flag") {
                        HStack(spacing: 8) {
                            ForEach(TaskPriority.allCases) { value in
                                choice(value.title, symbol: value == .high ? "flag.fill" : "flag", selected: priority == value) { priority = value }
                            }
                        }
                    }
                    card("언제 할까요?", symbol: "calendar") {
                        HStack(spacing: 8) {
                            ForEach(TaskRepeat.selectable) { rule in
                                choice(rule.title, symbol: rule == .weekly ? "repeat" : rule.symbol, selected: repeatRule == rule) { repeatRule = rule }
                            }
                        }
                        HStack(spacing: 12) {
                            TaskDateButton(label: repeatRule == .once ? "할 날짜" : "시작일", date: $date)
                            if repeatRule == .period {
                                Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                                TaskDateButton(label: "종료일", date: $endDate)
                            }
                        }
                        if repeatRule == .period && TaskDay(endDate) < TaskDay(date) {
                            warning("종료일은 시작일 이후로 선택해주세요.")
                        }
                        Text(repeatRule.explanation).font(.caption).foregroundStyle(.secondary)
                        if editingItem?.repeatRule == .weekdays {
                            Text("기존 평일 일정은 저장 시 선택한 새 일정으로 변경돼요. 취소하면 그대로 유지돼요.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    card("작게 나누면 더 쉬워요", symbol: "checklist") {
                        ForEach($subtasks) { $subtask in
                            HStack(spacing: 10) {
                                Image(systemName: "circle").foregroundStyle(.tertiary)
                                TextField("하위 할 일", text: $subtask.title).textFieldStyle(.plain)
                                Button { subtasks.removeAll { $0.id == subtask.id } } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                                    .buttonStyle(.plain).accessibilityLabel("하위 할 일 삭제")
                            }
                            .padding(12).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
                        }
                        if subtasks.contains(where: { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || $0.title.count > 120 }) {
                            warning("하위 제목은 1~120자로 입력하거나 빈 항목을 삭제해주세요.")
                        }
                        Button { subtasks.append(Subtask(title: "")) } label: {
                            Label("하위 TODO 추가", systemImage: "plus").font(.callout.weight(.medium)).foregroundStyle(.teal)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
                        }.buttonStyle(.plain)
                        Text("하위 항목은 개별 체크하며, 상위 작업 완료는 직접 체크해요.").font(.caption).foregroundStyle(.secondary)
                    }
                    if editingItem != nil {
                        Text("반복 일정 전체에 적용돼요. 완료 기록은 유지되며, 날짜·반복 변경 시 과거 계획 수가 다시 계산돼요.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let error = store.errorMessage { warning(error) }
                }
                .padding(.horizontal, 24).padding(.bottom, 24)
            }
            Divider()
            HStack {
                Label("이 Mac에 저장", systemImage: "lock").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("취소") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(editingItem == nil ? "할 일 등록" : "변경 저장", action: save)
                    .buttonStyle(.borderedProminent).tint(.teal)
                    .keyboardShortcut(.defaultAction).disabled(!valid)
                    .accessibilityIdentifier("saveTask")
            }
            .controlSize(.large).padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(width: 600, height: 740)
        .onAppear { titleFocused = true }
    }

    private func card<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Label(title, systemImage: symbol).font(.subheadline.weight(.semibold))
            content()
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.primary.opacity(0.06)))
    }

    private func choice(_ label: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: symbol).font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity).padding(.vertical, 11)
                .foregroundStyle(selected ? Color.teal : Color.secondary)
                .background(selected ? Color.teal.opacity(0.12) : Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.teal.opacity(0.4) : .clear))
        }
        .buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func warning(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.red)
    }

    private func save() {
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
}

struct TaskDateButton: View {
    let label: String
    @Binding var date: Date
    @State private var showingCalendar = false

    var body: some View {
        Button { showingCalendar = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "calendar").foregroundStyle(.teal)
                VStack(alignment: .leading, spacing: 4) {
                    Text(label).font(.caption).foregroundStyle(.secondary)
                    Text(date, format: .dateTime.year().month().day()).font(.callout.weight(.medium))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.down").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(12).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label), \(date.formatted(date: .long, time: .omitted))")
        .popover(isPresented: $showingCalendar, arrowEdge: .bottom) {
            TaskCalendar(date: $date) { showingCalendar = false }
        }
    }
}

private struct TaskCalendar: View {
    @Binding var date: Date
    let close: () -> Void
    @State private var month: Date
    private var calendar: Calendar { .current }

    init(date: Binding<Date>, close: @escaping () -> Void) {
        _date = date
        _month = State(initialValue: date.wrappedValue)
        self.close = close
    }

    var body: some View {
        let start = calendar.dateInterval(of: .month, for: month)!.start
        let count = calendar.range(of: .day, in: .month, for: start)!.count
        let offset = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
        VStack(spacing: 16) {
            HStack {
                Text(month, format: .dateTime.year().month(.wide)).font(.headline)
                Spacer()
                Button { move(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("이전 달")
                Button { move(1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("다음 달")
            }
            .buttonStyle(.borderless)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(0..<7, id: \.self) { index in
                    Text(calendar.shortStandaloneWeekdaySymbols[(index + calendar.firstWeekday - 1) % 7])
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(0..<(offset + count), id: \.self) { index in
                    if index < offset {
                        Color.clear.frame(height: 32)
                    } else {
                        let day = calendar.date(byAdding: .day, value: index - offset, to: start)!
                        let selected = calendar.isDate(day, inSameDayAs: date)
                        Button {
                            date = TaskDay(day).date()!
                            close()
                        } label: {
                            Text("\(index - offset + 1)").font(.callout.weight(selected ? .bold : .regular))
                                .frame(maxWidth: .infinity).frame(height: 32)
                                .foregroundStyle(selected ? Color.white : Color.primary)
                                .background(selected ? Color.teal : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(calendar.isDate(day, inSameDayAs: TaskClock.dayDate()) ? Color.teal : .clear))
                        }
                        .buttonStyle(.plain).accessibilityLabel(day.formatted(date: .complete, time: .omitted))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
            Divider()
            Button("오늘로 선택") { date = TaskClock.dayDate(); close() }.foregroundStyle(.teal).buttonStyle(.plain)
            Text("하루는 오전 6시에 시작돼요").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(20).frame(width: 300)
    }

    private func move(_ delta: Int) {
        let start = calendar.dateInterval(of: .month, for: month)!.start
        month = calendar.date(byAdding: .month, value: delta, to: start)!
    }
}

/// 편집 중 공백·한글 조합을 매번 전달하고 활성 편집기의 문자열을 덮어쓰지 않습니다.
private struct LiveTitleField: NSViewRepresentable {
    @Binding var text: String
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = "예: 이번 주 포트폴리오 마무리"
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 16, weight: .medium)
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
