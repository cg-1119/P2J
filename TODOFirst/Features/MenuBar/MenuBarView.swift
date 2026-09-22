import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(TaskStore.self) private var store

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            content(on: TaskClock.dayDate(for: context.date))
        }
        .padding(18)
        .frame(width: 390)
    }

    private func content(on date: Date) -> some View {
        let tasks = TodoItem.ordered(store.items.filter { $0.occurs(on: date) }, on: date)
        let completed = tasks.filter { $0.isCompleted(on: date) }.count
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(AppIdentity.name, systemImage: "checklist").font(.headline)
                Spacer()
                Text(date, format: .dateTime.month().day().weekday())
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Text("오늘 할 일").font(.subheadline.bold())
                Spacer()
                Text("\(completed)/\(tasks.count) 완료")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            ProgressView(value: Double(completed), total: Double(max(tasks.count, 1)))
                .tint(.teal).accessibilityLabel("오늘 완료율")

            if let error = store.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                Button("다시 불러오기") { store.reload() }
            }

            if tasks.isEmpty {
                Label("오늘 할 일이 없어요. 앱에서 등록해보세요.", systemImage: "sun.max")
                    .font(.callout).foregroundStyle(.secondary).padding(.vertical, 14)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(tasks) { item in
                            HStack(alignment: .top, spacing: 10) {
                                Toggle(isOn: Binding(
                                    get: { item.isCompleted(on: date) },
                                    set: { _ in store.toggleCompletion(item) }
                                )) { Text("\(item.title) 오늘 완료") }
                                .labelsHidden().toggleStyle(.checkbox)
                                .padding(.top, 2)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.title).font(.callout.weight(.medium)).lineLimit(2)
                                        .strikethrough(item.isCompleted(on: date))
                                        .foregroundStyle(item.isCompleted(on: date) ? .secondary : .primary)
                                        .help(item.title)
                                    Text(item.repeatRule.title).font(.caption2).foregroundStyle(.secondary)
                                    if !item.subtasks.isEmpty {
                                        Text("하위 TODO \(item.subtasks.filter { item.isSubtaskCompleted($0, on: date) }.count)/\(item.subtasks.count)")
                                            .font(.caption2).foregroundStyle(.teal)
                                        ForEach(item.subtasks) { subtask in
                                            Toggle(isOn: Binding(
                                                get: { item.isSubtaskCompleted(subtask, on: date) },
                                                set: { _ in store.toggleSubtask(subtask.id, in: item) }
                                            )) {
                                                Text(subtask.title).font(.callout).fixedSize(horizontal: false, vertical: true)
                                                    .strikethrough(item.isSubtaskCompleted(subtask, on: date))
                                                    .foregroundStyle(item.isSubtaskCompleted(subtask, on: date) ? .secondary : .primary)
                                            }
                                            .toggleStyle(.checkbox)
                                            .accessibilityLabel("\(item.title), 하위 할 일 \(subtask.title)")
                                            .padding(.vertical, 3)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                TaskPriorityPicker(title: item.title, priority: Binding(
                                    get: { item.priority }, set: { store.setPriority($0, for: item) }
                                ))
                                .controlSize(.small)
                            }
                            .disabled(!store.isReady)
                            .padding(12)
                            .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(height: min(CGFloat(tasks.reduce(0) { $0 + 88 + $1.subtasks.count * 38 }), 420))
            }
            Text("미완료 · 우선순위 순으로 표시해요")
                .font(.caption2).foregroundStyle(.secondary)
            Divider()
            HStack {
                Button("앱 열기", systemImage: "macwindow") {
                    openWindow(id: "main")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut("o")
                Spacer()
                Button("종료", systemImage: "power") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }
        }
    }
}
