import SwiftUI
import Charts

struct StatisticsView: View {
    let records: [TodoItem]
    let date: Date
    @State private var days = 7

    var body: some View {
        let today = TaskStatistics.day(date, records: records)
        let history = TaskStatistics.recent(days, through: date, records: records)
        let total = history.reduce(0) { $0 + $1.total }
        let completed = history.reduce(0) { $0 + $1.completed }
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("오늘의 달성률").font(.headline)
                        Spacer()
                        Text(today.total == 0 ? "할 일 없음" : today.rate.formatted(.percent.precision(.fractionLength(0))))
                            .font(.title2.bold()).monospacedDigit().foregroundStyle(.teal)
                    }
                    ProgressView(value: Double(today.completed), total: Double(max(today.total, 1)))
                        .tint(.teal)
                        .accessibilityLabel("오늘 완료율")
                    Text("\(today.total)개 중 \(today.completed)개 완료 · \(today.remaining)개 남음")
                        .font(.callout).foregroundStyle(.secondary)
                }
                .padding(18)
                .background(.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))

                HStack {
                    Text("꾸준함의 기록").font(.title3.bold())
                    Spacer()
                    Picker("통계 기간", selection: $days) {
                        Text("최근 7일").tag(7)
                        Text("최근 30일").tag(30)
                    }
                    .labelsHidden().pickerStyle(.segmented).frame(width: 220)
                }

                HStack(spacing: 16) {
                    metric("완료한 일", value: "\(completed)개")
                    metric("계획한 일", value: "\(total)개")
                    metric("완료율", value: total == 0 ? "—" : (Double(completed) / Double(total)).formatted(.percent.precision(.fractionLength(0))))
                }

                if total == 0 {
                    Text("선택한 기간에 계획한 일이 없어요. 첫 할 일을 등록해보세요.")
                        .foregroundStyle(.secondary).padding(.vertical, 12)
                }

                Chart(history) { day in
                    BarMark(x: .value("날짜", day.date, unit: .day), y: .value("할 일 수", day.completed))
                        .foregroundStyle(by: .value("상태", "완료"))
                    BarMark(x: .value("날짜", day.date, unit: .day), y: .value("할 일 수", day.remaining))
                        .foregroundStyle(by: .value("상태", "미완료"))
                }
                .chartForegroundStyleScale(["완료": Color.teal, "미완료": Color.gray.opacity(0.25)])
                .chartYScale(domain: 0...max(history.map(\.total).max() ?? 0, 1))
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: days == 7 ? 1 : 5)) {
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .frame(height: 190)
                .accessibilityLabel("일별 완료 및 미완료 할 일 수")

                Text("일별 기록").font(.headline)
                ForEach(history.reversed()) { day in
                    HStack {
                        Text(day.date, format: .dateTime.month().day().weekday())
                        Spacer()
                        Text(day.total == 0 ? "일정 없음" : "\(day.completed) / \(day.total)개 완료")
                            .foregroundStyle(.secondary).monospacedDigit()
                    }
                    .font(.callout)
                    Divider()
                }
                Text("오늘을 포함한 기간입니다. 하루에 할 일 하나를 1건으로 계산하며, 삭제 전 일정과 완료 기록도 포함합니다. 시작일을 과거로 등록하면 해당 기간의 계획 수에도 반영됩니다.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.bold()).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
    }
}
