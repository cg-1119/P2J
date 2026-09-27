import AppKit
import SwiftUI

/// SwiftUI Menu의 AppKitPopUpAdaptor가 메뉴 막대 창 복귀 시 appearance를
/// 재적용하며 갱신을 반복하는 경로를 피합니다. 사용자 선택만 모델에 전달합니다.
struct TaskPriorityPicker: NSViewRepresentable {
    let title: String
    let priority: TaskPriority
    let onSelect: (TaskPriority) -> Void
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.addItems(withTitles: TaskPriority.allCases.map(\.title))
        button.target = context.coordinator
        button.action = #selector(Coordinator.selectPriority(_:))
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.onSelect = onSelect
        let index = TaskPriority.allCases.firstIndex(of: priority)!
        if button.indexOfSelectedItem != index { button.selectItem(at: index) }
        if button.isEnabled != isEnabled { button.isEnabled = isEnabled }
        let size: NSControl.ControlSize = controlSize == .small ? .small : .regular
        if button.controlSize != size { button.controlSize = size }
        let label = "\(title) 우선순위"
        if button.accessibilityLabel() != label { button.setAccessibilityLabel(label) }
        let help = "우선순위: \(priority.title)"
        if button.toolTip != help { button.toolTip = help }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSPopUpButton, context: Context) -> CGSize? {
        nsView.intrinsicContentSize
    }

    final class Coordinator: NSObject {
        var onSelect: (TaskPriority) -> Void
        init(onSelect: @escaping (TaskPriority) -> Void) { self.onSelect = onSelect }

        @objc func selectPriority(_ sender: NSPopUpButton) {
            let index = sender.indexOfSelectedItem
            guard TaskPriority.allCases.indices.contains(index) else { return }
            onSelect(TaskPriority.allCases[index])
        }
    }
}
