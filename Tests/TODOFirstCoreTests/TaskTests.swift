import XCTest
@testable import TODOFirstCore

final class TaskTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }
    private func date(_ day: Int, month: Int = 9, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }
    private func item(_ rule: TaskRepeat, day: Int = 21) -> TodoItem {
        TodoItem(title: "테스트", repeatRule: rule, startDate: date(day), calendar: calendar)
    }
    private func repository() -> TaskRepository {
        TaskRepository(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("tasks.json"))
    }

    func testOnceMatchesEntireDayOnly() {
        let task = item(.once)
        XCTAssertTrue(task.occurs(on: date(21, hour: 0), calendar: calendar))
        XCTAssertTrue(task.occurs(on: date(21, hour: 23), calendar: calendar))
        XCTAssertFalse(task.occurs(on: date(20), calendar: calendar))
        XCTAssertFalse(task.occurs(on: date(22), calendar: calendar))
    }

    func testDailyStartsOnSelectedDayAndContinuesAcrossMonths() {
        let task = item(.daily)
        XCTAssertFalse(task.occurs(on: date(20), calendar: calendar))
        XCTAssertTrue(task.occurs(on: date(21), calendar: calendar))
        XCTAssertTrue(task.occurs(on: date(26), calendar: calendar))
        XCTAssertTrue(task.occurs(on: date(1, month: 10), calendar: calendar))
    }

    func testWeekdaysExcludeWeekendAndRespectStartDate() {
        let task = item(.weekdays)
        XCTAssertFalse(task.occurs(on: date(18), calendar: calendar))
        XCTAssertTrue(task.occurs(on: date(25), calendar: calendar))
        XCTAssertFalse(task.occurs(on: date(26), calendar: calendar))
        XCTAssertFalse(task.occurs(on: date(27), calendar: calendar))
        XCTAssertTrue(task.occurs(on: date(28), calendar: calendar))
    }

    func testWeeklyMatchesStartWeekday() {
        let task = item(.weekly)
        XCTAssertTrue(task.occurs(on: date(21), calendar: calendar))
        XCTAssertTrue(task.occurs(on: date(28), calendar: calendar))
        XCTAssertFalse(task.occurs(on: date(22), calendar: calendar))
        XCTAssertFalse(task.occurs(on: date(14), calendar: calendar))
    }

    func testCalendarDateDoesNotShiftWithTimeZone() {
        let task = item(.once)
        var other = calendar
        other.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let local = other.date(from: DateComponents(year: 2026, month: 9, day: 21, hour: 23))!
        XCTAssertTrue(task.occurs(on: local, calendar: other))
    }

    func testRoundTripPreservesRulesNotesAndIdentifiers() throws {
        let repo = repository()
        defer { try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent()) }
        let items = TaskRepeat.allCases.map { rule in
            TodoItem(title: "  물 마시기  ", note: "  한 컵  ", repeatRule: rule, startDate: date(21))
        }
        XCTAssertEqual(try repo.load(), [])
        try repo.save(items)
        XCTAssertEqual(try repo.load(), items)
        XCTAssertEqual(items.first?.title, "물 마시기")
        XCTAssertEqual(items.first?.note, "한 컵")
    }

    func testInvalidTitleCannotOverwriteFile() throws {
        let repo = repository()
        defer { try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent()) }
        try repo.save([item(.daily)])
        let original = try Data(contentsOf: repo.fileURL)
        XCTAssertThrowsError(try repo.save([TodoItem(title: " \n ")]))
        XCTAssertEqual(try Data(contentsOf: repo.fileURL), original)
    }

    @MainActor func testCorruptDataBlocksWritesAndPreservesOriginal() throws {
        let repo = repository()
        defer { try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: repo.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = Data("broken json".utf8)
        try original.write(to: repo.fileURL)
        let store = TaskStore(repository: repo)
        XCTAssertFalse(store.isReady)
        XCTAssertFalse(store.add(item(.daily)))
        XCTAssertNotNil(store.errorMessage)
        XCTAssertEqual(try Data(contentsOf: repo.fileURL), original)
    }

    @MainActor func testStorePersistsAcrossLaunchesAndDeletes() throws {
        let repo = repository()
        defer { try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent()) }
        let task = item(.weekdays)
        let store = TaskStore(repository: repo)
        XCTAssertTrue(store.add(task))
        let reopened = TaskStore(repository: repo)
        XCTAssertEqual(reopened.items, [task])
        XCTAssertTrue(reopened.remove(task))
        XCTAssertTrue(reopened.items.isEmpty)
        XCTAssertNotNil(try repo.load().first?.archivedOn)
    }

    @MainActor func testFailedSaveDoesNotPublishUnsavedItems() throws {
        let repo = repository()
        defer { try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent()) }
        let store = TaskStore(repository: repo)
        try FileManager.default.createDirectory(at: repo.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        // 저장 경로에 디렉터리가 생긴 실제 파일 시스템 실패를 재현합니다.
        try FileManager.default.createDirectory(at: repo.fileURL, withIntermediateDirectories: true)
        XCTAssertFalse(store.add(item(.once)))
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertNotNil(store.errorMessage)
    }
    @MainActor func testCompletionIsPerDayPersistsAndCanBeUndone() throws {
        let repo = repository()
        defer { try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent()) }
        let task = item(.daily)
        let store = TaskStore(repository: repo)
        XCTAssertTrue(store.add(task))
        XCTAssertTrue(store.toggleCompletion(task, on: date(21), calendar: calendar))
        let reopened = TaskStore(repository: repo)
        XCTAssertTrue(reopened.items[0].isCompleted(on: date(21), calendar: calendar))
        XCTAssertFalse(reopened.items[0].isCompleted(on: date(22), calendar: calendar))
        XCTAssertTrue(reopened.toggleCompletion(task, on: date(21), calendar: calendar))
        XCTAssertFalse(reopened.items[0].isCompleted(on: date(21), calendar: calendar))
    }

    @MainActor func testCompletionRejectsNonScheduledDayAndArchivedTask() {
        let repo = repository()
        defer { try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent()) }
        let store = TaskStore(repository: repo)
        let task = item(.weekdays)
        XCTAssertTrue(store.add(task))
        XCTAssertFalse(store.toggleCompletion(task, on: date(26), calendar: calendar))
        XCTAssertTrue(store.remove(task, on: date(22), calendar: calendar))
        XCTAssertFalse(store.toggleCompletion(task, on: date(21), calendar: calendar))
    }

    func testVersionOneDataLoadsWithoutCompletionFields() throws {
        let repo = repository()
        defer { try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent()) }
        let task = item(.once)
        try repo.save([task])
        var document = try JSONSerialization.jsonObject(with: Data(contentsOf: repo.fileURL)) as! [String: Any]
        var items = document["items"] as! [[String: Any]]
        items[0].removeValue(forKey: "completedDays")
        document["items"] = items
        document["version"] = 1
        try JSONSerialization.data(withJSONObject: document).write(to: repo.fileURL)
        let loaded = try repo.load()
        XCTAssertEqual(loaded[0].id, task.id)
        XCTAssertTrue(loaded[0].completedDays.isEmpty)
    }

    @MainActor func testFailedCompletionSaveKeepsPreviousState() throws {
        let repo = repository()
        defer { try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent()) }
        let store = TaskStore(repository: repo)
        let task = item(.daily)
        XCTAssertTrue(store.add(task))
        try FileManager.default.removeItem(at: repo.fileURL)
        try FileManager.default.createDirectory(at: repo.fileURL, withIntermediateDirectories: true)
        XCTAssertFalse(store.toggleCompletion(task, on: date(21), calendar: calendar))
        XCTAssertFalse(store.items[0].isCompleted(on: date(21), calendar: calendar))
    }

}
