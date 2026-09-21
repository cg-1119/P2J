import XCTest
@testable import TODOFirstCore

final class WidgetTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }
    private func date(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: 12))!
    }
    private func task(_ title: String, rule: TaskRepeat = .daily) -> TodoItem {
        TodoItem(title: title, note: "private note", repeatRule: rule, startDate: date(21), createdAt: date(21), calendar: calendar)
    }

    func testSnapshotRoundTripExcludesArchivedRecordsAndNotes() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let repo = WidgetSnapshotRepository(fileURL: url)
        XCTAssertNil(try repo.load())
        var archived = task("deleted")
        archived.archivedOn = TaskDay(date(22), calendar: calendar)
        let snapshot = WidgetSnapshot(records: [task("active"), archived])
        try repo.save(snapshot)
        let loaded = try XCTUnwrap(repo.load())
        XCTAssertEqual(loaded, snapshot)
        XCTAssertEqual(loaded.items.count, 1)
        XCTAssertEqual(loaded.items[0].note, "")
    }

    func testDayModelMatchesTodayAndResetsDailyCompletion() {
        var recurring = task("daily")
        recurring.completedDays = [TaskDay(date(21), calendar: calendar)]
        let once = task("once", rule: .once)
        let today = WidgetDayModel(date: date(21), records: [recurring, once], calendar: calendar)
        XCTAssertEqual(today.total, 2)
        XCTAssertEqual(today.completed, 1)
        XCTAssertEqual(today.remainingItems.map(\.title), ["once"])
        let tomorrow = WidgetDayModel(date: date(22), records: [recurring, once], calendar: calendar)
        XCTAssertEqual(tomorrow.total, 1)
        XCTAssertEqual(tomorrow.completed, 0)
        XCTAssertEqual(tomorrow.remainingItems.map(\.title), ["daily"])
    }

    func testEmptyAndAllCompleteModels() {
        let empty = WidgetDayModel(date: date(21), records: [], calendar: calendar)
        XCTAssertEqual(empty.total, 0)
        XCTAssertEqual(empty.progress, 0)
        var done = task("done")
        done.completedDays = [TaskDay(date(21), calendar: calendar)]
        let full = WidgetDayModel(date: date(21), records: [done], calendar: calendar)
        XCTAssertEqual(full.progress, 1)
        XCTAssertTrue(full.remainingItems.isEmpty)
    }

    func testTimelineCrossesDSTAtLocalSixAM() {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let start = c.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 12))!
        let dates = WidgetDayModel.timelineDates(from: start, calendar: c)
        XCTAssertEqual(dates.count, 8)
        XCTAssertEqual(dates[0], start)
        XCTAssertTrue(dates.dropFirst().allSatisfy { c.component(.hour, from: $0) == 6 })
        XCTAssertEqual(dates[2].timeIntervalSince(dates[1]), 23 * 3600)
    }

    func testCorruptSnapshotReportsFailure() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("broken".utf8).write(to: url)
        XCTAssertThrowsError(try WidgetSnapshotRepository(fileURL: url).load())
    }

    @MainActor func testStorePublishesSuccessfulChangesOnly() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("tasks.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var published: [[TodoItem]] = []
        let store = TaskStore(repository: TaskRepository(fileURL: url), didChange: { published.append($0) })
        XCTAssertEqual(published.count, 1)
        let item = task("test")
        XCTAssertTrue(store.add(item))
        XCTAssertTrue(store.toggleCompletion(item, on: date(21), calendar: calendar))
        XCTAssertEqual(published.count, 3)
        XCTAssertTrue(published.last![0].isCompleted(on: date(21), calendar: calendar))
        XCTAssertFalse(store.add(TodoItem(title: " ")))
        XCTAssertEqual(published.count, 3)
    }
}
