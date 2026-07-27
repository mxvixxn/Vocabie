import SwiftUI
import SwiftData

/// Add a new card or edit an existing one.
struct EditWordView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let set: VocabSet
    /// `nil` means we're adding a new card.
    let word: Vocab?

    @State private var term = ""
    @State private var meaning = ""
    @State private var note = ""

    private var isEditing: Bool { word != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("단어") {
                    TextField("영단어", text: $term)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("뜻", text: $meaning)
                    TextField("메모·발음·예문 (선택)", text: $note)
                }
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            delete()
                        } label: {
                            Label("이 단어 삭제", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "단어 편집" : "단어 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .disabled(term.trimmed.isEmpty || meaning.trimmed.isEmpty)
                }
            }
            .onAppear {
                if let word {
                    term = word.term
                    meaning = word.meaning
                    note = word.note
                }
            }
        }
    }

    private func save() {
        if let word {
            word.term = term.trimmed
            word.meaning = meaning.trimmed
            word.note = note.trimmed
        } else {
            let order = (set.words.map(\.order).max() ?? -1) + 1
            let vocab = Vocab(term: term.trimmed, meaning: meaning.trimmed, note: note.trimmed, order: order)
            // Insert before relating — see ImportWordsView.commit().
            context.insert(vocab)
            vocab.set = set
        }
        set.touch()
        try? context.save()
        Haptics.success()
        dismiss()
    }

    private func delete() {
        if let word {
            context.delete(word)
            set.touch()
            try? context.save()
            Haptics.nudge()
        }
        dismiss()
    }
}
