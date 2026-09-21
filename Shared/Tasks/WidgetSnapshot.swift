import Foundation

/// 앱이 쓰고 위젯이 읽는 표시 전용 복사본입니다. 원본 저장소는 변경하지 않습니다.
struct WidgetSnapshot: Codable, Equatable {
    let version: Int
    let updatedAt: Date
    let items: [TodoItem]

    init(records: [TodoItem], updatedAt: Date = .now) {
        version = 1
        self.updatedAt = updatedAt
        // 보관된 항목과 메모는 위젯에 전달하지 않습니다.
        items = records.filter { $0.archivedOn == nil }.map { item in
            var item = item
            item.note = ""
            return item
        }
    }
}

struct WidgetSnapshotRepository {
    let fileURL: URL

    enum SnapshotError: LocalizedError {
        case setupRequired, invalidSnapshot
        var errorDescription: String? {
            switch self {
            case .setupRequired: "위젯 연결에 개발 서명과 App Group 설정이 필요합니다."
            case .invalidSnapshot: "위젯 데이터를 읽을 수 없습니다. 앱을 열어 다시 연결해주세요."
            }
        }
    }

    static func shared(bundle: Bundle = .main) throws -> Self {
        guard let identifier = bundle.object(forInfoDictionaryKey: "P2JAppGroup") as? String,
              let team = bundle.object(forInfoDictionaryKey: "P2JDeveloperTeam") as? String,
              team.count == 10, !team.contains("$"), team != "YOUR_TEAM_ID",
              identifier.hasPrefix(team + "."),
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
        else { throw SnapshotError.setupRequired }
        return Self(fileURL: container.appendingPathComponent("widget-snapshot.json"))
    }

    func load() throws -> WidgetSnapshot? {
        let data: Data
        do { data = try Data(contentsOf: fileURL) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return nil }
        let snapshot = try JSONDecoder().decode(WidgetSnapshot.self, from: data)
        guard snapshot.version == 1 else { throw SnapshotError.invalidSnapshot }
        return snapshot
    }

    func save(_ snapshot: WidgetSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }
}

struct WidgetDayModel {
    let date: Date
    let total: Int
    let completed: Int
    let remainingItems: [TodoItem]
    var remaining: Int { total - completed }
    var progress: Double { total == 0 ? 0 : Double(completed) / Double(total) }

    init(date: Date, records: [TodoItem], calendar: Calendar = .current) {
        self.date = date
        let today = records.filter { $0.archivedOn == nil && $0.occurs(on: date, calendar: calendar) }
        total = today.count
        completed = today.filter { $0.isCompleted(on: date, calendar: calendar) }.count
        remainingItems = today.filter { !$0.isCompleted(on: date, calendar: calendar) }
            .sorted {
                if $0.createdAt == $1.createdAt { return $0.id.uuidString < $1.id.uuidString }
                return $0.createdAt < $1.createdAt
            }
    }

    /// 갱신이 늦어져도 자정에 다음 날 일정으로 바뀌도록 미래 엔트리를 준비합니다.
    static func timelineDates(from date: Date, calendar: Calendar = .current) -> [Date] {
        [date] + (1...7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: calendar.startOfDay(for: date))
        }
    }
}
