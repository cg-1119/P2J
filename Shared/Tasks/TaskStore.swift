import Foundation
import Observation

@MainActor @Observable
final class TaskStore {
    private(set) var records: [TodoItem] = []
    var items: [TodoItem] { records.filter { $0.archivedOn == nil } }
    private(set) var errorMessage: String?
    private(set) var isReady = false
    private let repository: TaskRepository?
    private let didChange: ([TodoItem]) -> Void

    init(repository: TaskRepository? = nil, didChange: @escaping ([TodoItem]) -> Void = { _ in }) {
        self.didChange = didChange
        do {
            self.repository = try repository ?? TaskRepository.local()
        } catch {
            self.repository = nil
            self.errorMessage = error.localizedDescription
        }
        reload()
    }

    func reload() {
        guard let repository else { return }
        do {
            records = try repository.load()
            isReady = true
            errorMessage = nil
            didChange(records)
        } catch {
            isReady = false
            errorMessage = "할 일을 불러오지 못했어요. 기존 파일을 보호하기 위해 변경을 멈췄습니다. \(error.localizedDescription)"
        }
    }

    @discardableResult
    func add(_ item: TodoItem) -> Bool {
        persist(records + [item])
    }

    @discardableResult
    func remove(_ item: TodoItem, on date: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let index = records.firstIndex(where: { $0.id == item.id && $0.archivedOn == nil }) else { return false }
        var next = records
        next[index].archivedOn = TaskDay(date, calendar: calendar)
        return persist(next)
    }

    @discardableResult
    func toggleCompletion(_ item: TodoItem, on date: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let index = records.firstIndex(where: { $0.id == item.id }),
              records[index].archivedOn == nil,
              records[index].occurs(on: date, calendar: calendar) else { return false }
        var next = records
        let day = TaskDay(date, calendar: calendar)
        if next[index].completedDays.contains(day) {
            next[index].completedDays.remove(day)
        } else {
            next[index].completedDays.insert(day)
        }
        return persist(next)
    }

    @discardableResult
    func setPriority(_ priority: TaskPriority, for item: TodoItem) -> Bool {
        guard let index = records.firstIndex(where: { $0.id == item.id && $0.archivedOn == nil }) else { return false }
        var next = records
        next[index].priority = priority
        return persist(next)
    }

    /// 수정한 필드만 반영해 최신 완료 기록과 식별자를 유지합니다.
    @discardableResult
    func update(_ item: TodoItem, title: String, note: String, repeatRule: TaskRepeat,
                startDate: Date, priority: TaskPriority, calendar: Calendar = .current) -> Bool {
        guard let index = records.firstIndex(where: { $0.id == item.id && $0.archivedOn == nil }) else {
            errorMessage = "수정할 할 일을 찾지 못했어요. 목록을 다시 확인해주세요."
            return false
        }
        var next = records
        next[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        next[index].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        next[index].repeatRule = repeatRule
        next[index].startDay = TaskDay(startDate, calendar: calendar)
        next[index].priority = priority
        return persist(next)
    }

    private func persist(_ next: [TodoItem]) -> Bool {
        guard isReady, let repository else { return false }
        do {
            try repository.save(next)
            records = next
            errorMessage = nil
            didChange(records)
            return true
        } catch {
            errorMessage = "저장하지 못했어요. 입력 내용을 유지한 채 다시 시도해주세요. \(error.localizedDescription)"
            return false
        }
    }
}
