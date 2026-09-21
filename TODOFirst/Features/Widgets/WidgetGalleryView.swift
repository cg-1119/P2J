import SwiftUI

struct WidgetGalleryView: View {
    @Environment(TaskStore.self) private var store
    @Environment(WidgetSync.self) private var sync

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let model = WidgetDayModel(date: context.date, records: store.records)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("오늘을 데스크톱에").font(.largeTitle.bold())
                    Text("실제 위젯과 같은 화면을 현재 할 일로 미리 확인하세요.")
                        .foregroundStyle(.secondary)
                    HStack(alignment: .top, spacing: 24) {
                        preview(model, compact: true)
                        preview(model, compact: false)
                    }
                    .padding(.vertical, 12)
                    Divider()
                    if let message = sync.message {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                    } else if let updated = sync.lastUpdated {
                        Label("위젯 데이터가 연결됐어요", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.teal)
                        Text("마지막 전달: \(updated.formatted(date: .omitted, time: .shortened))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Button("위젯 데이터 다시 보내기") { sync.publish(store.records) }
                        .disabled(!store.isReady)
                    Text("추가 방법").font(.headline)
                    Text("데스크톱을 보조 클릭 → 위젯 편집 → P2J 검색 → 소형 또는 중형 선택")
                    Text("이 미리보기는 macOS에 설치된 위젯이 아닙니다. 실제 위젯은 같은 개발 팀으로 서명된 앱과 App Group 설정이 필요합니다. 위젯을 누르면 앱에서 완료 체크할 수 있습니다. 갱신 시점은 macOS가 결정합니다.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(28)
            }
        }
        .frame(minWidth: 680, minHeight: 510)
    }

    private func preview(_ model: WidgetDayModel, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(compact ? "소형 · 남은 일" : "중형 · 오늘의 목록")
                .font(.subheadline.weight(.medium))
            WidgetCardContent(model: model, compact: compact)
                .padding(16)
                .frame(width: compact ? 170 : 360, height: 170)
                .background(.background, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(.quaternary))
        }
    }
}
