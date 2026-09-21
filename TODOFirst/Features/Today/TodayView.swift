import SwiftUI

private enum TaskFilter: String, CaseIterable, Identifiable {
    case today = "오늘", recurring = "반복 일정", all = "전체"
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
                     : "‘\(item.title)’ 반복 일정 전체가 삭제되며 앞으로 목록에 표시되지 않습니다.")
            }
        }
    }

    private func content(on date: Date) -> some View {
        let tasks = filtered(on: date)
        let todayCount = store.items.filter { $0.occurs(on: date) }.count
        return VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(date, format: .dateTime.month().day().weekday())
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("오늘, 중요한 것부터").font(.largeTitle.bold())
                    Text(todayCount == 0 ? "작은 일 하나부터 시작해보세요." : "오늘 할 일 \(todayCount)개가 기다리고 있어요.")
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

            Picker("보기", selection: $filter) {
                ForEach(TaskFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 340)

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

            if tasks.isEmpty {
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
                            TaskRow(item: item) { pendingDeletion = item }
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
            }
        }
        .sorted { $0.createdAt < $1.createdAt }
    }

    private var emptyTitle: String {
        switch filter {
        case .today: "오늘 할 일을 등록해보세요"
        case .recurring: "꾸준히 하고 싶은 일이 있나요?"
        case .all: "아직 등록한 할 일이 없어요"
        }
    }

    private var emptyDescription: String {
        switch filter {
        case .today: "오늘 하루만 할 일도, 매일의 작은 습관도 좋아요."
        case .recurring: "매일·평일·매주 반복할 일을 한 번만 등록하세요."
        case .all: "할 일 추가 버튼이나 ⌘N으로 시작하세요."
        }
    }
}

private struct TaskRow: View {
    let item: TodoItem
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: item.repeatRule == .once ? "calendar" : "repeat")
                .font(.title3)
                .foregroundStyle(item.repeatRule == .once ? Color.orange : Color.teal)
                .frame(width: 36, height: 36)
                .background((item.repeatRule == .once ? Color.orange : Color.teal).opacity(0.1),
                            in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 5) {
                Text(item.title).font(.headline).textSelection(.enabled)
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
