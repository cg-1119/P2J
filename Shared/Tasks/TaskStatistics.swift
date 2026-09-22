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
