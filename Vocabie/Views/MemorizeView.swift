import SwiftUI

/// 암기 (Memorize): a short-form, vertically-swiped flashcard feed.
///
/// One card fills the middle band. Swipe **up** for the next word, **down** for the
/// previous — the card follows your finger and snaps, like a Shorts / Reels feed.
/// Tap the card to flip between the term and its meaning. Swiping up off the last
/// card finishes the pass. There is no button tray; a first-card hint teaches it.
struct MemorizeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var context

    let cards: [Vocab]
    let direction: StudyDirection
    /// What to offer at the finish line, when more material follows this pass.
    var nextTitle: String? = nil
    var onNext: (() -> Void)? = nil

    @AppStorage("autoSpeak") private var autoSpeak = true

    @State private var index = 0
    @State private var revealed = false
    @State private var finished = false
    /// Vertical offset of the deck while dragging / snapping.
    @State private var drag: CGFloat = 0
    /// True while a snap animation is committing, so mid-flight input is ignored.
    @State private var locked = false
    /// Measured deck height, so a card can snap fully off screen.
    @State private var deckHeight: CGFloat = 0

    private var current: Vocab? {
        cards.indices.contains(index) ? cards[index] : nil
    }

    private func card(at i: Int) -> Vocab? {
        cards.indices.contains(i) ? cards[i] : nil
    }

    /// Whether the English term is the side currently on screen.
    private func termVisible(revealed: Bool) -> Bool {
        direction == .termToMeaning ? !revealed : revealed
    }

    private var progress: Double {
        guard !cards.isEmpty else { return 1 }
        return Double(index) / Double(cards.count)
    }

    /// How far a card travels to clear the band when snapping.
    private var travel: CGFloat { deckHeight > 0 ? deckHeight : 1000 }

    var body: some View {
        ZStack {
            Theme.background(scheme).ignoresSafeArea()

            if finished {
                StudyCompleteView(mode: .memorize, total: cards.count,
                                  nextTitle: nextTitle, onNext: onNext,
                                  onRestart: restart, onClose: { dismiss() })
            } else {
                StudyScaffold(
                    mode: .memorize,
                    cleared: min(index + 1, cards.count),
                    total: cards.count,
                    progress: progress,
                    onClose: { dismiss() }
                ) {
                    deck
                } panel: {
                    hint
                }
            }
        }
        .onAppear { speakIfNeeded() }
        .onDisappear { Speaker.shared.stop() }
    }

    // MARK: Deck

    private var deck: some View {
        GeometryReader { geo in
            let size = cardSize(in: geo.size)
            let h = geo.size.height
            ZStack {
                // The card sliding up from below (next) — or the finish peek.
                if drag < 0 {
                    Group {
                        if index < cards.count - 1 {
                            cardView(for: card(at: index + 1), revealed: false, size: size)
                        } else {
                            finishPeek(size: size)
                        }
                    }
                    .offset(y: drag + h)
                }

                // The card sliding down from above (previous).
                if drag > 0, index > 0 {
                    cardView(for: card(at: index - 1), revealed: false, size: size)
                        .offset(y: drag - h)
                }

                // The current card: tracks the finger, flips on tap.
                // Tap + drag share one view so a stationary tap flips while a moving
                // touch slides — the parent must not swallow the tap.
                cardView(for: current, revealed: revealed, size: size)
                    .offset(y: drag)
                    .contentShape(Rectangle())
                    .onTapGesture { flip() }
                    .gesture(deckDrag)
            }
            .frame(width: geo.size.width, height: h)
            .onChange(of: h, initial: true) { _, newValue in deckHeight = newValue }
            .accessibilityElement(children: .contain)
            .accessibilityAction(named: revealed ? "뜻 숨기기" : "뜻 보기") { flip() }
            .accessibilityAction(named: index == cards.count - 1 ? "완료" : "다음") { goNext() }
            .accessibilityAction(named: "이전") { goPrev() }
        }
    }

    private func cardSize(in container: CGSize) -> CGSize {
        CGSize(width: container.width - 40,
               height: container.height - 12)
    }

    /// A real card surface with the word on it.
    private func cardView(for card: Vocab?, revealed: Bool, size: CGSize) -> some View {
        let front = direction == .termToMeaning ? (card?.term ?? "") : (card?.meaning ?? "")
        let back = direction == .termToMeaning ? (card?.meaning ?? "") : (card?.term ?? "")
        let frontLabel = direction == .termToMeaning ? "단어" : "뜻"
        let backLabel = direction == .termToMeaning ? "뜻" : "단어"

        return ZStack {
            RoundedRectangle(cornerRadius: Theme.panelCorner, style: .continuous)
                .fill(cardFill)
                .shadow(color: .black.opacity(scheme == .dark ? 0.4 : 0.10),
                        radius: 22, x: 0, y: 12)

            WordStage(
                kicker: revealed ? backLabel : frontLabel,
                word: revealed ? back : front,
                note: revealed ? (card?.note ?? "") : "탭하면 정답이 보여요",
                accent: Theme.memorize,
                size: 40,
                stacked: false,
                // Only offer pronunciation while the English term is on screen.
                speaks: termVisible(revealed: revealed) ? card?.term : nil
            )
            .padding(24)
        }
        .frame(width: size.width, height: size.height)
    }

    private var cardFill: Color {
        scheme == .dark ? Color.white.opacity(0.07) : Color.white
    }

    /// A soft "done" card that peeks up as you swipe off the last word.
    private func finishPeek(size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.panelCorner, style: .continuous)
                .fill(cardFill)
                .shadow(color: .black.opacity(scheme == .dark ? 0.4 : 0.10),
                        radius: 22, x: 0, y: 12)
            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(Theme.memorize.gradient)
                Text("암기 끝!")
                    .font(.title3.weight(.bold))
            }
        }
        .frame(width: size.width, height: size.height)
    }

    /// First-card nudge that teaches the swipe, then gets out of the way.
    private var hint: some View {
        Group {
            if index == 0 && drag == 0 {
                HStack(spacing: 7) {
                    Image(systemName: "chevron.up")
                        .symbolEffect(.bounce, options: .repeating)
                    Text("위로 넘겨서 다음 단어")
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 22)
        .padding(.top, 4)
        .padding(.bottom, 14)
        .animation(.easeInOut(duration: 0.25), value: index == 0)
    }

    private var deckDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !locked else { return }
                let dy = value.translation.height
                // Rubber-band against the hard top edge (no previous card).
                drag = (dy > 0 && index == 0) ? dy * 0.32 : dy
            }
            .onEnded { value in
                guard !locked else { return }
                onDragEnd(value)
            }
    }

    private func onDragEnd(_ value: DragGesture.Value) {
        let dy = value.translation.height
        let predicted = value.predictedEndTranslation.height
        let commit = travel * 0.22
        let flick = travel * 0.5

        if dy < -commit || predicted < -flick {
            goNext()
        } else if (dy > commit || predicted > flick), index > 0 {
            goPrev()
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { drag = 0 }
        }
    }

    // MARK: Navigation

    private func goNext() {
        guard !locked else { return }
        if index < cards.count - 1 { advance(to: index + 1, offBy: -travel) }
        else { finish(offBy: -travel) }
    }

    private func goPrev() {
        guard !locked, index > 0 else { return }
        advance(to: index - 1, offBy: travel)
    }

    /// Snaps the current card off `offBy`, then swaps in `newIndex` at centre.
    private func advance(to newIndex: Int, offBy target: CGFloat) {
        if newIndex > index { markSeen(current) }
        locked = true
        // No haptic on a swipe between cards — only the tap-to-flip taps (below).
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            drag = target
        } completion: {
            index = newIndex
            revealed = false
            drag = 0
            locked = false
            speakIfNeeded()
        }
    }

    private func finish(offBy target: CGFloat) {
        markSeen(current)
        locked = true
        Haptics.success()
        Speaker.shared.stop()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
            drag = target
        } completion: {
            finished = true
            drag = 0
            locked = false
        }
    }

    private func flip() {
        guard !locked else { return }
        Haptics.rigid()   // the "뚝" when the card is tapped to reveal the meaning
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { revealed.toggle() }
        speakIfNeeded()
    }

    private func markSeen(_ card: Vocab?) {
        card?.memorizeSeen = true
        card?.lastStudied = Date()
        try? context.save()
    }

    /// Reads the term aloud whenever it is the visible side.
    private func speakIfNeeded() {
        guard autoSpeak, termVisible(revealed: revealed), let term = current?.term else { return }
        Speaker.shared.speak(term)
    }

    private func restart() {
        index = 0
        revealed = false
        finished = false
        drag = 0
        locked = false
        speakIfNeeded()
    }
}
