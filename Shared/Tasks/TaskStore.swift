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
        next[index].archivedOn = TaskDay(TaskClock.dayDate(for: date, calendar: calendar), calendar: calendar)
        return persist(next)
    }

    @discardableResult
    func toggleCompletion(_ item: TodoItem, on instant: Date = .now, calendar: Calendar = .current) -> Bool {
        let date = TaskClock.dayDate(for: instant, calendar: calendar)
        guard let index = records.firstIndex(where: { $0.id == item.id }),
              records[index].archivedOn == nil,
              records[index].occurs(on: date, calendar: calendar) else { return false }
        var next = records
        let day = TaskDay(date, calendar: calendar)
        let undo = next[index].isCompleted(on: date, calendar: calendar)
        if next[index].repeatRule == .period {
            if undo { next[index].completedDays.removeAll() }
            else { next[index].completedDays = [day] }
        } else if undo { next[index].completedDays.remove(day) }
        else { next[index].completedDays.insert(day) }
        let activityIndex = next[index].repeatRule == .period
            ? next[index].activities.indices.last
            : next[index].activities.lastIndex { $0.day == day }
        if let activityIndex {
            next[index].activities[activityIndex].finishedAt = undo ? nil : instant
            if undo && next[index].activities[activityIndex].startedAt == nil {
                next[index].activities.remove(at: activityIndex)
            }
        } else if !undo {
            next[index].activities.append(TaskActivity(day: day, finishedAt: instant))
        }
        return persist(next)
    }

    @discardableResult
    func start(_ item: TodoItem, on instant: Date = .now, calendar: Calendar = .current) -> Bool {
        let date = TaskClock.dayDate(for: instant, calendar: calendar)
        guard let index = records.firstIndex(where: { $0.id == item.id && $0.archivedOn == nil }),
              records[index].occurs(on: date, calendar: calendar),
              !records[index].isCompleted(on: date, calendar: calendar),
              records[index].activity(on: date, calendar: calendar)?.startedAt == nil else { return false }
        var next = records
        let day = TaskDay(date, calendar: calendar)
        let activityIndex = next[index].repeatRule == .period ? next[index].activities.indices.last
            : next[index].activities.lastIndex { $0.day == day }
        if let activityIndex { next[index].activities[activityIndex].startedAt = instant }
        else { next[index].activities.append(TaskActivity(day: day, startedAt: instant)) }
        return persist(next)
    }

    @discardableResult
    func recordTiming(_ item: TodoItem, workday: Date, startedAt: Date?, finishedAt: Date?,
                      now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let index = records.firstIndex(where: { $0.id == item.id && $0.archivedOn == nil }) else { return false }
        let current = records[index]
        let day = TaskDay(workday, calendar: calendar)
        guard current.occurs(on: workday, calendar: calendar),
              startedAt != nil || finishedAt != nil,
              startedAt.map({ $0 <= now }) ?? true, finishedAt.map({ $0 <= now }) ?? true,
              (startedAt == nil || finishedAt == nil || finishedAt! >= startedAt!),
              [startedAt, finishedAt].compactMap({ $0 }).allSatisfy({ instant in
                  let actualDay = TaskClock.dayDate(for: instant, calendar: calendar)
                  return current.repeatRule == .period ? current.occurs(on: actualDay, calendar: calendar)
                      : TaskDay(actualDay, calendar: calendar) == day
              }) else {
            errorMessage = "작업일에 해당하는 과거 시각을 입력해주세요. 완료 시각은 시작 이후여야 합니다."
            return false
        }
        var next = records
        let activityIndex = current.repeatRule == .period ? current.activities.indices.last
            : current.activities.lastIndex { $0.day == day }
        let activity = TaskActivity(day: day, startedAt: startedAt, finishedAt: finishedAt)
        if let activityIndex { next[index].activities[activityIndex] = activity }
        else { next[index].activities.append(activity) }
        if current.repeatRule == .period { next[index].completedDays.removeAll() }
        else { next[index].completedDays.remove(day) }
        if let finishedAt {
            next[index].completedDays.insert(TaskDay(TaskClock.dayDate(for: finishedAt, calendar: calendar), calendar: calendar))
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
                startDate: Date, priority: TaskPriority, endDate: Date? = nil, subtasks: [Subtask]? = nil, calendar: Calendar = .current) -> Bool {
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
        next[index].endDay = repeatRule == .period ? endDate.map { TaskDay($0, calendar: calendar) } : nil
        if let subtasks {
            next[index].subtasks = subtasks.map { draft in
                var result = draft
                result.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
                result.completedDays = records[index].subtasks.first { $0.id == draft.id }?.completedDays ?? []
                return result
            }
        }
        return persist(next)
    }

    @discardableResult
    func toggleSubtask(_ id: UUID, in item: TodoItem, on instant: Date = .now, calendar: Calendar = .current) -> Bool {
        let date = TaskClock.dayDate(for: instant, calendar: calendar)
        guard let i = records.firstIndex(where: { $0.id == item.id && $0.archivedOn == nil }),
              records[i].occurs(on: date, calendar: calendar),
              let j = records[i].subtasks.firstIndex(where: { $0.id == id }) else { return false }
        var next = records
        let day = TaskDay(date, calendar: calendar)
        if next[i].repeatRule == .period {
            if next[i].subtasks[j].completedDays.isEmpty { next[i].subtasks[j].completedDays = [day] }
            else { next[i].subtasks[j].completedDays = [] }
        } else if next[i].subtasks[j].completedDays.contains(day) { next[i].subtasks[j].completedDays.remove(day) }
        else { next[i].subtasks[j].completedDays.insert(day) }
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

