import SwiftUI

/// 암기 (Memorize): a passive flashcard pass. Tap to reveal, swipe or tap Next to advance.
struct MemorizeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var context

    let cards: [Vocab]
    let direction: StudyDirection

    @State private var index = 0
    @State private var revealed = false
    @State private var finished = false

    private var current: Vocab? {
        cards.indices.contains(index) ? cards[index] : nil
    }

    private var progress: Double {
        guard !cards.isEmpty else { return 1 }
        return Double(index) / Double(cards.count)
    }

    var body: some View {
        ZStack {
            Theme.background(scheme).ignoresSafeArea()

            if finished {
                StudyCompleteView(mode: .memorize, total: cards.count,
                                  onRestart: restart, onClose: { dismiss() })
            } else {
                StudyScaffold(
                    mode: .memorize,
                    cleared: min(index + 1, cards.count),
                    total: cards.count,
                    progress: progress,
                    onClose: { dismiss() }
                ) {
                    stage
                } panel: {
                    FloatingPanel(tint: Theme.memorize) {
                        HStack(spacing: 8) {
                            PanelButton(title: "", systemImage: "chevron.left", action: previous)
                                .frame(width: 74)
                                .disabled(index == 0)
                                .opacity(index == 0 ? 0.4 : 1)

                            PanelButton(
                                title: index == cards.count - 1 ? "완료" : "다음",
                                fill: Theme.memorize,
                                solid: true,
                                action: next
                            )
                        }
                    }
                }
            }
        }
    }

    private var stage: some View {
        let card = current
        let front = direction == .termToMeaning ? (card?.term ?? "") : (card?.meaning ?? "")
        let back = direction == .termToMeaning ? (card?.meaning ?? "") : (card?.term ?? "")
        let frontLabel = direction == .termToMeaning ? "단어" : "뜻"
        let backLabel = direction == .termToMeaning ? "뜻" : "단어"

        return WordStage(
            kicker: revealed ? backLabel : frontLabel,
            word: revealed ? back : front,
            note: revealed ? (card?.note ?? "") : "탭하면 정답이 보여요",
            accent: Theme.memorize,
            size: 40,
            stacked: true
        )
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.soft()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { revealed.toggle() }
        }
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    if value.translation.width < -40 { next() }
                    else if value.translation.width > 40 { previous() }
                }
        )
        .id(index)
        .transition(.opacity)
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
            revealed = false
            withAnimation(.easeInOut(duration: 0.18)) { index += 1 }
        }
    }

    private func previous() {
        guard index > 0 else { return }
        revealed = false
        withAnimation(.easeInOut(duration: 0.18)) { index -= 1 }
    }

    private func restart() {
        index = 0
        revealed = false
        finished = false
    }
}
