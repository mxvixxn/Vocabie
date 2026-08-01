import SwiftUI
import SwiftData

/// Moves one set onto a different 단어장 — or off every shelf, back to 미분류.
///
/// This is the screen that makes the hierarchy usable at all: sets made before there
/// were 단어장, and sets made in a hurry, all land unfiled and need a way in.
struct MoveSetView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    let set: VocabSet

    @Query(sort: \Notebook.updatedAt, order: .reverse) private var notebooks: [Notebook]

    @State private var showingNewNotebook = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(notebooks) { notebook in
                        Button { move(to: notebook) } label: {
                            row(title: notebook.title.isEmpty ? "제목 없는 단어장" : notebook.title,
                                detail: "세트 \(notebook.setCount)개 · \(notebook.wordCount)단어",
                                systemImage: notebook.isArchived ? "archivebox" : "books.vertical.fill",
                                isCurrent: set.notebook?.id == notebook.id)
                        }
                        .buttonStyle(.plain)
                    }
                    Button { showingNewNotebook = true } label: {
                        Label("새 단어장 만들기", systemImage: "plus")
                            .font(.body)
                            .foregroundStyle(Theme.tint)
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("단어장")
                }
                .listRowBackground(Theme.rowFill)

                Section {
                    Button { move(to: nil) } label: {
                        row(title: "미분류",
                            detail: "어느 단어장에도 넣지 않아요",
                            systemImage: "tray",
                            isCurrent: set.notebook == nil)
                    }
                    .buttonStyle(.plain)
                } footer: {
                    Text("단어와 학습 기록은 그대로예요. 세트가 놓이는 자리만 바뀝니다.")
                }
                .listRowBackground(Theme.rowFill)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background(scheme).ignoresSafeArea())
            .navigationTitle("‘\(set.title)’ 이동")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
            .sheet(isPresented: $showingNewNotebook) {
                NewNotebookView { notebook in
                    move(to: notebook)
                }
            }
        }
        .tint(Theme.tint)
    }

    private func row(title: String, detail: String, systemImage: String, isCurrent: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Theme.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body).foregroundStyle(.primary)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if isCurrent {
                Image(systemName: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.tint)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private func move(to notebook: Notebook?) {
        // Touch both shelves: the one losing the set and the one gaining it both
        // change, and the list is sorted by `updatedAt`.
        set.notebook?.touch()
        set.notebook = notebook
        notebook?.touch()
        set.touch()
        try? context.save()
        Haptics.success()
        dismiss()
    }
}
