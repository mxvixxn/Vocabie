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
    /// Voice for this pass. A set is one language, so this is fixed for the whole deck.
    var voice: String = StudyLanguage.english.voiceCode
    /// Where this pass is saved, so leaving mid-way can be picked up later.
    /// `nil` for passes that aren't a set's 묶음 (today's review).
    var progressKey: String? = nil
    /// A saved position to open on.
    var resume: StudyProgress? = nil
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
    /// True once the opening position has been applied, so it happens exactly once.
    @State private var started = false
    /// How far into the pass the learner has actually got. Nothing is written to the
    /// model while a finger is moving — this watermark is all the swipe touches, and
    /// `flush()` turns it into 암기 stars on the way out.
    @State private var furthest = 0
    /// True while this screen holds the audio session, so it is released exactly once.
    @State private var holding = false
    /// Cancels a pending utterance when the learner keeps swiping.
    @State private var speechTask: Task<Void, Never>?

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
        .onAppear(perform: start)
        .onDisappear {
            speechTask?.cancel()
            Speaker.shared.stop()
            if holding {
                holding = false
                Speaker.shared.release()
            }
            persist()
            flush()
        }
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
                            cardView(for: card(at: index + 1), revealed: false,
                                     size: size, shadowed: false)
                        } else {
                            finishPeek(size: size)
                        }
                    }
                    .offset(y: drag + h)
                }

                // The card sliding down from above (previous).
                if drag > 0, index > 0 {
                    cardView(for: card(at: index - 1), revealed: false,
                             size: size, shadowed: false)
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
    ///
    /// The card is built as a separate `Equatable` view on purpose. Reading `card.term`
    /// straight out of the model here meant SwiftUI re-evaluated three cards — and
    /// re-read three observable objects — on *every frame* of a drag, because `drag`
    /// lives in the same body. Handing plain strings to a view that declares itself
    /// unchanged reduces a drag frame to what it should be: moving two offsets.
    ///
    /// `shadowed` is off for the neighbours waiting off-screen. A blurred shadow forces
    /// an offscreen pass per card, and paying for it three times a frame is the other
    /// half of what made the swipe feel gritty — only the card being touched needs one.
    private func cardView(for card: Vocab?, revealed: Bool, size: CGSize,
                          shadowed: Bool = true) -> some View {
        let front = direction == .termToMeaning ? (card?.term ?? "") : (card?.meaning ?? "")
        let back = direction == .termToMeaning ? (card?.meaning ?? "") : (card?.term ?? "")
        let frontLabel = direction == .termToMeaning ? "단어" : "뜻"
        let backLabel = direction == .termToMeaning ? "뜻" : "단어"

        return DeckCard(
            kicker: revealed ? backLabel : frontLabel,
            word: revealed ? back : front,
            note: revealed ? (card?.note ?? "") : "탭하면 정답이 보여요",
            // Only offer pronunciation while the English term is on screen.
            speaks: termVisible(revealed: revealed) ? card?.term : nil,
            voice: voice,
            size: size,
            fill: cardFill,
            shadowed: shadowed,
            dark: scheme == .dark
        )
        .equatable()
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
    ///
    /// Nothing expensive happens inside the animation or its completion. Marking a card
    /// seen used to write to SwiftData on every swipe, and the next word was spoken the
    /// instant the spring landed — a disk write and an utterance both landing on the
    /// main thread mid-gesture, which is what the stutter was. The write is now batched
    /// (`flush`) and the speech is scheduled just after the frame settles.
    private func advance(to newIndex: Int, offBy target: CGFloat) {
        furthest = max(furthest, newIndex)
        locked = true
        speechTask?.cancel()
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
        furthest = cards.count
        locked = true
        speechTask?.cancel()
        Haptics.success()
        Speaker.shared.stop()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
            drag = target
        } completion: {
            finished = true
            drag = 0
            locked = false
            flush()
            if let progressKey { StudyProgressStore.clear(progressKey) }
        }
    }

    private func flip() {
        guard !locked else { return }
        Haptics.rigid()   // the "뚝" when the card is tapped to reveal the meaning
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { revealed.toggle() }
        speakIfNeeded()
    }

    // MARK: Opening position · persistence

    /// Opens on the saved position (if any) and takes the audio session, so the very
    /// first word is spoken.
    ///
    /// That first word used to stay silent: `onAppear` fires while the cover is still
    /// animating in, and activating the audio session in the middle of that presentation
    /// simply lost the utterance. Holding the session and letting the transition finish
    /// first fixes it.
    private func start() {
        guard !started else { return }
        started = true
        holding = true
        Speaker.shared.hold()
        if let resume {
            let seen = Set(resume.clearedIDs)
            let position = cards.firstIndex { !seen.contains($0.id) } ?? 0
            index = min(position, max(cards.count - 1, 0))
        }
        furthest = index
        speakIfNeeded(delay: 0.45)
    }

    /// Reads the term aloud whenever it is the visible side.
    private func speakIfNeeded(delay: Double = 0.06) {
        speechTask?.cancel()
        guard autoSpeak, termVisible(revealed: revealed), let term = current?.term else { return }
        speechTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            Speaker.shared.speak(term, language: voice)
        }
    }

    /// Turn the watermark into 암기 stars, once.
    ///
    /// Touching the model mid-swipe is what has to be avoided: every property set marks
    /// the context dirty, and SwiftData's autosave then picks its own moment to write —
    /// which lands, unhelpfully, in the middle of a gesture.
    private func flush() {
        let seen = min(furthest, cards.count)
        guard seen > 0 else { return }
        furthest = 0
        let now = Date()
        for card in cards.prefix(seen) {
            card.setMemorizeSeen(true, direction)
            card.lastStudied = now
        }
        try? context.save()
    }

    /// Where this pass has got to, so leaving mid-way can be picked up later.
    /// Written on the way out rather than per card — a `UserDefaults` round-trip is
    /// small, but the swipe is the one place nothing extra belongs.
    private func persist() {
        // A finished pass has already cleared its key — writing here would put it back.
        guard !finished, let progressKey, !cards.isEmpty, index > 0 else { return }
        let seen = cards.prefix(index).map(\.id)
        StudyProgressStore.save(
            StudyProgress(queueIDs: cards.dropFirst(index).map(\.id),
                          clearedIDs: Array(seen),
                          misses: [:],
                          total: cards.count),
            key: progressKey
        )
    }

    private func restart() {
        index = 0
        revealed = false
        finished = false
        drag = 0
        locked = false
        furthest = 0
        if let progressKey { StudyProgressStore.clear(progressKey) }
        speakIfNeeded(delay: 0.2)
    }
}

/// One card face. Value-typed and `Equatable` so a drag doesn't rebuild it — see
/// `MemorizeView.cardView(for:revealed:size:shadowed:)`.
private struct DeckCard: View, Equatable {
    let kicker: String
    let word: String
    let note: String
    let speaks: String?
    let voice: String
    let size: CGSize
    let fill: Color
    let shadowed: Bool
    let dark: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.panelCorner, style: .continuous)
                .fill(fill)
                .shadow(color: shadowed ? .black.opacity(dark ? 0.4 : 0.10) : .clear,
                        radius: shadowed ? 22 : 0, x: 0, y: shadowed ? 12 : 0)

            WordStage(
                kicker: kicker,
                word: word,
                note: note,
                accent: Theme.memorize,
                size: 40,
                stacked: false,
                speaks: speaks,
                speaksVoice: voice
            )
            .padding(24)
        }
        .frame(width: size.width, height: size.height)
    }
}
