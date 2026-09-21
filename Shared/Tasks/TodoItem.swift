import Foundation

/// 실제 시각을 오전 6시에 시작하는 작업일의 정오로 변환합니다.
/// 날짜 선택값과 저장된 TaskDay는 달력 날짜 그대로 유지합니다.
enum TaskClock {
    static func dayDate(for instant: Date = .now, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: instant)
        let boundary = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: start)!
        let day = instant < boundary ? calendar.date(byAdding: .day, value: -1, to: start)! : start
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day)!
    }

    static func nextBoundary(after instant: Date, calendar: Calendar = .current) -> Date {
        calendar.nextDate(after: instant, matching: DateComponents(hour: 6, minute: 0, second: 0),
                          matchingPolicy: .nextTime)!
    }
}

/// 달력 날짜를 저장해 시간대가 바뀌어도 등록한 날짜가 이동하지 않게 합니다.
struct TaskDay: Codable, Hashable, Comparable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    init(_ date: Date, calendar: Calendar = .current) {
        year = calendar.component(.year, from: date)
        month = calendar.component(.month, from: date)
        day = calendar.component(.day, from: date)
    }

    func date(calendar: Calendar = .current) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

enum TaskRepeat: String, Codable, CaseIterable, Identifiable, Sendable {
    case once, daily, weekdays, weekly
    var id: String { rawValue }

    var title: String {
        switch self {
        case .once: "하루만"
        case .daily: "매일"
        case .weekdays: "평일마다"
        case .weekly: "매주"
        }
    }

    var symbol: String {
        switch self {
        case .once: "calendar"
        case .daily: "repeat"
        case .weekdays: "calendar.badge.clock"
        case .weekly: "arrow.trianglehead.2.clockwise.rotate.90"
        }
    }

    var explanation: String {
        switch self {
        case .once: "오늘 또는 지정한 날짜에 한 번만 표시해요."
        case .daily: "시작일부터 매일 오늘의 목록에 표시해요."
        case .weekdays: "시작일부터 월요일~금요일에 표시해요. 공휴일도 포함해요."
        case .weekly: "시작일과 같은 요일에 매주 표시해요."
        }
    }
}

enum TaskPriority: Int, Codable, CaseIterable, Identifiable, Sendable {
    case high = 0, normal = 1, low = 2
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .high: "높음"
        case .normal: "보통"
        case .low: "낮음"
        }
    }
}

struct TodoItem: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var note: String
    var repeatRule: TaskRepeat
    var priority: TaskPriority
    var startDay: TaskDay
    let createdAt: Date
    var completedDays: Set<TaskDay> = []
    var archivedOn: TaskDay?

    init(id: UUID = UUID(), title: String, note: String = "", repeatRule: TaskRepeat = .once,
         startDate: Date = .now, createdAt: Date = .now, priority: TaskPriority = .normal, calendar: Calendar = .current) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        self.repeatRule = repeatRule
        self.priority = priority
        self.startDay = TaskDay(startDate, calendar: calendar)
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, note, repeatRule, startDay, createdAt, completedDays, archivedOn, priority
    }

    // v1 파일에 없던 완료 기록은 빈 목록으로 읽습니다.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        note = try values.decode(String.self, forKey: .note)
        repeatRule = try values.decode(TaskRepeat.self, forKey: .repeatRule)
        priority = try values.decodeIfPresent(TaskPriority.self, forKey: .priority) ?? .normal
        startDay = try values.decode(TaskDay.self, forKey: .startDay)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        completedDays = try values.decodeIfPresent(Set<TaskDay>.self, forKey: .completedDays) ?? []
        archivedOn = try values.decodeIfPresent(TaskDay.self, forKey: .archivedOn)
    }

    /// 미완료 → 높은 우선순위 → 등록 순서로 정렬합니다.
    static func ordered(_ items: [TodoItem], on date: Date, calendar: Calendar = .current) -> [TodoItem] {
        items.sorted { lhs, rhs in
            let leftDone = lhs.isCompleted(on: date, calendar: calendar)
            let rightDone = rhs.isCompleted(on: date, calendar: calendar)
            if leftDone != rightDone { return !leftDone }
            if lhs.priority != rhs.priority { return lhs.priority.rawValue < rhs.priority.rawValue }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    func isCompleted(on date: Date, calendar: Calendar = .current) -> Bool {
        completedDays.contains(TaskDay(date, calendar: calendar))
    }

    func occurs(on date: Date, calendar: Calendar = .current) -> Bool {
        let day = TaskDay(date, calendar: calendar)
        guard day >= startDay else { return false }
        if let archivedOn, day >= archivedOn { return false }
        switch repeatRule {
        case .once: return day == startDay
        case .daily: return true
        case .weekdays: return (2...6).contains(calendar.component(.weekday, from: date))
        case .weekly:
            guard let start = startDay.date(calendar: calendar) else { return false }
            return calendar.component(.weekday, from: start) == calendar.component(.weekday, from: date)
        }
    }
}
