import SwiftUI

struct TaskPriorityPicker: View {
    let title: String
    @Binding var priority: TaskPriority

    var body: some View {
        Picker("\(title) 우선순위", selection: $priority) {
            ForEach(TaskPriority.allCases) { value in
                Text(value.title).tag(value)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .fixedSize()
        .foregroundStyle(priority == .high ? Color.orange : Color.secondary)
        .help("우선순위: \(priority.title)")
    }
}
