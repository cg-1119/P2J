import SwiftUI

/// WidgetKit과 앱 내 미리보기에서 같은 레이아웃을 사용합니다.
struct WidgetCardContent: View {
    let model: WidgetDayModel
    let compact: Bool
    var notice: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("P2J", systemImage: "checklist").font(.caption.bold())
                Spacer(minLength: 4)
                Text(model.date, format: .dateTime.month().day())
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if let notice {
                Spacer(minLength: 0)
                Image(systemName: "rectangle.3.group").foregroundStyle(.teal)
                Text(notice).font(.caption).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            } else if compact {
                summary
                ProgressView(value: model.progress).tint(.teal)
                    .accessibilityLabel("오늘 완료율")
                taskList(limit: 2)
                Spacer(minLength: 0)
            } else {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        summary
                        ProgressView(value: model.progress).tint(.teal)
                            .accessibilityLabel("오늘 완료율")
                        Text("\(model.completed)/\(model.total) 완료")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(width: 94, alignment: .leading)
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        taskList(limit: 3)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var summary: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text("\(model.remaining)").font(.system(size: compact ? 28 : 34, weight: .bold, design: .rounded))
                .foregroundStyle(.teal).monospacedDigit()
            Text("개 남음").font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func taskList(limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if model.total == 0 {
                Label("오늘 할 일을 등록해보세요", systemImage: "plus.circle")
                    .font(.caption).foregroundStyle(.secondary)
            } else if model.remaining == 0 {
                Label("오늘 할 일 모두 완료!", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.medium)).foregroundStyle(.teal)
            } else {
                ForEach(model.remainingItems.prefix(limit)) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "circle").font(.system(size: 8)).foregroundStyle(.teal)
                        Text(item.title).font(.caption).lineLimit(1)
                    }
                    .privacySensitive()
                }
                if model.remaining > limit {
                    Text("+\(model.remaining - limit)개 더 · 앱에서 보기")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
        }
    }
}
