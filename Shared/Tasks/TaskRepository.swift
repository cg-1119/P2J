import Foundation

struct TaskRepository {
    let fileURL: URL

    static func local() throws -> Self {
        let directory = try FileManager.default.url(for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true)
        return Self(fileURL: directory.appendingPathComponent("TODOFirst", isDirectory: true)
            .appendingPathComponent("tasks.json"))
    }

    private struct Document: Codable {
        let version: Int
        let items: [TodoItem]
    }

    enum StorageError: LocalizedError {
        case unsupportedVersion, invalidData
        var errorDescription: String? {
            switch self {
            case .unsupportedVersion: "지원하지 않는 버전의 저장 파일입니다. 앱 업데이트를 확인해주세요."
            case .invalidData: "저장된 할 일 데이터가 올바르지 않습니다. 원본 파일은 유지됩니다."
            }
        }
    }

    func load() throws -> [TodoItem] {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return []
        }
        let document = try JSONDecoder().decode(Document.self, from: data)
        guard document.version == 1 else { throw StorageError.unsupportedVersion }
        try validate(document.items)
        return document.items
    }

    func save(_ items: [TodoItem]) throws {
        try validate(items)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(Document(version: 1, items: items))
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }

    private func validate(_ items: [TodoItem]) throws {
        guard Set(items.map(\.id)).count == items.count else { throw StorageError.invalidData }
        for item in items {
            guard !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  item.title.count <= 120, item.note.count <= 2000 else { throw StorageError.invalidData }
        }
    }
}
