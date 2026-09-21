import Foundation

/// 달력 날짜를 저장해 시간대가 바뀌어도 등록한 날짜가 이동하지 않게 합니다.
struct TaskDay: Codable, Equatable, Comparable, Sendable {
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

struct TodoItem: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var note: String
    var repeatRule: TaskRepeat
    var startDay: TaskDay
    let createdAt: Date

    init(id: UUID = UUID(), title: String, note: String = "", repeatRule: TaskRepeat = .once,
         startDate: Date = .now, createdAt: Date = .now, calendar: Calendar = .current) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        self.repeatRule = repeatRule
        self.startDay = TaskDay(startDate, calendar: calendar)
        self.createdAt = createdAt
    }

    func occurs(on date: Date, calendar: Calendar = .current) -> Bool {
        let day = TaskDay(date, calendar: calendar)
        guard day >= startDay else { return false }
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
