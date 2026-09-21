import SwiftUI
import WidgetKit

struct TODOFirstEntry: TimelineEntry {
    let date: Date
    let model: WidgetDayModel
    var notice: String? = nil
}

struct TODOFirstProvider: TimelineProvider {
    func placeholder(in context: Context) -> TODOFirstEntry { sample() }

    func getSnapshot(in context: Context, completion: @escaping (TODOFirstEntry) -> Void) {
        completion(context.isPreview ? sample() : entries().first!)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TODOFirstEntry>) -> Void) {
        completion(Timeline(entries: entries(), policy: .after(.now.addingTimeInterval(15 * 60))))
    }

    private func entries(now: Date = .now) -> [TODOFirstEntry] {
        do {
            guard let snapshot = try WidgetSnapshotRepository.shared().load() else {
                return [notice("P2J 앱을 한 번 열어주세요", date: now)]
            }
            return WidgetDayModel.timelineDates(from: now).map { date in
                TODOFirstEntry(date: date, model: WidgetDayModel(date: date, records: snapshot.items))
            }
        } catch {
            return [notice("앱에서 위젯 연결 설정을 확인해주세요", date: now)]
        }
    }

    private func notice(_ text: String, date: Date) -> TODOFirstEntry {
        TODOFirstEntry(date: date, model: WidgetDayModel(date: date, records: []), notice: text)
    }

    private func sample() -> TODOFirstEntry {
        let now = Date.now
        let tasks = [TodoItem(title: "책 10쪽 읽기", repeatRule: .daily, startDate: now),
                     TodoItem(title: "가볍게 산책하기", startDate: now)]
        return TODOFirstEntry(date: now, model: WidgetDayModel(date: now, records: tasks))
    }
}

struct TODOFirstWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TODOFirstEntry

    var body: some View {
        WidgetCardContent(model: entry.model, compact: family == .systemSmall, notice: entry.notice)
            .containerBackground(.background, for: .widget)
            .widgetURL(URL(string: "p2j://today"))
    }
}

@main
struct TODOFirstWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppIdentity.widgetKind, provider: TODOFirstProvider()) { entry in
            TODOFirstWidgetView(entry: entry)
        }
        .configurationDisplayName("P2J · 오늘 할 일")
        .description("남은 할 일과 완료 현황을 확인하세요. 누르면 P2J 앱이 열립니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
