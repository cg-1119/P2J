import SwiftUI

struct TodayView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(Date.now, format: .dateTime.month().day().weekday())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("오늘, 중요한 것부터")
                    .font(.largeTitle.bold())
            }

            ContentUnavailableView {
                Label("오늘의 할 일을 준비하고 있어요", systemImage: "checklist")
            } description: {
                Text("할 일 추가와 우선순위 기능이 이곳에 들어올 예정입니다.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Label("프로젝트 초기 구성 · 개발 중", systemImage: "hammer")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(minWidth: 540, minHeight: 380)
    }
}

#Preview {
    TodayView()
}
