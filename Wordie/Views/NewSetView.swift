import SwiftUI
import SwiftData

/// Create a new set, then jump straight into bulk word entry.
struct NewSetView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var detail = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("단어장 정보") {
                    TextField("제목 (예: 수능 필수 어휘 Day 1)", text: $title)
                    TextField("메모 (선택)", text: $detail)
                }
                Section {
                    Text("다음 화면에서 CSV·엑셀·텍스트·마크다운을 붙여넣거나 파일로 불러와 단어를 한 번에 추가할 수 있어요.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("새 단어장")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("다음") { createAndContinue() }
                        .disabled(title.trimmed.isEmpty)
                }
            }
        }
    }

    private func createAndContinue() {
        let set = VocabSet(title: title.trimmed, detail: detail.trimmed)
        context.insert(set)
        try? context.save()
        Haptics.success()
        dismiss()
    }
}
