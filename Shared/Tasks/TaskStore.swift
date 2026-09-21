import Foundation
import Observation

@MainActor @Observable
final class TaskStore {
    private(set) var items: [TodoItem] = []
    private(set) var errorMessage: String?
    private(set) var isReady = false
    private let repository: TaskRepository?

    init(repository: TaskRepository? = nil) {
        do {
            self.repository = try repository ?? TaskRepository.local()
        } catch {
            self.repository = nil
            self.errorMessage = error.localizedDescription
        }
        reload()
    }

    func reload() {
        guard let repository else { return }
        do {
            items = try repository.load()
            isReady = true
            errorMessage = nil
        } catch {
            isReady = false
            errorMessage = "할 일을 불러오지 못했어요. 기존 파일을 보호하기 위해 변경을 멈췄습니다. \(error.localizedDescription)"
        }
    }

    @discardableResult
    func add(_ item: TodoItem) -> Bool {
        persist(items + [item])
    }

    @discardableResult
    func remove(_ item: TodoItem) -> Bool {
        persist(items.filter { $0.id != item.id })
    }

    private func persist(_ next: [TodoItem]) -> Bool {
        guard isReady, let repository else { return false }
        do {
            try repository.save(next)
            items = next
            errorMessage = nil
            return true
        } catch {
            errorMessage = "저장하지 못했어요. 입력 내용을 유지한 채 다시 시도해주세요. \(error.localizedDescription)"
            return false
        }
    }
}
