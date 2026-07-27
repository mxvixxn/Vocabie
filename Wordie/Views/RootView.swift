import SwiftUI
import SwiftData

/// Home screen: the list of study sets (단어장).
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \VocabSet.updatedAt, order: .reverse) private var sets: [VocabSet]

    @State private var showingNewSet = false
    @State private var showingReview = false
    /// Set awaiting delete confirmation. Deleting takes its words with it, so we ask.
    @State private var pendingDeletion: VocabSet?
    /// Set being renamed from the leading swipe.
    @State private var renameTarget: VocabSet?
    @State private var draftTitle = ""

    /// Every card across every set whose review date has arrived, hardest first.
    private var dueCards: [Vocab] {
        sets.flatMap { $0.dueWords() }
            .sorted { $0.lapses > $1.lapses }
    }

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
            .navigationTitle("Wordie")
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
            .sheet(isPresented: $showingReview) {
                ReviewStartView(dueCards: dueCards)
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
            if !dueCards.isEmpty {
                Button {
                    Haptics.soft()
                    showingReview = true
                } label: {
                    ReviewBanner(count: dueCards.count)
                }
                .buttonStyle(.plain)
                .plainRow()
            }

            ForEach(sets) { set in
                NavigationLink(value: set) {
                    SetRow(set: set)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
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
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Haptics.selection()
                        pendingDeletion = set
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
                .plainRow()
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationDestination(for: VocabSet.self) { set in
            SetDetailView(set: set)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.tint.gradient)
            Text("아직 단어장이 없어요")
                .font(.title3.weight(.semibold))
            Text("＋ 버튼을 눌러 첫 단어장을 만들고\nCSV·엑셀·텍스트를 붙여넣어 보세요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Haptics.soft()
                showingNewSet = true
            } label: {
                Label("단어장 만들기", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Theme.tint, in: Capsule())
                    .foregroundStyle(.white)
            }
            .padding(.top, 4)
        }
        .padding(40)
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

/// Sits above the set list whenever cards have come due.
private struct ReviewBanner: View {
    let count: Int

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.tint.gradient)
                    .frame(width: 46, height: 46)
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("오늘의 복습")
                    .font(.headline)
                Text("\(count)개 단어가 복습할 때가 됐어요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .glassPanel(corner: 24, tint: Theme.tint)
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
        .padding(16)
        .glassPanel(corner: 24)
    }
}
