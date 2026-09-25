import SwiftUI

private enum TaskFilter: String, CaseIterable, Identifiable {
    case today = "오늘", recurring = "반복 일정", all = "전체", statistics = "통계"
    var id: String { rawValue }
}

struct TodayView: View {
    @Environment(TaskStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @State private var filter: TaskFilter = .today
    @State private var showingNewTask = false
    @State private var editingItem: TodoItem?
    @State private var pendingDeletion: TodoItem?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            content(on: TaskClock.dayDate(for: context.date))
        }
        .sheet(isPresented: $showingNewTask) {
            NewTaskView()
                .environment(store)
        }
        .sheet(item: $editingItem) { item in
            NewTaskView(item: item)
                .environment(store)
        }
        .confirmationDialog("할 일을 삭제할까요?", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        ), titleVisibility: .visible) {
            if let item = pendingDeletion {
                Button("삭제", role: .destructive) {
                    store.remove(item)
                    pendingDeletion = nil
                }
            }
            Button("취소", role: .cancel) { pendingDeletion = nil }
        } message: {
            if let item = pendingDeletion {
                Text(item.repeatRule == .once || item.repeatRule == .period
                     ? "‘\(item.title)’ 항목을 삭제합니다."
                     : "‘\(item.title)’ 반복 일정이 앞으로 목록에 표시되지 않습니다. 과거 완료 기록은 통계에 남습니다.")
            }
        }
    }

    private func content(on date: Date) -> some View {
        let tasks = filtered(on: date)
        let todayItems = store.items.filter { $0.occurs(on: date) }
        let todayCount = todayItems.count
        let completedCount = todayItems.filter { $0.isCompleted(on: date) }.count
        return VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(date, format: .dateTime.month().day().weekday())
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("오늘, 중요한 것부터").font(.largeTitle.bold())
                    Text(todayCount == 0 ? "작은 일 하나부터 시작해보세요." : "오늘 \(todayCount)개 중 \(completedCount)개 완료했어요.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    showingNewTask = true
                } label: {
                    Label("할 일 추가", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut("n", modifiers: .command)
                .disabled(!store.isReady)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("보기").font(.subheadline.weight(.medium))
                Picker("보기", selection: $filter) {
                    ForEach(TaskFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: 340)
            }

            if let error = store.errorMessage {
                HStack {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.callout).foregroundStyle(.red)
                    Spacer()
                    Button("다시 불러오기") { store.reload() }
                }
                .padding(12)
                .background(.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }

            if filter == .statistics {
                StatisticsView(records: store.records, date: date)
            } else if tasks.isEmpty {
                ContentUnavailableView {
                    Label(emptyTitle, systemImage: filter == .recurring ? "repeat" : "checklist")
                } description: {
                    Text(emptyDescription)
                } actions: {
                    Button("첫 할 일 등록") { showingNewTask = true }
                        .disabled(!store.isReady)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(tasks) { item in
                            TaskRow(item: item, date: date,
                                    onToggle: { store.toggleCompletion(item) },
                                    onPriority: { store.setPriority($0, for: item) },
                                    onEdit: { editingItem = item },
                                    onDelete: { pendingDeletion = item })
                                .disabled(!store.isReady)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "internaldrive")
                Text("이 Mac에 저장됨")
                Button("위젯 보기") { openWindow(id: "widgets") }
                    .buttonStyle(.link)
                Spacer()
                Text("하루는 오전 6시에 시작돼요")
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(minWidth: 620, minHeight: 460)
    }

    private func filtered(on date: Date) -> [TodoItem] {
        let items = store.items.filter { item in
            switch filter {
            case .today: item.occurs(on: date)
            case .recurring: [.daily, .weekly, .weekdays].contains(item.repeatRule)
            case .all: true
            case .statistics: false
            }
        }
        return TodoItem.ordered(items, on: date)
    }

    private var emptyTitle: String {
        switch filter {
        case .today: "오늘 할 일을 등록해보세요"
        case .recurring: "꾸준히 하고 싶은 일이 있나요?"
        case .all: "아직 등록한 할 일이 없어요"
        case .statistics: "통계"
        }
    }

    private var emptyDescription: String {
        switch filter {
        case .today: "오늘 하루만 할 일도, 매일의 작은 습관도 좋아요."
        case .recurring: "매일·매주 반복할 일을 한 번만 등록하세요."
        case .all: "할 일 추가 버튼이나 ⌘N으로 시작하세요."
        case .statistics: "오늘의 기록을 확인하세요."
        }
    }
}

private struct TaskRow: View {
    @Environment(TaskStore.self) private var store
    let item: TodoItem
    let date: Date
    let onToggle: () -> Void
    let onPriority: (TaskPriority) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Toggle(isOn: Binding(get: { item.isCompleted(on: date) }, set: { _ in onToggle() })) {
                Text("\(item.title) 오늘 완료")
            }
            .labelsHidden()
            .toggleStyle(.checkbox)
            .disabled(!item.occurs(on: date))
            .help(item.occurs(on: date) ? "오늘 완료 표시 또는 취소" : "오늘 해당하지 않는 일정입니다")
            .padding(.top, 3)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.title).font(.headline).textSelection(.enabled)
                    .strikethrough(item.isCompleted(on: date))
                    .foregroundStyle(item.isCompleted(on: date) ? .secondary : .primary)
                if !item.note.isEmpty {
                    Text(item.note).font(.callout).foregroundStyle(.secondary)
                        .lineLimit(2).help(item.note)
                }
                HStack(spacing: 6) {
                    Text(item.repeatRule.title)
                    if let date = item.startDay.date() {
                        Text("·")
                        Text(date, format: .dateTime.year().month().day().weekday())
                        if item.repeatRule != .once { Text("시작") }
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
                if let end = item.endDay?.date(), item.repeatRule == .period {
                    Text("종료: \(end.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(.secondary)
                }
                TaskTimingView(item: item, date: date)
                ForEach(item.subtasks) { subtask in
                    Toggle(isOn: Binding(get: {
                        item.isSubtaskCompleted(subtask, on: date)
                    }, set: { _ in store.toggleSubtask(subtask.id, in: item) })) {
                        Text(subtask.title).font(.callout)
                    }
                    .toggleStyle(.checkbox)
                    .disabled(!item.occurs(on: date))
                }
            }
            Spacer(minLength: 8)
            TaskPriorityPicker(title: item.title, priority: Binding(get: { item.priority }, set: onPriority))
            Button(action: onEdit) { Image(systemName: "pencil") }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("할 일 수정")
                .accessibilityLabel("\(item.title) 수정")
            Button(action: onDelete) { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("할 일 삭제")
                .accessibilityLabel("\(item.title) 삭제")
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.quaternary))
    }
}

struct TaskTimingView: View {
    @State private var editingTime = false
    @Environment(TaskStore.self) private var store
    let item: TodoItem
    let date: Date

    var body: some View {
        let activity = item.activity(on: date)
        VStack(alignment: .leading, spacing: 5) {
            Button("시간 기록·수정", systemImage: "clock.badge") { editingTime = true }.buttonStyle(.borderless)
            if let start = activity?.startedAt {
                Label("시작 \(start.formatted(date: .abbreviated, time: .shortened))", systemImage: "play.circle")
            }
            if let finish = activity?.finishedAt {
                Label("완료 \(finish.formatted(date: .abbreviated, time: .shortened))", systemImage: "checkmark.circle")
                if let elapsed = activity?.elapsed {
                    Text("소요 \(TaskStatistics.durationLabel(elapsed)) · 휴식 포함 경과 시간")
                }
            } else if item.isCompleted(on: date) {
                Text("완료 · 시각 기록 없음")
            } else if activity?.startedAt != nil {
                Text("진행 중").foregroundStyle(.teal)
            }
            if activity?.startedAt == nil && !item.isCompleted(on: date) && item.occurs(on: date) {
                Button { store.start(item) } label: { Label("시작", systemImage: "play.fill") }
                    .buttonStyle(.borderless).foregroundStyle(.teal)
                    .accessibilityLabel("\(item.title) 시작")
            }
        }
        .font(.caption).foregroundStyle(.secondary)
        .contextMenu { Button("시간 기록·수정") { editingTime = true } }
        .sheet(isPresented: $editingTime) {
            TaskTimeEditor(item: item, date: date, isPresented: $editingTime).environment(store)
        }
    }
}

private struct TaskTimeEditor: View {
    @Environment(TaskStore.self) private var store
    @Binding private var isPresented: Bool
    let item: TodoItem
    @State private var workday: Date
    @State private var startedAt: Date
    @State private var finishedAt: Date
    @State private var hasStart: Bool
    @State private var hasFinish: Bool
    init(item: TodoItem, date: Date, isPresented: Binding<Bool>) {
        self.item = item
        _isPresented = isPresented
        let activity = item.activity(on: date)
        _workday = State(initialValue: date)
        _startedAt = State(initialValue: activity?.startedAt ?? .now)
        _finishedAt = State(initialValue: activity?.finishedAt ?? .now)
        _hasStart = State(initialValue: activity?.startedAt != nil)
        _hasFinish = State(initialValue: activity?.finishedAt != nil)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("시간 기록·수정").font(.title2.bold())
            Text(item.title).foregroundStyle(.secondary)
            TaskDateButton(label: "기록할 작업일", date: $workday)
                .onChange(of: workday) { _, day in
                    let activity = item.activity(on: day)
                    hasStart = activity?.startedAt != nil; hasFinish = activity?.finishedAt != nil
                    startedAt = activity?.startedAt ?? day; finishedAt = activity?.finishedAt ?? day
                }
            Toggle("시작 시각 기록", isOn: $hasStart)
            if hasStart { timeInput("실제 시작", value: $startedAt) }
            Toggle("완료 시각 기록", isOn: $hasFinish)
            if hasFinish { timeInput("실제 완료", value: $finishedAt) }
            Text("오전 6시 기준 작업일입니다. 완료 시각을 기록하면 완료 처리하며, 해제하면 해당 완료 기록도 취소됩니다. 소요 시간에는 휴식이 포함됩니다.")
                .font(.caption).foregroundStyle(.secondary)
            if let error = store.errorMessage { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("취소") { isPresented = false }.keyboardShortcut(.cancelAction)
                Button("저장") {
                    if store.recordTiming(item, workday: workday, startedAt: hasStart ? startedAt : nil,
                                          finishedAt: hasFinish ? finishedAt : nil) { isPresented = false }
                }.buttonStyle(.borderedProminent).tint(.teal).disabled(!hasStart && !hasFinish)
            }
        }.padding(24).frame(width: 520)
    }
    private func timeInput(_ label: String, value: Binding<Date>) -> some View {
        HStack(spacing: 12) {
            TaskDateButton(label: label, date: Binding(get: { value.wrappedValue }, set: { day in
                let clock = Calendar.current.dateComponents([.hour, .minute], from: value.wrappedValue)
                value.wrappedValue = Calendar.current.date(bySettingHour: clock.hour ?? 12,
                                                          minute: clock.minute ?? 0, second: 0, of: day)!
            }))
            DatePicker(label, selection: value, displayedComponents: .hourAndMinute)
                .labelsHidden().padding(12)
                .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
        }
    }

}
