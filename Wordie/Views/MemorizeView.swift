import SwiftUI

/// 암기 (Memorize): a passive flashcard pass. Tap to flip, swipe or tap Next to advance.
struct MemorizeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var context

    let cards: [Vocab]
    let direction: StudyDirection

    @State private var index = 0
    @State private var flipped = false
    @State private var finished = false

    private var current: Vocab? {
        guard cards.indices.contains(index) else { return nil }
        return cards[index]
    }

    private var progress: Double {
        guard !cards.isEmpty else { return 1 }
        return Double(index) / Double(cards.count)
    }

    var body: some View {
        ZStack {
            Theme.background(scheme).ignoresSafeArea()

            if finished {
                StudyCompleteView(
                    mode: .memorize,
                    total: cards.count,
                    onRestart: restart,
                    onClose: { dismiss() }
                )
            } else {
                VStack(spacing: 0) {
                    StudyTopBar(
                        title: "암기 \(min(index + 1, cards.count))/\(cards.count)",
                        progress: progress,
                        accent: Theme.memorize,
                        onClose: { dismiss() }
                    )
                    Spacer()
                    if let card = current {
                        card(for: card)
                            .padding(.horizontal, 24)
                    }
                    Spacer()
                    controls
                }
            }
        }
    }

    private func card(for card: Vocab) -> some View {
        let front = direction == .termToMeaning ? card.term : card.meaning
        let back = direction == .termToMeaning ? card.meaning : card.term
        let frontLabel = direction == .termToMeaning ? "단어" : "뜻"
        let backLabel = direction == .termToMeaning ? "뜻" : "단어"
        return VStack(spacing: 16) {
            Text(flipped ? backLabel : frontLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.memorize)
            Text(flipped ? back : front)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
            if flipped && !card.note.isEmpty {
                Text(card.note)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if !flipped {
                Text("탭하면 정답이 보여요")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .cardSurface(padding: 28)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: flipped)
        .onTapGesture {
            Haptics.soft()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { flipped.toggle() }
        }
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    if value.translation.width < -40 { next() }
                    else if value.translation.width > 40 { previous() }
                }
        )
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Button(action: previous) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 54, height: 54)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .disabled(index == 0)
            .opacity(index == 0 ? 0.4 : 1)

            Button(action: next) {
                Text(index == cards.count - 1 ? "완료" : "다음")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.memorize, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
    }

    // MARK: Navigation

    private func next() {
        current?.memorizeSeen = true
        current?.lastStudied = Date()
        try? context.save()
        if index >= cards.count - 1 {
            Haptics.success()
            withAnimation { finished = true }
        } else {
            withAnimation(.easeInOut(duration: 0.15)) { flipped = false }
            index += 1
        }
    }

    private func previous() {
        guard index > 0 else { return }
        flipped = false
        index -= 1
    }

    private func restart() {
        index = 0
        flipped = false
        finished = false
    }
}
