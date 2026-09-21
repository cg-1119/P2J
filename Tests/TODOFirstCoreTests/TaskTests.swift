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

    func testStatisticsCountScheduledOccurrencesAndCompletion() {
        var daily = item(.daily)
        daily.completedDays = [TaskDay(date(21), calendar: calendar), TaskDay(date(22), calendar: calendar)]
        var once = item(.once)
        once.completedDays = [TaskDay(date(21), calendar: calendar)]
        let history = TaskStatistics.recent(7, through: date(27), records: [daily, once, item(.weekdays), item(.weekly)], calendar: calendar)
        XCTAssertEqual(history.count, 7)
        XCTAssertEqual(history.first?.date, calendar.startOfDay(for: date(21)))
        XCTAssertEqual(history.reduce(0) { $0 + $1.total }, 14)
        XCTAssertEqual(history.reduce(0) { $0 + $1.completed }, 3)
        XCTAssertEqual(history.last?.total, 1)
        XCTAssertEqual(history.first?.rate, 0.5)
    }

    func testArchivePreservesPastStatisticsButStopsFutureSchedule() {
        var task = item(.daily)
        task.completedDays = [TaskDay(date(21), calendar: calendar), TaskDay(date(22), calendar: calendar)]
        task.archivedOn = TaskDay(date(22), calendar: calendar)
        XCTAssertEqual(TaskStatistics.day(date(21), records: [task], calendar: calendar).completed, 1)
        XCTAssertEqual(TaskStatistics.day(date(22), records: [task], calendar: calendar).completed, 1)
        XCTAssertEqual(TaskStatistics.day(date(23), records: [task], calendar: calendar).total, 0)
    }

    func testEmptyStatisticsAndThirtyDayRange() {
        let history = TaskStatistics.recent(30, through: date(21), records: [], calendar: calendar)
        XCTAssertEqual(history.count, 30)
        XCTAssertTrue(history.allSatisfy { $0.total == 0 && $0.rate == 0 })
        XCTAssertEqual(history.last?.date, calendar.startOfDay(for: date(21)))
        XCTAssertTrue(TaskStatistics.recent(0, through: date(21), records: []).isEmpty)
    }

    func testLegacyDataDefaultsToNormalPriority() throws {
        var data = try JSONSerialization.jsonObject(with: JSONEncoder().encode(item(.daily))) as! [String: Any]
        data.removeValue(forKey: "priority")
        let restored = try JSONDecoder().decode(TodoItem.self, from: JSONSerialization.data(withJSONObject: data))
        XCTAssertEqual(restored.priority, .normal)
    }

    func testOrderingPutsIncompleteBeforeCompletedThenUsesPriority() {
        var high = item(.daily); high.title = "high"; high.priority = .high
        var low = item(.daily); low.title = "low"; low.priority = .low
        var done = item(.daily); done.title = "done"; done.priority = .high
        done.completedDays = [TaskDay(date(21), calendar: calendar)]
        let normal = item(.daily)
        let sorted = TodoItem.ordered([low, done, normal, high], on: date(21), calendar: calendar)
        XCTAssertEqual(sorted.map(\.id), [high.id, normal.id, low.id, done.id])
    }

    @MainActor func testPriorityPersistsAndPublishesWithoutLosingCompletion() throws {
        let repo = repository()
        defer { try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent()) }
        var published: [TodoItem] = []
        let store = TaskStore(repository: repo, didChange: { published = $0 })
        let task = item(.daily)
        XCTAssertTrue(store.add(task))
        XCTAssertTrue(store.toggleCompletion(task, on: date(21), calendar: calendar))
        XCTAssertTrue(store.setPriority(.high, for: task))
        XCTAssertEqual(published[0].priority, .high)
        let restored = TaskStore(repository: repo)
        XCTAssertEqual(restored.items[0].priority, .high)
        XCTAssertTrue(restored.items[0].isCompleted(on: date(21), calendar: calendar))
        XCTAssertTrue(restored.remove(task))
        XCTAssertFalse(restored.setPriority(.low, for: task))
    }

    @MainActor func testFailedPrioritySaveKeepsExistingValue() throws {
        let repo = repository()
        defer { try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent()) }
        let store = TaskStore(repository: repo)
        let task = item(.daily)
        XCTAssertTrue(store.add(task))
        try FileManager.default.removeItem(at: repo.fileURL)
        try FileManager.default.createDirectory(at: repo.fileURL, withIntermediateDirectories: true)
        XCTAssertFalse(store.setPriority(.high, for: task))
        XCTAssertEqual(store.items[0].priority, .normal)
    }

    func testWidgetUsesSamePriorityOrder() {
        var low = item(.daily); low.priority = .low
        var high = item(.daily); high.priority = .high
        let model = WidgetDayModel(date: date(21), records: [low, high], calendar: calendar)
        XCTAssertEqual(model.remainingItems.map(\.id), [high.id, low.id])
    }

    @MainActor func testEditingPreservesLatestCompletionAndIdentityAndPersistsSchedule() throws {
        let repo = repository()
        defer { try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent()) }
        var published: [TodoItem] = []
        let store = TaskStore(repository: repo, didChange: { published = $0 })
        let original = item(.daily)
        XCTAssertTrue(store.add(original))
        // 편집 창을 연 뒤 다른 화면에서 체크한 기록도 덮어쓰지 않습니다.
        XCTAssertTrue(store.toggleCompletion(original, on: date(21), calendar: calendar))
        XCTAssertTrue(store.update(original, title: "  수정한 제목  ", note: " 메모 ", repeatRule: .weekly,
                                   startDate: date(22), priority: .high, calendar: calendar))
        let restored = try XCTUnwrap(try repo.load().first)
        XCTAssertEqual(restored.id, original.id)
        XCTAssertEqual(restored.createdAt, original.createdAt)
        XCTAssertEqual(restored.title, "수정한 제목")
        XCTAssertEqual(restored.note, "메모")
        XCTAssertEqual(restored.priority, .high)
        XCTAssertEqual(restored.repeatRule, .weekly)
        XCTAssertFalse(restored.occurs(on: date(21), calendar: calendar))
        XCTAssertTrue(restored.occurs(on: date(29), calendar: calendar))
        XCTAssertTrue(restored.isCompleted(on: date(21), calendar: calendar))
        XCTAssertEqual(TaskStatistics.day(date(21), records: [restored], calendar: calendar).completed, 1)
        XCTAssertEqual(published, [restored])
        XCTAssertEqual(WidgetDayModel(date: date(22), records: published, calendar: calendar).remainingItems.first?.title, "수정한 제목")
    }

    @MainActor func testInvalidOrFailedEditKeepsOriginalAndRejectsDeletedItems() throws {
        let repo = repository()
        defer { try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent()) }
        let store = TaskStore(repository: repo)
        let original = item(.once)
        XCTAssertTrue(store.add(original))
        let savedData = try Data(contentsOf: repo.fileURL)
        for title in ["   ", String(repeating: "가", count: 121)] {
            XCTAssertFalse(store.update(original, title: title, note: "", repeatRule: .daily,
                                        startDate: date(22), priority: .low, calendar: calendar))
            XCTAssertEqual(store.items, [original])
            XCTAssertEqual(try Data(contentsOf: repo.fileURL), savedData)
        }
        XCTAssertFalse(store.update(original, title: "수정", note: String(repeating: "가", count: 2001),
                                    repeatRule: .daily, startDate: date(22), priority: .low))
        try FileManager.default.removeItem(at: repo.fileURL)
        try FileManager.default.createDirectory(at: repo.fileURL, withIntermediateDirectories: true)
        XCTAssertFalse(store.update(original, title: "수정", note: "", repeatRule: .daily,
                                    startDate: date(22), priority: .low))
        XCTAssertEqual(store.items, [original])
        XCTAssertNotNil(store.errorMessage)
        try FileManager.default.removeItem(at: repo.fileURL)
        XCTAssertTrue(store.remove(original))
        XCTAssertFalse(store.update(original, title: "수정", note: "", repeatRule: .daily,
                                    startDate: date(22), priority: .low))
        XCTAssertTrue(store.items.isEmpty)
    }

}
