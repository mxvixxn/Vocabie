import SwiftUI
import SwiftData

/// Create a 단어장 — the shelf, not the words.
///
/// Takes a completion so the callers that need the result can have it: moving a set
/// straight onto the shelf it just made, for instance.
struct NewNotebookView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var onCreate: ((Notebook) -> Void)? = nil

    @State private var title = ""
    @State private var detail = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("단어장 정보") {
                    TextField("제목 (예: 모의고사 단어 정리)", text: $title)
                    TextField("메모 (선택)", text: $detail)
                }
                Section {
                    Text("단어장은 세트를 모아두는 큰 묶음이에요. 회차·강·교재처럼 한 덩어리로 들어오는 자료를 담고, 실제 학습은 그 안의 세트 단위로 해요.")
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
                    Button("완료") { create() }
                        .disabled(title.trimmed.isEmpty)
                }
            }
        }
    }

    private func create() {
        let notebook = Notebook(title: title.trimmed, detail: detail.trimmed)
        context.insert(notebook)
        try? context.save()
        Haptics.success()
        dismiss()
        onCreate?(notebook)
    }
}
