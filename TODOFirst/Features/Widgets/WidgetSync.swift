import Foundation
import Observation
import WidgetKit

@MainActor @Observable
final class WidgetSync {
    private(set) var message: String?
    private(set) var lastUpdated: Date?

    func publish(_ records: [TodoItem]) {
        do {
            let snapshot = WidgetSnapshot(records: records)
            try WidgetSnapshotRepository.shared().save(snapshot)
            lastUpdated = snapshot.updatedAt
            message = nil
            WidgetCenter.shared.reloadTimelines(ofKind: AppIdentity.widgetKind)
        } catch {
            message = "위젯 연결을 완료하지 못했어요. 앱의 할 일은 정상적으로 저장됩니다. 개발 서명과 App Group 설정을 확인해주세요."
        }
    }
}
