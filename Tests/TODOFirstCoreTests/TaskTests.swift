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
            TodoItem(title: "  물 마시기  ", note: "  한 컵  ", repeatRule: rule, startDate: date(21), endDate: rule == .period ? date(23) : nil)
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

    @MainActor func testSixAMBoundaryPreservesOvernightCompletionAndNextDayResets() throws {
        let repo = repository()
        defer { try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent()) }
        let store = TaskStore(repository: repo)
        let task = item(.daily)
        XCTAssertTrue(store.add(task))
        let before = date(22, hour: 6).addingTimeInterval(-1)
        let boundary = date(22, hour: 6)
        XCTAssertEqual(TaskDay(TaskClock.dayDate(for: date(22, hour: 0), calendar: calendar), calendar: calendar), TaskDay(date(21), calendar: calendar))
        XCTAssertEqual(TaskDay(TaskClock.dayDate(for: before, calendar: calendar), calendar: calendar), TaskDay(date(21), calendar: calendar))
        XCTAssertEqual(TaskDay(TaskClock.dayDate(for: boundary, calendar: calendar), calendar: calendar), TaskDay(date(22), calendar: calendar))
        XCTAssertTrue(store.toggleCompletion(task, on: before, calendar: calendar))
        XCTAssertTrue(store.items[0].isCompleted(on: date(21), calendar: calendar))
        XCTAssertEqual(WidgetDayModel(date: before, records: store.records, calendar: calendar).completed, 1)
        XCTAssertEqual(WidgetDayModel(date: boundary, records: store.records, calendar: calendar).completed, 0)
        XCTAssertEqual(TaskStatistics.day(TaskClock.dayDate(for: before, calendar: calendar), records: store.records, calendar: calendar).completed, 1)
        XCTAssertEqual(WidgetDayModel.timelineDates(from: before, calendar: calendar)[1], boundary)
        XCTAssertEqual(WidgetDayModel.timelineDates(from: boundary, calendar: calendar)[1], date(23, hour: 6))
        XCTAssertTrue(store.remove(task, on: before, calendar: calendar))
        XCTAssertEqual(store.records[0].archivedOn, TaskDay(date(21), calendar: calendar))
    }

    func testSixAMBoundaryAcrossMonthAndWeekdayKeepsExplicitDates() {
        let overnight = date(1, month: 10, hour: 3)
        XCTAssertEqual(TaskDay(TaskClock.dayDate(for: overnight, calendar: calendar), calendar: calendar), TaskDay(date(30), calendar: calendar))
        let fridayTask = item(.weekdays)
        XCTAssertTrue(fridayTask.occurs(on: TaskClock.dayDate(for: date(26, hour: 5), calendar: calendar), calendar: calendar))
        XCTAssertFalse(fridayTask.occurs(on: TaskClock.dayDate(for: date(26, hour: 6), calendar: calendar), calendar: calendar))
        let explicit = TodoItem(title: "날짜 지정", startDate: date(22, hour: 0), calendar: calendar)
        XCTAssertEqual(explicit.startDay, TaskDay(date(22), calendar: calendar))
    }

    @MainActor func testPeriodBoundsCompletionAndStatistics() throws {
        let repo = repository()
        defer { try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent()) }
        let store = TaskStore(repository: repo)
        let task = TodoItem(title: "기간 작업", repeatRule: .period, startDate: date(21), endDate: date(23), calendar: calendar)
        XCTAssertTrue(store.add(task))
        XCTAssertFalse(task.occurs(on: date(20), calendar: calendar))
        XCTAssertTrue(task.occurs(on: date(21), calendar: calendar))
        XCTAssertTrue(task.occurs(on: date(23), calendar: calendar))
        XCTAssertFalse(task.occurs(on: date(24), calendar: calendar))
        XCTAssertTrue(store.toggleCompletion(task, on: date(22), calendar: calendar))
        XCTAssertFalse(store.items[0].isCompleted(on: date(21), calendar: calendar))
        XCTAssertTrue(store.items[0].isCompleted(on: date(23), calendar: calendar))
        XCTAssertEqual(WidgetDayModel(date: date(23), records: store.records, calendar: calendar).completed, 1)
        XCTAssertEqual(TaskStatistics.recent(7, through: date(27), records: store.records, calendar: calendar).reduce(0) { $0 + $1.completed }, 1)
        XCTAssertEqual(try repo.load(), store.records)
        XCTAssertTrue(store.toggleCompletion(task, on: date(23), calendar: calendar))
        XCTAssertFalse(store.items[0].isCompleted(on: date(23), calendar: calendar))
        XCTAssertFalse(store.update(task, title: task.title, note: "", repeatRule: .period, startDate: date(23), priority: .normal, endDate: date(21), calendar: calendar))
        XCTAssertEqual(store.items[0].startDay, task.startDay)
    }

    @MainActor func testSubtasksPersistResetAndPreserveConcurrentChecksOnEdit() throws {
        let repo = repository()
        defer { try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent()) }
        let store = TaskStore(repository: repo)
        let child = Subtask(title: "자료 조사")
        let task = TodoItem(title: "부모", repeatRule: .daily, startDate: date(21), subtasks: [child], calendar: calendar)
        XCTAssertTrue(store.add(task))
        XCTAssertTrue(store.toggleSubtask(child.id, in: task, on: date(22, hour: 5), calendar: calendar))
        XCTAssertEqual(store.items[0].subtasks[0].completedDays, [TaskDay(date(21), calendar: calendar)])
        XCTAssertFalse(store.items[0].isCompleted(on: date(21), calendar: calendar))
        XCTAssertTrue(store.items[0].isSubtaskCompleted(store.items[0].subtasks[0], on: date(21), calendar: calendar))
        XCTAssertFalse(store.items[0].isSubtaskCompleted(store.items[0].subtasks[0], on: date(22), calendar: calendar))
        var edited = child
        edited.title = "자료  조사 수정"
        XCTAssertTrue(store.update(task, title: "제목  띄어 쓰기", note: "", repeatRule: .daily, startDate: date(21), priority: .normal, subtasks: [edited], calendar: calendar))
        XCTAssertEqual(store.items[0].title, "제목  띄어 쓰기")
        XCTAssertEqual(store.items[0].subtasks[0].completedDays.count, 1)
        XCTAssertFalse(store.items[0].subtasks[0].completedDays.contains(TaskDay(date(22), calendar: calendar)))
        XCTAssertTrue(store.toggleSubtask(child.id, in: task, on: date(22, hour: 6), calendar: calendar))
        XCTAssertEqual(try repo.load().first?.subtasks[0].completedDays.count, 2)
        XCTAssertTrue(store.update(task, title: "부모", note: "", repeatRule: .daily, startDate: date(21), priority: .normal, subtasks: [], calendar: calendar))
        XCTAssertFalse(store.toggleSubtask(child.id, in: task, on: date(22), calendar: calendar))
    }

    @MainActor func testPeriodSubtasksPersistUntilUndoneAndFailedSaveKeepsState() throws {
        let repo = repository()
        defer { try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent()) }
        let store = TaskStore(repository: repo)
        let child = Subtask(title: "초안")
        let task = TodoItem(title: "마감 작업", repeatRule: .period, startDate: date(21), endDate: date(23), subtasks: [child], calendar: calendar)
        XCTAssertTrue(store.add(task))
        XCTAssertTrue(store.toggleSubtask(child.id, in: task, on: date(21), calendar: calendar))
        XCTAssertTrue(store.items[0].isSubtaskCompleted(store.items[0].subtasks[0], on: date(22), calendar: calendar))
        XCTAssertFalse(store.items[0].isSubtaskCompleted(store.items[0].subtasks[0], on: date(20), calendar: calendar))
        XCTAssertTrue(store.toggleSubtask(child.id, in: task, on: date(22), calendar: calendar))
        XCTAssertTrue(store.items[0].subtasks[0].completedDays.isEmpty)
        XCTAssertFalse(store.toggleSubtask(child.id, in: task, on: date(24), calendar: calendar))
        let before = store.records
        try FileManager.default.removeItem(at: repo.fileURL)
        try FileManager.default.createDirectory(at: repo.fileURL, withIntermediateDirectories: true)
        XCTAssertFalse(store.toggleSubtask(child.id, in: task, on: date(22), calendar: calendar))
        XCTAssertEqual(before, store.records)
    }

    func testLegacySchemaAndInvalidSubtaskValidation() throws {
        let repo = repository()
        defer { try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent()) }
        try repo.save([item(.weekdays)])
        var document = try JSONSerialization.jsonObject(with: Data(contentsOf: repo.fileURL)) as! [String: Any]
        var records = document["items"] as! [[String: Any]]
        records[0].removeValue(forKey: "subtasks")
        records[0].removeValue(forKey: "endDay")
        document["items"] = records
        document["version"] = 3
        try JSONSerialization.data(withJSONObject: document).write(to: repo.fileURL)
        let old = try XCTUnwrap(repo.load().first)
        XCTAssertTrue(old.subtasks.isEmpty)
        XCTAssertNil(old.endDay)
        XCTAssertEqual(old.repeatRule, .weekdays)
        XCTAssertFalse(TaskRepeat.selectable.contains(.weekdays))
        var invalid = old
        invalid.subtasks = [Subtask(title: "   ")]
        XCTAssertThrowsError(try repo.save([invalid]))
        let child = Subtask(title: "중복")
        invalid.subtasks = [child, child]
        XCTAssertThrowsError(try repo.save([invalid]))
    }

    @MainActor func testTimingTracksExactInstantsAcrossSixAMAndUndo() throws {
        let repo = repository()
        defer { try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent()) }
        let store = TaskStore(repository: repo)
        let task = item(.daily)
        XCTAssertTrue(store.add(task))
        let start = date(22, hour: 1), finish = date(22, hour: 2)
        XCTAssertTrue(store.start(task, on: start, calendar: calendar))
        XCTAssertFalse(store.start(task, on: finish, calendar: calendar))
        XCTAssertTrue(store.toggleCompletion(task, on: finish, calendar: calendar))
        let activity = try XCTUnwrap(store.items[0].activity(on: date(21), calendar: calendar))
        XCTAssertEqual(activity.startedAt, start)
        XCTAssertEqual(activity.finishedAt, finish)
        XCTAssertEqual(activity.elapsed, 3600)
        XCTAssertEqual(try repo.load()[0].activities, [activity])
        let logs = TaskStatistics.logs(1, through: date(21), records: store.records, calendar: calendar)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].elapsed, 3600)
        XCTAssertTrue(logs[0].completed)
        XCTAssertTrue(store.toggleCompletion(task, on: finish.addingTimeInterval(60), calendar: calendar))
        XCTAssertNil(store.items[0].activities[0].finishedAt)
        XCTAssertEqual(store.items[0].activities[0].startedAt, start)
        XCTAssertTrue(store.start(task, on: date(22, hour: 6), calendar: calendar))
        XCTAssertEqual(store.items[0].activities.count, 2)
    }

    @MainActor func testPeriodTimingSpansDaysAndCompletionWithoutStartIsUnknown() throws {
        let repo = repository()
        defer { try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent()) }
        let store = TaskStore(repository: repo)
        let task = TodoItem(title: "기간", repeatRule: .period, startDate: date(21), endDate: date(25), calendar: calendar)
        XCTAssertTrue(store.add(task))
        XCTAssertTrue(store.start(task, on: date(21, hour: 10), calendar: calendar))
        XCTAssertFalse(store.start(task, on: date(22), calendar: calendar))
        XCTAssertTrue(store.toggleCompletion(task, on: date(23, hour: 11), calendar: calendar))
        let logs = TaskStatistics.logs(1, through: date(23), records: store.records, calendar: calendar)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].elapsed, 49 * 3600)
        XCTAssertTrue(TaskStatistics.logs(1, through: date(22), records: store.records, calendar: calendar).isEmpty)
        let direct = item(.once)
        XCTAssertTrue(store.add(direct))
        XCTAssertTrue(store.toggleCompletion(direct, on: date(21), calendar: calendar))
        let entry = try XCTUnwrap(TaskStatistics.logs(1, through: date(21), records: store.records, calendar: calendar).first)
        XCTAssertNil(entry.startedAt)
        XCTAssertNotNil(entry.finishedAt)
        XCTAssertNil(entry.elapsed)
        XCTAssertTrue(store.toggleCompletion(direct, on: date(21), calendar: calendar))
        XCTAssertTrue(TaskStatistics.logs(1, through: date(21), records: store.records, calendar: calendar).isEmpty)
    }

    @MainActor func testTimingSurvivesEditingAndFailedWritesDoNotPublish() throws {
        let repo = repository()
        defer { try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent()) }
        let store = TaskStore(repository: repo)
        let task = item(.daily)
        XCTAssertTrue(store.add(task))
        XCTAssertTrue(store.start(task, on: date(21), calendar: calendar))
        XCTAssertTrue(store.update(task, title: "수정", note: "", repeatRule: .daily, startDate: date(21), priority: .high, calendar: calendar))
        XCTAssertEqual(store.items[0].activities[0].startedAt, date(21))
        let before = store.records
        try FileManager.default.removeItem(at: repo.fileURL)
        try FileManager.default.createDirectory(at: repo.fileURL, withIntermediateDirectories: true)
        XCTAssertFalse(store.toggleCompletion(task, on: date(21, hour: 13), calendar: calendar))
        XCTAssertFalse(store.start(task, on: date(22), calendar: calendar))
        XCTAssertEqual(store.records, before)
    }

    func testLegacyTimingIsNotInventedAndArchivedCompletionStillAppears() throws {
        var old = item(.once)
        old.completedDays = [TaskDay(date(21), calendar: calendar)]
        old.archivedOn = TaskDay(date(22), calendar: calendar)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as! [String: Any]
        json.removeValue(forKey: "activities")
        let restored = try JSONDecoder().decode(TodoItem.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(restored.activities.isEmpty)
        let logs = TaskStatistics.logs(7, through: date(23), records: [restored], calendar: calendar)
        XCTAssertEqual(logs.count, 1)
        XCTAssertTrue(logs[0].completed)
        XCTAssertNil(logs[0].startedAt)
        XCTAssertNil(logs[0].finishedAt)
        XCTAssertTrue(TaskStatistics.logs(0, through: date(23), records: [restored], calendar: calendar).isEmpty)
    }

    func testSummaryCountsPeriodOnceAndDailyPerOccurrence() {
        var period = TodoItem(title: "기간", repeatRule: .period, startDate: date(21), endDate: date(30), calendar: calendar)
        var daily = item(.daily)
        daily.completedDays = [TaskDay(date(21), calendar: calendar), TaskDay(date(22), calendar: calendar)]
        period.completedDays = [TaskDay(date(23), calendar: calendar)]
        let summary = TaskStatistics.summary(7, through: date(27), records: [period, daily], calendar: calendar)
        XCTAssertEqual(summary.periodTotal, 1)
        XCTAssertEqual(summary.periodCompleted, 1)
        XCTAssertEqual(summary.recurringTotal, 7)
        XCTAssertEqual(summary.recurringCompleted, 2)
        XCTAssertEqual(summary.total, 8)
        XCTAssertEqual(summary.completed, 3)
        XCTAssertEqual(TaskStatistics.summary(1, through: date(24), records: [period], calendar: calendar).periodTotal, 0)
        period.completedDays = []
        XCTAssertEqual(TaskStatistics.summary(7, through: date(27), records: [period], calendar: calendar).periodTotal, 1)
        XCTAssertEqual(TaskStatistics.summary(1, through: date(20), records: [period], calendar: calendar).periodTotal, 0)
        period.archivedOn = TaskDay(date(22), calendar: calendar)
        XCTAssertEqual(TaskStatistics.summary(1, through: date(23), records: [period], calendar: calendar).periodTotal, 0)
    }

    @MainActor func testManualTimingValidatesAndUpdatesCompletion() throws {
        let repo = repository()
        defer { try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent()) }
        let store = TaskStore(repository: repo)
        let task = item(.daily)
        XCTAssertTrue(store.add(task))
        XCTAssertTrue(store.recordTiming(task, workday: date(21), startedAt: date(21, hour: 23), finishedAt: date(22, hour: 2), now: date(25), calendar: calendar))
        XCTAssertTrue(store.items[0].isCompleted(on: date(21), calendar: calendar))
        XCTAssertEqual(store.items[0].activities[0].elapsed, 3 * 3600)
        let original = store.records
        XCTAssertFalse(store.recordTiming(task, workday: date(21), startedAt: date(22, hour: 6), finishedAt: nil, now: date(25), calendar: calendar))
        XCTAssertFalse(store.recordTiming(task, workday: date(21), startedAt: date(21, hour: 23), finishedAt: date(21, hour: 22), now: date(25), calendar: calendar))
        XCTAssertFalse(store.recordTiming(task, workday: date(26), startedAt: date(26), finishedAt: nil, now: date(25), calendar: calendar))
        XCTAssertEqual(store.records, original)
        XCTAssertTrue(store.recordTiming(task, workday: date(21), startedAt: date(21, hour: 22), finishedAt: nil, now: date(25), calendar: calendar))
        XCTAssertFalse(store.items[0].isCompleted(on: date(21), calendar: calendar))
        XCTAssertEqual(try repo.load(), store.records)
    }

    @MainActor func testAutomationIsIdempotentAndPreservesExistingFields() throws {
        let repo = repository()
        defer { try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent()) }
        let store = TaskStore(repository: repo)
        let add = TaskAutomationRequest(id: UUID(), operation: "add", title: "AI로 등록", note: "유지", rule: .daily, subtasks: ["하위"])
        _ = try TaskAutomation.execute(add, store: store)
        _ = try TaskAutomation.execute(add, store: store)
        XCTAssertEqual(store.items.count, 1)
        let update = TaskAutomationRequest(id: UUID(), operation: "update", taskID: add.id, title: "변경")
        _ = try TaskAutomation.execute(update, store: store)
        XCTAssertEqual(store.items[0].note, "유지")
        XCTAssertEqual(store.items[0].subtasks.count, 1)
        let done = TaskAutomationRequest(id: UUID(), operation: "complete", taskID: add.id, completed: true)
        _ = try TaskAutomation.execute(done, store: store)
        let finished = store.items[0].activities[0].finishedAt
        _ = try TaskAutomation.execute(done, store: store)
        XCTAssertEqual(store.items[0].activities[0].finishedAt, finished)
        let stats = try TaskAutomation.execute(TaskAutomationRequest(id: UUID(), operation: "stats", days: 7), store: store)
        let object = try JSONSerialization.jsonObject(with: stats) as! [String: Any]
        XCTAssertEqual(object["recurringCompleted"] as? Int, 1)
        XCTAssertThrowsError(try TaskAutomation.execute(TaskAutomationRequest(id: UUID(), operation: "stats", days: 0), store: store))
        XCTAssertThrowsError(try TaskAutomation.execute(TaskAutomationRequest(id: UUID(), operation: "add", title: "잘못된 날짜", startDate: "2026-02-30"), store: store))
        XCTAssertThrowsError(try TaskAutomation.execute(TaskAutomationRequest(id: UUID(), operation: "complete", taskID: UUID(), completed: true), store: store))
        XCTAssertEqual(store.items.count, 1)
    }

    @MainActor func testDetailedModeRequiresExplicitStartAndFinish() throws {
        let repo = repository()
        defer { try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent()) }
        let store = TaskStore(repository: repo)
        let task = item(.daily)
        XCTAssertTrue(store.add(task))
        store.setRecordingMode(.detailed)
        XCTAssertFalse(store.toggleCompletion(task, on: date(21), calendar: calendar))
        XCTAssertTrue(store.items[0].activities.isEmpty)
        XCTAssertFalse(store.recordTiming(task, workday: date(21), startedAt: nil, finishedAt: date(21), now: date(22), calendar: calendar))
        XCTAssertTrue(store.start(task, on: date(21, hour: 23), calendar: calendar))
        XCTAssertFalse(store.items[0].isCompleted(on: date(21), calendar: calendar))
        XCTAssertTrue(store.toggleCompletion(task, on: date(22, hour: 5), calendar: calendar))
        XCTAssertEqual(store.items[0].activities[0].elapsed, 6 * 3600)
        XCTAssertTrue(store.items[0].isCompleted(on: date(21), calendar: calendar))
        XCTAssertTrue(store.toggleCompletion(task, on: date(22, hour: 5), calendar: calendar))
        XCTAssertNil(store.items[0].activities[0].finishedAt)
        XCTAssertFalse(store.items[0].isCompleted(on: date(21), calendar: calendar))
    }

    @MainActor func testDetailedUnfinishedDailyRecordRemainsIncompleteAfterSixAM() throws {
        let repo = repository()
        defer { try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent()) }
        let store = TaskStore(repository: repo)
        let task = item(.daily)
        XCTAssertTrue(store.add(task))
        store.setRecordingMode(.detailed)
        XCTAssertTrue(store.start(task, on: date(21, hour: 23), calendar: calendar))
        XCTAssertFalse(store.toggleCompletion(task, on: date(22, hour: 6), calendar: calendar))
        XCTAssertTrue(store.start(task, on: date(22, hour: 6), calendar: calendar))
        XCTAssertTrue(store.toggleCompletion(task, on: date(22, hour: 7), calendar: calendar))
        XCTAssertFalse(store.items[0].isCompleted(on: date(21), calendar: calendar))
        XCTAssertTrue(store.items[0].isCompleted(on: date(22), calendar: calendar))
        let logs = TaskStatistics.logs(2, through: date(22), records: store.records, calendar: calendar)
        XCTAssertEqual(logs.filter(\.completed).count, 1)
        XCTAssertEqual(logs.filter(\.completed).compactMap(\.elapsed).reduce(0, +), 3600)
        XCTAssertNil(logs.first { !$0.completed }?.finishedAt)
        XCTAssertEqual(TaskStatistics.summary(2, through: date(22), records: store.records, calendar: calendar).recurringCompleted, 1)
        XCTAssertEqual(try repo.load(), store.records)
    }

    @MainActor func testDetailedPeriodRemainsOpenUntilExplicitFinish() throws {
        let repo = repository()
        defer { try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent()) }
        let store = TaskStore(repository: repo)
        let task = TodoItem(title: "기간", repeatRule: .period, startDate: date(21), endDate: date(25), calendar: calendar)
        XCTAssertTrue(store.add(task))
        store.setRecordingMode(.detailed)
        XCTAssertTrue(store.start(task, on: date(21, hour: 23), calendar: calendar))
        store.reload()
        XCTAssertFalse(store.items[0].isCompleted(on: date(22), calendar: calendar))
        XCTAssertNil(store.items[0].activities[0].finishedAt)
        XCTAssertEqual(TaskStatistics.summary(2, through: date(22), records: store.records, calendar: calendar).periodCompleted, 0)
        XCTAssertTrue(store.toggleCompletion(task, on: date(22, hour: 8), calendar: calendar))
        XCTAssertEqual(store.items[0].activities[0].elapsed, 9 * 3600)
        XCTAssertEqual(TaskStatistics.summary(2, through: date(22), records: store.records, calendar: calendar).periodCompleted, 1)
    }

    @MainActor func testGlobalRecordingModePersistsWithoutChangingTaskHistory() throws {
        let suite = "P2J-tests-\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suite))
        let repo = repository()
        defer {
            preferences.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent())
        }
        let store = TaskStore(repository: repo, preferences: preferences)
        XCTAssertEqual(store.recordingMode, .normal)
        let task = item(.daily)
        XCTAssertTrue(store.add(task))
        XCTAssertTrue(store.toggleCompletion(task, on: date(21), calendar: calendar))
        let before = store.records
        store.setRecordingMode(.detailed)
        XCTAssertEqual(TaskStore(repository: repo, preferences: preferences).recordingMode, .detailed)
        XCTAssertEqual(store.records, before)
        store.setRecordingMode(.normal)
        XCTAssertEqual(store.records, before)
        XCTAssertTrue(store.toggleCompletion(task, on: date(22), calendar: calendar))
    }

    @MainActor func testAutomationCannotBypassDetailedStartRequirement() throws {
        let repo = repository()
        defer { try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent()) }
        let store = TaskStore(repository: repo)
        let task = TodoItem(title: "상세 모드", startDate: TaskClock.dayDate())
        XCTAssertTrue(store.add(task))
        store.setRecordingMode(.detailed)
        let finish = TaskAutomationRequest(id: UUID(), operation: "complete", taskID: task.id, completed: true)
        XCTAssertThrowsError(try TaskAutomation.execute(finish, store: store))
        _ = try TaskAutomation.execute(TaskAutomationRequest(id: UUID(), operation: "start", taskID: task.id), store: store)
        _ = try TaskAutomation.execute(finish, store: store)
        XCTAssertNotNil(store.items[0].activities[0].startedAt)
        XCTAssertNotNil(store.items[0].activities[0].finishedAt)
    }

    @MainActor func testIdleClockOnlyChangesAtWorkdayBoundaryAndDoesNotWriteRecords() throws {
        let repo = repository()
        defer { try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent()) }
        var publishes = 0
        let store = TaskStore(repository: repo, didChange: { _ in publishes += 1 })
        XCTAssertTrue(store.add(item(.daily)))
        let before = try Data(contentsOf: repo.fileURL)
        let count = publishes
        _ = store.refreshWorkday(at: date(21, hour: 12), calendar: calendar)
        let workday = store.workday
        for seconds in stride(from: 0, to: 3600, by: 30) {
            XCTAssertFalse(store.refreshWorkday(at: date(21, hour: 12).addingTimeInterval(Double(seconds)), calendar: calendar))
        }
        XCTAssertFalse(store.refreshWorkday(at: date(22, hour: 5), calendar: calendar))
        XCTAssertEqual(store.workday, workday)
        XCTAssertTrue(store.refreshWorkday(at: date(22, hour: 6), calendar: calendar))
        XCTAssertEqual(TaskDay(store.workday, calendar: calendar), TaskDay(date(22), calendar: calendar))
        // 며칠간 잠든 뒤 깨어나도 중간 타이머를 재생하지 않고 현재 작업일로 이동합니다.
        XCTAssertTrue(store.refreshWorkday(at: date(25, hour: 8), calendar: calendar))
        XCTAssertEqual(TaskDay(store.workday, calendar: calendar), TaskDay(date(25), calendar: calendar))
        XCTAssertEqual(publishes, count)
        XCTAssertEqual(try Data(contentsOf: repo.fileURL), before)
    }

    @MainActor func testSelectingCurrentPriorityDoesNotRepublish() throws {
        let repo = repository()
        defer { try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent()) }
        var publishes = 0
        let store = TaskStore(repository: repo, didChange: { _ in publishes += 1 })
        let task = item(.once)
        XCTAssertTrue(store.add(task))
        let before = publishes
        XCTAssertTrue(store.setPriority(task.priority, for: task))
        XCTAssertEqual(publishes, before)
        XCTAssertTrue(store.setPriority(.high, for: task))
        XCTAssertEqual(publishes, before + 1)
    }

    @MainActor func testRepeatedCompletionInputPreservesTimingAndDoesNotPublish() throws {
        let repo = repository()
        defer { try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent()) }
        var publishes = 0
        let store = TaskStore(repository: repo, didChange: { _ in publishes += 1 })
        let snapshot = item(.daily)
        XCTAssertTrue(store.add(snapshot))
        store.setRecordingMode(.detailed)
        XCTAssertTrue(store.start(snapshot, on: date(21, hour: 10), calendar: calendar))
        XCTAssertTrue(store.setCompletion(true, for: snapshot, on: date(21), calendar: calendar))
        let saved = store.items
        let count = publishes
        // 두 창이 가진 오래된 스냅샷에서 같은 값을 전달해도 종료 시각을 덮어쓰지 않습니다.
        XCTAssertTrue(store.setCompletion(true, for: snapshot, on: date(21, hour: 13), calendar: calendar))
        XCTAssertEqual(store.items, saved)
        XCTAssertEqual(publishes, count)
        XCTAssertTrue(store.setCompletion(false, for: snapshot, on: date(21, hour: 14), calendar: calendar))
        let undone = store.items
        XCTAssertTrue(store.setCompletion(false, for: snapshot, on: date(21, hour: 15), calendar: calendar))
        XCTAssertEqual(store.items, undone)
        XCTAssertEqual(publishes, count + 1)
    }

    @MainActor func testSubtaskDesiredStateIsIdempotentForDailyAndPeriod() throws {
        for rule in [TaskRepeat.daily, .period] {
            let repo = repository()
            defer { try? FileManager.default.removeItem(at: repo.fileURL.deletingLastPathComponent()) }
            var publishes = 0
            let store = TaskStore(repository: repo, didChange: { _ in publishes += 1 })
            let child = Subtask(title: "하위 검증")
            let snapshot = TodoItem(title: "부모 검증", repeatRule: rule, startDate: date(21),
                                    endDate: rule == .period ? date(23) : nil, subtasks: [child], calendar: calendar)
            XCTAssertTrue(store.add(snapshot))
            XCTAssertTrue(store.setSubtaskCompletion(true, id: child.id, in: snapshot, on: date(21), calendar: calendar))
            let count = publishes
            XCTAssertTrue(store.setSubtaskCompletion(true, id: child.id, in: snapshot, on: date(21), calendar: calendar))
            XCTAssertEqual(publishes, count)
            XCTAssertTrue(store.setSubtaskCompletion(true, id: child.id, in: snapshot, on: date(22), calendar: calendar))
            XCTAssertEqual(publishes, count + (rule == .daily ? 1 : 0))
            XCTAssertTrue(store.setSubtaskCompletion(false, id: child.id, in: snapshot, on: date(22), calendar: calendar))
            let saved = store.items
            let undoneCount = publishes
            XCTAssertTrue(store.setSubtaskCompletion(false, id: child.id, in: snapshot, on: date(22), calendar: calendar))
            XCTAssertEqual(store.items, saved)
            XCTAssertEqual(publishes, undoneCount)
        }
    }

    func testOverviewHidesFinishedFiniteTasksButKeepsRecurringAndFutureTasks() {
        var once = item(.once)
        once.completedDays = [TaskDay(date(21), calendar: calendar)]
        var period = TodoItem(title: "완료한 기간 작업", repeatRule: .period, startDate: date(21), endDate: date(23), calendar: calendar)
        period.completedDays = [TaskDay(date(22), calendar: calendar)]
        var daily = item(.daily)
        daily.completedDays = [TaskDay(date(24), calendar: calendar)]
        let future = item(.once, day: 26)
        let overdue = item(.once, day: 22)
        let unfinishedPeriod = TodoItem(title: "미완료 기간 작업", repeatRule: .period, startDate: date(21), endDate: date(23), calendar: calendar)
        var archived = item(.daily)
        archived.archivedOn = TaskDay(date(23), calendar: calendar)
        let records = [once, period, daily, future, overdue, unfinishedPeriod, archived]
        let visible = TodoItem.overviewItems(records, on: date(24), includeCompleted: false, calendar: calendar)
        XCTAssertEqual(Set(visible.map(\.id)), Set([daily, future, overdue, unfinishedPeriod].map(\.id)))
        let all = TodoItem.overviewItems(records, on: date(24), includeCompleted: true, calendar: calendar)
        XCTAssertEqual(Set(all.map(\.id)), Set(records.filter { $0.archivedOn == nil }.map(\.id)))
        // 과거 하루 작업을 오늘 미완료로 오판해 위로 올리지 않습니다.
        XCTAssertTrue(all.prefix(3).allSatisfy { !$0.isFinished && !$0.isCompleted(on: date(24), calendar: calendar) })
        XCTAssertEqual(once.completedDays, [TaskDay(date(21), calendar: calendar)])
        XCTAssertTrue(once.isFinished)
        XCTAssertTrue(period.isFinished)
        XCTAssertFalse(daily.isFinished)
    }

    func testOverdueStartsAtSixAMAfterDeadlineAndExcludesFinishedOrRepeatingTasks() {
        var once = item(.once)
        var period = TodoItem(title: "기간 작업", repeatRule: .period, startDate: date(20), endDate: date(21), calendar: calendar)
        let before = TaskClock.dayDate(for: date(22, hour: 5), calendar: calendar)
        let after = TaskClock.dayDate(for: date(22, hour: 6), calendar: calendar)
        XCTAssertFalse(once.isOverdue(on: before, calendar: calendar))
        XCTAssertFalse(period.isOverdue(on: before, calendar: calendar))
        XCTAssertTrue(once.isOverdue(on: after, calendar: calendar))
        XCTAssertTrue(period.isOverdue(on: after, calendar: calendar))
        XCTAssertFalse(item(.once, day: 23).isOverdue(on: after, calendar: calendar))
        for rule in [TaskRepeat.daily, .weekly, .weekdays] {
            XCTAssertFalse(item(rule).isOverdue(on: after, calendar: calendar))
        }
        once.completedDays = [TaskDay(date(21), calendar: calendar)]
        period.completedDays = [TaskDay(date(21), calendar: calendar)]
        XCTAssertFalse(once.isOverdue(on: after, calendar: calendar))
        XCTAssertFalse(period.isOverdue(on: after, calendar: calendar))
        var archived = item(.once)
        archived.archivedOn = TaskDay(date(21), calendar: calendar)
        XCTAssertFalse(archived.isOverdue(on: after, calendar: calendar))
    }

}
