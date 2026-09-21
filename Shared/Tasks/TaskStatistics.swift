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
        // 삭제 전의 일정과 삭제 당일 이미 완료한 기록도 실적에 남깁니다.
        let scheduled = records.filter {
            $0.occurs(on: date, calendar: calendar) || $0.isCompleted(on: date, calendar: calendar)
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
