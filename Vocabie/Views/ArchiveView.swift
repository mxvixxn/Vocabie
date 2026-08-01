import SwiftUI
import SwiftData

/// 설정 › 보관함 — put-away 단어장 and 세트, where they can be restored or deleted for good.
struct ArchiveView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme

    @Query(filter: #Predicate<Notebook> { $0.isArchived },
           sort: \Notebook.updatedAt, order: .reverse)
    private var archivedNotebooks: [Notebook]

    @Query(filter: #Predicate<VocabSet> { $0.isArchived },
           sort: \VocabSet.updatedAt, order: .reverse)
    private var archivedSets: [VocabSet]

    @State private var pendingSet: VocabSet?
    @State private var pendingNotebook: Notebook?

    private var isEmpty: Bool { archivedNotebooks.isEmpty && archivedSets.isEmpty }

    var body: some View {
        ZStack {
            Theme.background(scheme).ignoresSafeArea()
            if isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("보관함")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "‘\(pendingSet?.title ?? "")’을(를) 삭제할까요?",
            isPresented: Binding(
                get: { pendingSet != nil },
                set: { if !$0 { pendingSet = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) { deletePendingSet() }
            Button("취소", role: .cancel) { pendingSet = nil }
        } message: {
            if let set = pendingSet {
                Text("단어 \(set.wordCount)개와 학습 기록이 함께 사라져요. 되돌릴 수 없어요.")
            }
        }
        .confirmationDialog(
            "‘\(pendingNotebook?.title ?? "")’을(를) 삭제할까요?",
            isPresented: Binding(
                get: { pendingNotebook != nil },
                set: { if !$0 { pendingNotebook = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) { deletePendingNotebook() }
            Button("취소", role: .cancel) { pendingNotebook = nil }
        } message: {
            if let notebook = pendingNotebook {
                Text("세트 \(notebook.setCount)개와 단어 \(notebook.wordCount)개가 함께 사라져요. 되돌릴 수 없어요.")
            }
        }
    }

    private var list: some View {
        List {
            if !archivedNotebooks.isEmpty {
                Section {
                    ForEach(archivedNotebooks) { notebook in
                        ArchivedRow(title: notebook.title.isEmpty ? "제목 없는 단어장" : notebook.title,
                                    detail: "세트 \(notebook.setCount)개 · \(notebook.wordCount)단어")
                            .archiveRow(
                                restore: { restore(notebook) },
                                delete: {
                                    Haptics.selection()
                                    pendingNotebook = notebook
                                }
                            )
                    }
                } header: {
                    header("단어장")
                }
            }

            if !archivedSets.isEmpty {
                Section {
                    ForEach(archivedSets) { set in
                        ArchivedRow(title: set.title.isEmpty ? "제목 없는 세트" : set.title,
                                    detail: setDetail(set))
                            .archiveRow(
                                restore: { restore(set) },
                                delete: {
                                    Haptics.selection()
                                    pendingSet = set
                                }
                            )
                    }
                } header: {
                    header("세트")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    /// An archived set that sits on an archived shelf would come back invisible, so
    /// the row says where it will land.
    private func setDetail(_ set: VocabSet) -> String {
        let words = "\(set.wordCount)단어"
        guard let notebook = set.notebook else { return words }
        return words + " · \(notebook.title)" + (notebook.isArchived ? " (보관됨)" : "")
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(nil)
            .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 2, trailing: 16))
    }

    private var emptyState: some View {
        EmptyStateView(
            systemImage: "archivebox",
            title: "보관한 항목이 없어요",
            message: "단어장이나 세트를 왼쪽으로 밀어 보관하면 여기에 모여요.",
            tint: .secondary
        )
    }

    // MARK: Actions

    private func restore(_ set: VocabSet) {
        withAnimation {
            set.isArchived = false
            set.touch()
        }
        try? context.save()
        Haptics.success()
    }

    private func restore(_ notebook: Notebook) {
        withAnimation {
            notebook.isArchived = false
            notebook.touch()
        }
        try? context.save()
        Haptics.success()
    }

    private func deletePendingSet() {
        guard let set = pendingSet else { return }
        pendingSet = nil
        withAnimation { context.delete(set) }   // words cascade with it
        try? context.save()
        Haptics.intenseError()
    }

    private func deletePendingNotebook() {
        guard let notebook = pendingNotebook else { return }
        pendingNotebook = nil
        withAnimation { context.delete(notebook) }  // sets and their words cascade
        try? context.save()
        Haptics.intenseError()
    }
}

private struct ArchivedRow: View {
    let title: String
    let detail: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "archivebox.fill")
                .foregroundStyle(.tertiary)
        }
        .padding(Theme.contentPad)
        .glassPanel()
        .contentShape(Rectangle())
    }
}

private extension View {
    /// Same chrome and same two swipes for every row in the archive.
    func archiveRow(restore: @escaping () -> Void, delete: @escaping () -> Void) -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .swipeActions(edge: .leading) {
                Button(action: restore) {
                    Label("복원", systemImage: "tray.and.arrow.up")
                }
                .tint(Theme.correct)
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive, action: delete) {
                    Label("삭제", systemImage: "trash")
                }
                .tint(.red)
            }
    }
}
