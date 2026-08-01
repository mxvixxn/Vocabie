import SwiftUI
import SwiftData

/// A set row and everything you can do to it, shared by the two lists that show sets:
/// the 미분류 section of the 단어장 list, and the inside of a 단어장.
///
/// The actions are the same in both places, but a swipe action can only *start* one —
/// renaming, moving and deleting all need a sheet or a dialog, and those have to live
/// on the container rather than on each row, or the list presents one per row. So the
/// row raises intent into `SetActions`, and `.setActionDialogs(_:)` handles it once.

// MARK: - Reordering

/// Turning a list move into stored order.
///
/// The lists sort by `order` with `updatedAt` as the tiebreaker, which means an
/// untouched library needs no migration — every row starts at 0 and still reads
/// newest-first. The moment one row moves, the *whole* visible list is renumbered, so
/// the arrangement is complete rather than half-inherited from the old ordering.
enum Reorder {
    static func apply<T>(_ items: [T], from source: IndexSet, to destination: Int,
                         assign: (T, Int) -> Void) {
        var arranged = items
        arranged.move(fromOffsets: source, toOffset: destination)
        for (index, item) in arranged.enumerated() { assign(item, index) }
        Haptics.selection()
    }
}

// MARK: - Shared state

@Observable
final class SetActions {
    var renameTarget: VocabSet?
    var moveTarget: VocabSet?
    /// Deleting takes the set's words with it, so it asks first.
    var deletionTarget: VocabSet?
    var draftTitle = ""
}

// MARK: - Row

struct SetListRow: View {
    let set: VocabSet
    let actions: SetActions

    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationLink(value: set) {
            SetRow(set: set)
        }
        .navigationLinkIndicatorVisibility(.hidden)
        .plainRow()
        .swipeActions(edge: .leading) {
            Button {
                Haptics.selection()
                actions.draftTitle = set.title
                actions.renameTarget = set
            } label: {
                Label("이름 변경", systemImage: "pencil")
            }
            .tint(.blue)
            Button {
                Haptics.selection()
                actions.moveTarget = set
            } label: {
                Label("단어장 이동", systemImage: "folder")
            }
            .tint(.indigo)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                Haptics.selection()
                actions.deletionTarget = set
            } label: {
                Label("삭제", systemImage: "trash")
            }
            .tint(.red)
            Button {
                Haptics.selection()
                withAnimation {
                    set.isArchived = true
                    set.touch()
                }
                try? context.save()
            } label: {
                Label("보관", systemImage: "archivebox")
            }
            .tint(Theme.tint)
        }
    }
}

struct SetRow: View {
    let set: VocabSet

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(set.title.isEmpty ? "제목 없는 세트" : set.title)
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

/// Strips the List chrome so rows keep floating on the gradient the way they did
/// in the scroll view. Same row metrics as Moodie Sky's diary list.
extension View {
    func plainRow() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }
}

// MARK: - Dialogs

extension View {
    /// Attaches the rename / move / delete UI the rows ask for. Put this on the
    /// container that holds the list, once.
    func setActionDialogs(_ actions: SetActions) -> some View {
        modifier(SetActionDialogs(actions: actions))
    }
}

private struct SetActionDialogs: ViewModifier {
    @Environment(\.modelContext) private var context
    @Bindable var actions: SetActions

    func body(content: Content) -> some View {
        content
            .sheet(item: $actions.moveTarget) { set in
                MoveSetView(set: set)
            }
            .alert("이름 변경", isPresented: Binding(
                get: { actions.renameTarget != nil },
                set: { if !$0 { actions.renameTarget = nil } }
            )) {
                TextField("세트 이름", text: $actions.draftTitle)
                Button("취소", role: .cancel) { actions.renameTarget = nil }
                Button("저장") { rename() }
            }
            .confirmationDialog(
                "‘\(actions.deletionTarget?.title ?? "")’을(를) 삭제할까요?",
                isPresented: Binding(
                    get: { actions.deletionTarget != nil },
                    set: { if !$0 { actions.deletionTarget = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("삭제", role: .destructive) { deletePending() }
                Button("취소", role: .cancel) { actions.deletionTarget = nil }
            } message: {
                if let set = actions.deletionTarget {
                    Text("단어 \(set.wordCount)개와 학습 기록이 함께 사라져요. 되돌릴 수 없어요.")
                }
            }
    }

    private func rename() {
        let title = actions.draftTitle.trimmed
        guard let set = actions.renameTarget else { return }
        actions.renameTarget = nil
        guard !title.isEmpty else { return }
        set.title = title
        set.touch()
        try? context.save()
        Haptics.success()
    }

    private func deletePending() {
        guard let set = actions.deletionTarget else { return }
        // Clear the reference first so the dialog stops reading a deleted object.
        actions.deletionTarget = nil
        // Vocab has a cascade delete rule, so its words go with it.
        withAnimation { context.delete(set) }
        try? context.save()
        Haptics.intenseError()
    }
}
