import SwiftUI

private enum TaskFilter: String, CaseIterable, Identifiable {
    case today = "오늘", recurring = "반복 일정", all = "전체", statistics = "통계"
    var id: String { rawValue }
}

struct TodayView: View {
    @Environment(TaskStore.self) private var store
    @State private var filter: TaskFilter = .today
    @State private var showingNewTask = false
    @State private var pendingDeletion: TodoItem?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            content(on: context.date)
        }
        .sheet(isPresented: $showingNewTask) {
            NewTaskView()
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
                Text(item.repeatRule == .once
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
                Spacer()
                Text("반복 일정은 해당하는 날 자동으로 표시돼요")
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(minWidth: 620, minHeight: 460)
    }

    private func filtered(on date: Date) -> [TodoItem] {
        store.items.filter { item in
            switch filter {
            case .today: item.occurs(on: date)
            case .recurring: item.repeatRule != .once
            case .all: true
            case .statistics: false
            }
        }
        .sorted { $0.createdAt < $1.createdAt }
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
        case .recurring: "매일·평일·매주 반복할 일을 한 번만 등록하세요."
        case .all: "할 일 추가 버튼이나 ⌘N으로 시작하세요."
        case .statistics: "오늘의 기록을 확인하세요."
        }
    }
}

private struct TaskRow: View {
    let item: TodoItem
    let date: Date
    let onToggle: () -> Void
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
            }
            Spacer(minLength: 8)
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
