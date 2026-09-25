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

/// 로컬 자동화 요청도 앱의 TaskStore를 거쳐 저장합니다.
struct TaskAutomationRequest: Codable {
    let id: UUID
    let operation: String
    var token: String?
    var taskID: UUID?
    var title: String?
    var note: String?
    var rule: TaskRepeat?
    var startDate: String?
    var endDate: String?
    var priority: TaskPriority?
    var subtasks: [String]?
    var subtaskID: UUID?
    var completed: Bool?
    var workday: String?
    var startedAt: String?
    var finishedAt: String?
    var days: Int?
}

enum TaskAutomation {
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    @MainActor static func execute(_ request: TaskAutomationRequest, store: TaskStore, now: Date = .now) throws -> Data {
        guard store.isReady else { throw Failure(message: store.errorMessage ?? "저장소 준비 실패") }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        func date(_ value: String?, fallback: Date) throws -> Date {
            guard let value else { return fallback }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.timeZone = .current
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.isLenient = false
            guard let parsed = formatter.date(from: value), formatter.string(from: parsed) == value else {
                throw Failure(message: "날짜는 YYYY-MM-DD 형식이어야 합니다.")
            }
            return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: parsed)!
        }
        func instant(_ value: String?) throws -> Date? {
            guard let value else { return nil }
            guard let parsed = ISO8601DateFormatter().date(from: value) else {
                throw Failure(message: "시각은 시간대가 포함된 ISO 8601 형식이어야 합니다.")
            }
            return parsed
        }
        func check(_ result: Bool) throws {
            if !result { throw Failure(message: store.errorMessage ?? "현재 일정에서 처리할 수 없는 요청입니다.") }
        }
        if request.operation == "list" { return try encoder.encode(store.items) }
        if request.operation == "stats" {
            let days = request.days ?? 7
            guard (1...366).contains(days) else { throw Failure(message: "days는 1~366입니다.") }
            let counts = TaskStatistics.summary(days, through: TaskClock.dayDate(for: now), records: store.records)
            let data = try encoder.encode(counts)
            var output = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            output["total"] = counts.total; output["completed"] = counts.completed
            let logs = TaskStatistics.logs(days, through: TaskClock.dayDate(for: now), records: store.records)
            output["logs"] = try JSONSerialization.jsonObject(with: encoder.encode(logs))
            let elapsed = logs.filter(\.completed).compactMap(\.elapsed)
            output["timedCompletions"] = elapsed.count
            output["recordedElapsedSeconds"] = elapsed.reduce(0, +)
            if !elapsed.isEmpty { output["averageElapsedSeconds"] = elapsed.reduce(0, +) / Double(elapsed.count) }
            return try JSONSerialization.data(withJSONObject: output, options: [.sortedKeys])
        }
        if request.operation == "add" {
            if let existing = store.records.first(where: { $0.id == request.id }) { return try encoder.encode(existing) }
            guard let title = request.title else { throw Failure(message: "title이 필요합니다.") }
            guard request.rule != .weekdays else { throw Failure(message: "평일 반복은 신규 등록할 수 없습니다.") }
            let start = try date(request.startDate, fallback: TaskClock.dayDate(for: now))
            let end = try request.endDate.map { try date($0, fallback: start) }
            let item = TodoItem(id: request.id, title: title, note: request.note ?? "", repeatRule: request.rule ?? .once,
                                startDate: start, priority: request.priority ?? .normal, endDate: end,
                                subtasks: (request.subtasks ?? []).map { Subtask(title: $0) })
            try check(store.add(item))
            return try encoder.encode(item)
        }
        guard let taskID = request.taskID, let item = store.items.first(where: { $0.id == taskID }) else {
            throw Failure(message: "list에서 확인한 taskID가 필요합니다.")
        }
        switch request.operation {
        case "start":
            let today = TaskClock.dayDate(for: now)
            if item.activity(on: today)?.startedAt == nil { try check(store.start(item, on: now)) }
        case "complete":
            guard let completed = request.completed else { throw Failure(message: "completed가 필요합니다.") }
            if item.isCompleted(on: TaskClock.dayDate(for: now)) != completed { try check(store.toggleCompletion(item, on: now)) }
        case "subtask":
            guard let id = request.subtaskID, let child = item.subtasks.first(where: { $0.id == id }),
                  let completed = request.completed else { throw Failure(message: "subtaskID와 completed가 필요합니다.") }
            if item.isSubtaskCompleted(child, on: TaskClock.dayDate(for: now)) != completed {
                try check(store.toggleSubtask(id, in: item, on: now))
            }
        case "update":
            guard request.rule != .weekdays else { throw Failure(message: "평일 반복으로 변경할 수 없습니다.") }
            try check(store.update(item, title: request.title ?? item.title, note: request.note ?? item.note,
                                   repeatRule: request.rule ?? item.repeatRule,
                                   startDate: date(request.startDate, fallback: item.startDay.date()!), priority: request.priority ?? item.priority,
                                   endDate: date(request.endDate, fallback: item.endDay?.date() ?? item.startDay.date()!),
                                   subtasks: nil))
        case "timing":
            try check(store.recordTiming(item, workday: date(request.workday, fallback: TaskClock.dayDate(for: now)),
                                         startedAt: instant(request.startedAt), finishedAt: instant(request.finishedAt), now: now))
        default: throw Failure(message: "지원하지 않는 operation입니다.")
        }
        return try encoder.encode(store.items.first { $0.id == taskID }!)
    }

    static func prepare() throws {
        let base = try TaskRepository.local().fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let tokenFile = base.appendingPathComponent("automation-token")
        if !FileManager.default.fileExists(atPath: tokenFile.path) {
            try Data((UUID().uuidString + UUID().uuidString).utf8).write(to: tokenFile, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tokenFile.path)
        }
    }

    @MainActor static func handle(_ url: URL, store: TaskStore) {
        guard url.scheme == "p2j", url.host == "automation",
              let encoded = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "request" })?.value,
              encoded.count < 100_000, let data = Data(base64Encoded: encoded),
              let request = try? JSONDecoder().decode(TaskAutomationRequest.self, from: data) else { return }
        do {
            let base = try TaskRepository.local().fileURL.deletingLastPathComponent()
            let token = try String(contentsOf: base.appendingPathComponent("automation-token"), encoding: .utf8)
            guard request.token == token else { return }
            let directory = base.appendingPathComponent("automation")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            let file = directory.appendingPathComponent(request.id.uuidString.lowercased() + ".json")
            // 동일 요청 ID는 재실행하지 않습니다. 클라이언트는 같은 ID의 응답을 다시 읽습니다.
            if FileManager.default.fileExists(atPath: file.path) { return }
            let response: [String: Any]
            do {
                let result = try execute(request, store: store)
                response = ["id": request.id.uuidString.lowercased(), "ok": true,
                            "data": try JSONSerialization.jsonObject(with: result)]
            } catch {
                response = ["id": request.id.uuidString.lowercased(), "ok": false, "error": error.localizedDescription]
            }
            try JSONSerialization.data(withJSONObject: response, options: [.sortedKeys]).write(to: file, options: .atomic)
        } catch { /* 응답 파일 쓰기 실패는 클라이언트에서 시간 초과로 보고합니다. */ }
    }
}
