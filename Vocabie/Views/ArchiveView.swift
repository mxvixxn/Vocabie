import SwiftUI
import SwiftData

/// 설정 › 보관함 — archived sets, where they can be restored or permanently deleted.
struct ArchiveView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme

    @Query(filter: #Predicate<VocabSet> { $0.isArchived },
           sort: \VocabSet.updatedAt, order: .reverse)
    private var archived: [VocabSet]

    @State private var pendingDeletion: VocabSet?

    var body: some View {
        ZStack {
            Theme.background(scheme).ignoresSafeArea()
            if archived.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("보관함")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "‘\(pendingDeletion?.title ?? "")’을(를) 삭제할까요?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) { deletePending() }
            Button("취소", role: .cancel) { pendingDeletion = nil }
        } message: {
            if let set = pendingDeletion {
                Text("단어 \(set.wordCount)개와 학습 기록이 함께 사라져요. 되돌릴 수 없어요.")
            }
        }
    }

    private var list: some View {
        List {
            ForEach(archived) { set in
                ArchivedRow(set: set)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .swipeActions(edge: .leading) {
                        Button {
                            restore(set)
                        } label: {
                            Label("복원", systemImage: "tray.and.arrow.up")
                        }
                        .tint(Theme.correct)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Haptics.selection()
                            pendingDeletion = set
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                        .tint(.red)
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        EmptyStateView(
            systemImage: "archivebox",
            title: "보관한 단어장이 없어요",
            message: "단어장을 왼쪽으로 밀어 보관하면 여기에 모여요.",
            tint: .secondary
        )
    }

    private func restore(_ set: VocabSet) {
        withAnimation {
            set.isArchived = false
            set.touch()
        }
        try? context.save()
        Haptics.success()
    }

    private func deletePending() {
        guard let set = pendingDeletion else { return }
        pendingDeletion = nil
        withAnimation { context.delete(set) }   // words cascade with it
        try? context.save()
        Haptics.intenseError()
    }
}

private struct ArchivedRow: View {
    let set: VocabSet

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(set.title.isEmpty ? "제목 없는 단어장" : set.title)
                    .font(.headline)
                Text("\(set.wordCount)단어")
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
