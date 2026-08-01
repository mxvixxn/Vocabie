import SwiftUI
import SwiftData

/// Drag the words of a set into the order you want to meet them in.
///
/// A sheet rather than an inline edit mode: the set screen's word list lives in a
/// `LazyVStack` inside a scroll view — good for 300 rows, but `onMove` needs a `List`.
/// Reordering is also a deliberate, occasional act, which suits a screen you enter.
///
/// The order set here is the order everything else follows: the 묶음 split, 암기's card
/// deck, and 리콜 / 스펠 when 랜덤 is off.
struct WordOrderView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @Bindable var set: VocabSet

    // `self` is required: a bare `set` at the start of a computed property body reads
    // as the beginning of a setter.
    private var words: [Vocab] { self.set.orderedWords }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background(scheme).ignoresSafeArea()

                List {
                    ForEach(Array(words.enumerated()), id: \.element.id) { index, word in
                        row(word, at: index)
                    }
                    .onMove(perform: move)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, .constant(.active))
            }
            .navigationTitle("단어 순서")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                        .font(.body.weight(.semibold))
                }
            }
        }
        .tint(Theme.tint)
    }

    private func row(_ word: Vocab, at index: Int) -> some View {
        HStack(spacing: 12) {
            // The number is the point of the screen — it is what the 묶음 split counts.
            Text("\(index + 1)")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 26, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(word.term).font(.body.weight(.medium))
                Text(word.meaning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: Theme.innerCorner, style: .continuous)
            .fill(Theme.rowFill))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
    }

    private func move(from source: IndexSet, to destination: Int) {
        Reorder.apply(words, from: source, to: destination) { $0.order = $1 }
        set.touch()
        try? context.save()
    }
}
