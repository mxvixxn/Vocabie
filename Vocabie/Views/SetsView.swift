import SwiftUI
import SwiftData

/// 세트 tab: the list of study sets (단어장) — create, rename, delete.
struct SetsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme
    @Query(filter: #Predicate<VocabSet> { !$0.isArchived },
           sort: \VocabSet.updatedAt, order: .reverse) private var sets: [VocabSet]

    @State private var showingNewSet = false
    /// Set awaiting delete confirmation. Deleting takes its words with it, so we ask.
    @State private var pendingDeletion: VocabSet?
    /// Set being renamed from the leading swipe.
    @State private var renameTarget: VocabSet?
    @State private var draftTitle = ""

    @AppStorage("vocabie.hasSeenSwipeTutorial") private var hasSeenSwipeTutorial = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background(scheme).ignoresSafeArea()

                if sets.isEmpty {
                    emptyState
                } else {
                    setList
                }
            }
            .navigationTitle("단어장")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.soft()
                        showingNewSet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.tint)
                    }
                }
            }
            .sheet(isPresented: $showingNewSet) {
                NewSetView()
            }
            .confirmationDialog(
                "‘\(pendingDeletion?.title ?? "")’을(를) 삭제할까요?",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("삭제", role: .destructive) { deletePendingSet() }
                Button("취소", role: .cancel) { pendingDeletion = nil }
            } message: {
                if let set = pendingDeletion {
                    Text("단어 \(set.wordCount)개와 학습 기록이 함께 사라져요. 되돌릴 수 없어요.")
                }
            }
            .alert("이름 변경", isPresented: Binding(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } }
            )) {
                TextField("단어장 이름", text: $draftTitle)
                Button("취소", role: .cancel) { renameTarget = nil }
                Button("저장") { if let set = renameTarget { rename(set) } }
            }
        }
        .tint(Theme.tint)
        .overlay {
            if !hasSeenSwipeTutorial {
                SwipeTutorialView {
                    withAnimation(.easeInOut(duration: 0.25)) { hasSeenSwipeTutorial = true }
                }
                .transition(.opacity)
            }
        }
    }

    private func deletePendingSet() {
        guard let set = pendingDeletion else { return }
        // Clear the reference first so the dialog stops reading a deleted object.
        pendingDeletion = nil
        // Vocab has a cascade delete rule, so its words go with it.
        withAnimation { context.delete(set) }
        try? context.save()
        Haptics.intenseError()
    }

    private func archive(_ set: VocabSet) {
        Haptics.selection()
        withAnimation {
            set.isArchived = true
            set.touch()
        }
        try? context.save()
    }

    private func rename(_ set: VocabSet) {
        let title = draftTitle.trimmed
        renameTarget = nil
        guard !title.isEmpty else { return }
        set.title = title
        set.touch()
        try? context.save()
        Haptics.success()
    }

    private var setList: some View {
        List {
            ForEach(sets) { set in
                NavigationLink(value: set) {
                    SetRow(set: set)
                }
                .navigationLinkIndicatorVisibility(.hidden)
                .plainRow()
                .swipeActions(edge: .leading) {
                    Button {
                        Haptics.selection()
                        draftTitle = set.title
                        renameTarget = set
                    } label: {
                        Label("이름 변경", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        Haptics.selection()
                        pendingDeletion = set
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                    .tint(.red)
                    Button {
                        archive(set)
                    } label: {
                        Label("보관", systemImage: "archivebox")
                    }
                    .tint(Theme.tint)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationDestination(for: VocabSet.self) { set in
            SetDetailView(set: set)
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            systemImage: "cloud.sun.fill",
            title: "아직 단어장이 없어요",
            message: "＋ 버튼을 눌러 첫 단어장을 만들고\nCSV·엑셀·텍스트를 붙여넣어 보세요.",
            actionTitle: "단어장 만들기",
            actionImage: "plus"
        ) {
            Haptics.soft()
            showingNewSet = true
        }
    }
}

/// Strips the List chrome so rows keep floating on the gradient the way they did
/// in the scroll view. Same row metrics as Moodie Sky's diary list.
private extension View {
    func plainRow() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }
}

private struct SetRow: View {
    let set: VocabSet

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(set.title.isEmpty ? "제목 없는 단어장" : set.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(set.wordCount)단어")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            if !set.detail.isEmpty {
                Text(set.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            ProgressView(value: set.masteryProgress)
                .tint(Theme.tint)
            HStack(spacing: 4) {
                Image(systemName: "star.fill").font(.caption2).foregroundStyle(Theme.star)
                Text("\(set.totalStars)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                let due = set.dueCount()
                if due > 0 {
                    Text("복습 \(due)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.tint)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.tint.opacity(0.14)))
                        .padding(.leading, 4)
                }

                Spacer()
                Text("\(Int(set.masteryProgress * 100))% 완료")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Theme.contentPad)
        .glassPanel()
        // Flatten the hit region back to a plain rectangle. The glass container
        // shapes its own, which can leave the row's swipe area ill-defined.
        .contentShape(Rectangle())
    }
}
