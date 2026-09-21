import SwiftUI
import WidgetKit

struct TODOFirstEntry: TimelineEntry {
    let date: Date
}

struct TODOFirstProvider: TimelineProvider {
    func placeholder(in context: Context) -> TODOFirstEntry {
        TODOFirstEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (TODOFirstEntry) -> Void) {
        completion(TODOFirstEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TODOFirstEntry>) -> Void) {
        // 실제 데이터 연결 전까지 불필요한 갱신을 요청하지 않습니다.
        completion(Timeline(entries: [TODOFirstEntry(date: .now)], policy: .never))
    }
}

struct TODOFirstWidgetView: View {
    let entry: TODOFirstEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(AppIdentity.name, systemImage: "checklist")
                .font(.headline)
            Text(AppIdentity.tagline)
                .font(.subheadline)
            Spacer(minLength: 0)
            Text("위젯 준비 중")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

@main
struct TODOFirstWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppIdentity.widgetKind, provider: TODOFirstProvider()) { entry in
            TODOFirstWidgetView(entry: entry)
        }
        .configurationDisplayName("TODO First")
        .description("오늘의 중요한 할 일을 확인하는 위젯입니다. 현재 개발 중입니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
