import Foundation

struct DayStatistics: Identifiable {
    let date: Date
    let total: Int
    let completed: Int
    var id: Date { date }
    var remaining: Int { total - completed }
    var rate: Double { total == 0 ? 0 : Double(completed) / Double(total) }
}

enum TaskStatistics {
    static func day(_ date: Date, records: [TodoItem], calendar: Calendar = .current) -> DayStatistics {
        // 기간 작업은 완료 다음 날부터 계획·실적을 중복 집계하지 않습니다.
        // 삭제했거나 일정을 바꿔도 실제 완료한 날짜의 기록은 남깁니다.
        let day = TaskDay(date, calendar: calendar)
        let scheduled = records.filter { item in
            let previouslyFinished = item.repeatRule == .period && item.completedDays.contains { $0 < day }
            return (item.occurs(on: date, calendar: calendar) && !previouslyFinished)
                || item.completedDays.contains(day)
        }
        return DayStatistics(date: calendar.startOfDay(for: date), total: scheduled.count,
                             completed: scheduled.filter { $0.isCompleted(on: date, calendar: calendar) }.count)
    }

    static func recent(_ count: Int, through date: Date, records: [TodoItem], calendar: Calendar = .current) -> [DayStatistics] {
        guard count > 0 else { return [] }
        let today = calendar.startOfDay(for: date)
        return (0..<count).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return self.day(day, records: records, calendar: calendar)
        }
    }
}

struct TaskLogEntry: Identifiable, Codable {
    var id: String { "\(taskID)-\(day.year)-\(day.month)-\(day.day)" }
    let taskID: UUID
    let title: String
    let priority: TaskPriority
    let day: TaskDay
    let startedAt: Date?
    let finishedAt: Date?
    let completed: Bool
    var elapsed: TimeInterval? {
        guard let startedAt, let finishedAt, finishedAt >= startedAt else { return nil }
        return finishedAt.timeIntervalSince(startedAt)
    }
}

extension TaskStatistics {
    static func logs(_ count: Int, through date: Date, records: [TodoItem], calendar: Calendar = .current) -> [TaskLogEntry] {
        guard count > 0, let first = calendar.date(byAdding: .day, value: 1 - count, to: date) else { return [] }
        let lower = TaskDay(first, calendar: calendar), upper = TaskDay(date, calendar: calendar)
        var result: [TaskLogEntry] = []
        for item in records {
            var rows: [TaskDay: TaskLogEntry] = [:]
            for day in item.completedDays {
                rows[day] = TaskLogEntry(taskID: item.id, title: item.title, priority: item.priority,
                                        day: day, startedAt: nil, finishedAt: nil, completed: true)
            }
            for activity in item.activities {
                let day = activity.finishedAt.map { TaskDay(TaskClock.dayDate(for: $0, calendar: calendar), calendar: calendar) } ?? activity.day
                rows[day] = TaskLogEntry(taskID: item.id, title: item.title, priority: item.priority,
                                        day: day, startedAt: activity.startedAt, finishedAt: activity.finishedAt,
                                        completed: item.completedDays.contains(day))
            }
            result += rows.values.filter { $0.day >= lower && $0.day <= upper }
        }
        return result.sorted {
            if $0.day != $1.day { return $0.day > $1.day }
            let left = $0.finishedAt ?? $0.startedAt ?? .distantPast
            let right = $1.finishedAt ?? $1.startedAt ?? .distantPast
            return left != right ? left > right : $0.id < $1.id
        }
    }

    static func durationLabel(_ seconds: TimeInterval) -> String {
        let minutes = Int(max(0, seconds) / 60)
        if minutes == 0 { return "1분 미만" }
        if minutes < 60 { return "\(minutes)분" }
        return "\(minutes / 60)시간 \(minutes % 60)분"
    }
}

struct TaskCountSummary: Codable {
    var onceTotal = 0
    var onceCompleted = 0
    var recurringTotal = 0
    var recurringCompleted = 0
    var periodTotal = 0
    var periodCompleted = 0
    var total: Int { onceTotal + recurringTotal + periodTotal }
    var completed: Int { onceCompleted + recurringCompleted + periodCompleted }
}

extension TaskStatistics {
    static func summary(_ count: Int, through date: Date, records: [TodoItem], calendar: Calendar = .current) -> TaskCountSummary {
        var result = TaskCountSummary()
        guard count > 0, let first = calendar.date(byAdding: .day, value: 1 - count, to: date) else { return result }
        let lower = TaskDay(first, calendar: calendar), upper = TaskDay(date, calendar: calendar)
        for item in records {
            if item.repeatRule == .period {
                let done = item.completedDays.contains { $0 >= lower && $0 <= upper }
                let finishedBefore = item.completedDays.contains { $0 < lower }
                let overlaps = item.startDay <= upper && (item.endDay ?? item.startDay) >= lower
                    && (item.archivedOn == nil || item.archivedOn! > lower)
                if done || (overlaps && !finishedBefore) {
                    result.periodTotal += 1
                    if done { result.periodCompleted += 1 }
                }
            } else {
                let history = recent(count, through: date, records: [item], calendar: calendar)
                let total = history.reduce(0) { $0 + $1.total }
                let completed = history.reduce(0) { $0 + $1.completed }
                if item.repeatRule == .once {
                    result.onceTotal += total; result.onceCompleted += completed
                } else {
                    result.recurringTotal += total; result.recurringCompleted += completed
                }
            }
        }
        return result
    }
}
