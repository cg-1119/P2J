import SwiftUI
import Charts

struct StatisticsView: View {
    let records: [TodoItem]
    let date: Date
    @State private var days = 7
    @State private var completedOnly = false

    var body: some View {
        let model = WidgetDayModel(date: date, records: records)
        let today = DayStatistics(date: date, total: model.total, completed: model.completed)
        let history = TaskStatistics.recent(days, through: date, records: records.filter { $0.repeatRule != .period })
        let counts = TaskStatistics.summary(days, through: date, records: records)
        let total = counts.total
        let completed = counts.completed
        let logs = TaskStatistics.logs(days, through: date, records: records)
        let measured = logs.filter(\.completed).compactMap(\.elapsed)
        let previousEnd = Calendar.current.date(byAdding: .day, value: -days, to: date)!
        let previous = TaskStatistics.summary(days, through: previousEnd, records: records).completed
        let difference = completed - previous
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

                HStack(spacing: 16) {
                    metric("하루 작업", value: "\(counts.onceCompleted) / \(counts.onceTotal)건")
                    metric("반복 수행", value: "\(counts.recurringCompleted) / \(counts.recurringTotal)회")
                    metric("기간 작업", value: "\(counts.periodCompleted) / \(counts.periodTotal)건")
                }
                Text("기간 작업은 조회 기간과 겹치는 작업을 한 번만, 매일·매주 작업은 예정된 날짜마다 한 회로 계산합니다. 합계는 작업 건수와 반복 수행 횟수를 합친 값입니다.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 16) {
                    metric("기록된 총 소요", value: measured.isEmpty ? "기록 없음" : TaskStatistics.durationLabel(measured.reduce(0, +)))
                    metric("시간 기록 완료", value: "\(measured.count)건")
                }
                HStack(spacing: 16) {
                    metric("완료한 날", value: "\(Set(logs.filter(\.completed).map(\.day)).count) / \(days)일")
                    metric("평균 소요", value: measured.isEmpty ? "기록 없음" : TaskStatistics.durationLabel(measured.reduce(0, +) / Double(measured.count)))
                    metric("이전 \(days)일 대비", value: "\(difference > 0 ? "+" : "")\(difference)개")
                }
                Text("평균 소요는 시작·완료 시각이 모두 있는 \(measured.count)건의 경과 시간입니다. 휴식 시간도 포함되며, 실제 집중 시간을 뜻하지 않습니다.")
                    .font(.caption).foregroundStyle(.secondary)

                if total == 0 {
                    Text("선택한 기간에 계획한 일이 없어요. 첫 할 일을 등록해보세요.")
                        .foregroundStyle(.secondary).padding(.vertical, 12)
                }

                Text("일별 수행 · 하루 작업과 반복 일정").font(.headline)
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

                VStack(alignment: .leading, spacing: 14) {
                    Label("우선순위별 성과", systemImage: "flag").font(.headline)
                    ForEach(TaskPriority.allCases) { priority in
                        let group = TaskStatistics.summary(days, through: date, records: records.filter { $0.priority == priority })
                        let planned = group.total
                        let done = group.completed
                        HStack {
                            Text(priority.title).frame(width: 40, alignment: .leading)
                            ProgressView(value: Double(done), total: Double(max(planned, 1))).tint(.teal)
                            Text("\(done) / \(planned)건").monospacedDigit().frame(width: 90, alignment: .trailing)
                            Text(planned == 0 ? "—" : (Double(done) / Double(planned)).formatted(.percent.precision(.fractionLength(0))))
                                .frame(width: 50, alignment: .trailing)
                        }.font(.callout)
                    }
                    Text("현재 지정된 우선순위를 기준으로 분류합니다.").font(.caption).foregroundStyle(.secondary)
                }
                .padding(18).background(.teal.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))

                HStack {
                    Label("작업별 시간 기록", systemImage: "clock").font(.headline)
                    Spacer()
                    Toggle("완료만", isOn: $completedOnly).toggleStyle(.switch).controlSize(.small)
                }
                if logs.filter({ !completedOnly || $0.completed }).isEmpty {
                    Text("선택한 기간에 기록이 없어요. 목록에서 시작을 누르거나 완료를 체크해보세요.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                ForEach(logs.filter { !completedOnly || $0.completed }) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            Image(systemName: entry.completed ? "checkmark.circle.fill" : "play.circle.fill").foregroundStyle(.teal)
                            Text(entry.title).font(.headline).textSelection(.enabled)
                            Spacer()
                            Text(entry.completed ? "완료" : "시작 기록").font(.caption).foregroundStyle(.secondary)
                        }
                        if let workday = entry.day.date() {
                            Text("작업일 \(workday.formatted(date: .abbreviated, time: .omitted)) · 우선순위 \(entry.priority.title)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        HStack(alignment: .top, spacing: 24) {
                            timestamp("실제 시작", date: entry.startedAt)
                            timestamp("실제 완료", date: entry.finishedAt)
                        }
                        if let elapsed = entry.elapsed {
                            Label("소요 \(TaskStatistics.durationLabel(elapsed))", systemImage: "hourglass")
                                .font(.caption.weight(.medium)).foregroundStyle(.teal)
                        }
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(.quaternary))
                }
                Text("완료 기록은 완료한 작업일, 미완료 시작 기록은 시작한 작업일에 표시합니다. 이전 버전의 완료 날짜는 보존하며 시각을 추정하지 않습니다.")
                    .font(.caption).foregroundStyle(.secondary)
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
                Text("오늘을 포함한 기간입니다. 일별 차트와 일별 기록은 하루 작업·반복 수행 기준이며 기간 작업은 위의 별도 집계에 포함합니다. 삭제 전 일정과 완료 기록도 포함합니다. 시작일을 과거로 등록하면 해당 기간의 계획 수에도 반영됩니다.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
    }

    private func timestamp(_ label: String, date: Date?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(date?.formatted(date: .abbreviated, time: .shortened) ?? "시각 기록 없음")
                .font(.callout).textSelection(.enabled)
        }.frame(maxWidth: .infinity, alignment: .leading)
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
