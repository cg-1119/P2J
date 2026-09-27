import SwiftUI

struct TaskPriorityPicker: View {
    let title: String
    @Binding var priority: TaskPriority

    var body: some View {
        Menu {
            ForEach(TaskPriority.allCases) { value in
                Button {
                    if priority != value { priority = value }
                } label: {
                    if priority == value { Label(value.title, systemImage: "checkmark") }
                    else { Text(value.title) }
                }
            }
        } label: {
            Text(priority.title)
        }
        .fixedSize()
        .foregroundStyle(priority == .high ? Color.orange : Color.secondary)
        .accessibilityLabel("\(title) 우선순위")
        .help("우선순위: \(priority.title)")
    }
}
