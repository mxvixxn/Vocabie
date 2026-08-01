import SwiftUI
import SwiftData

/// Create a new set, then jump straight into bulk word entry.
struct NewSetView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// The 단어장 the new set lands on. `nil` when it is made from the top of the
    /// list rather than from inside a 단어장 — it goes to 미분류 then.
    var notebook: Notebook? = nil

    @State private var title = ""
    @State private var detail = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("세트 정보") {
                    TextField("제목 (예: 1번-10번)", text: $title)
                    TextField("메모 (선택)", text: $detail)
                }
                Section {
                    Text(placement)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("새 세트")
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

    private var placement: String {
        let where_ = notebook.map { "‘\($0.title)’ 단어장에 들어가요. " } ?? ""
        return where_ + "다음 화면에서 CSV·엑셀·텍스트·마크다운을 붙여넣거나 파일로 불러와 단어를 한 번에 추가할 수 있어요."
    }

    private func createAndContinue() {
        let set = VocabSet(title: title.trimmed, detail: detail.trimmed)
        set.notebook = notebook
        notebook?.touch()
        context.insert(set)
        try? context.save()
        Haptics.success()
        dismiss()
    }
}
