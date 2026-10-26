import SwiftUI

/// 스펠 (Spell): type the word from its meaning.
///
/// Grading is lenient — case, spacing, punctuation and slashes are ignored. A hint reveals
/// the answer but counts as a miss, so the card returns later.
///
/// Vertical space is the real constraint here: the keyboard takes roughly 40% of the screen,
/// so once the field is focused the pill shrinks and the prompt chrome steps out of the way.
struct SpellView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var context
    @FocusState private var fieldFocused: Bool

    @State var session: StudySession
    /// Key under which this round's progress is saved, so leaving mid-way resumes.
    let progressKey: String
    /// What to offer at the finish line, when more material follows this round.
    var nextTitle: String? = nil
    var onNext: (() -> Void)? = nil
    @State private var typed = ""
    @State private var phase: Phase = .typing
    @State private var usedHint = false

    @AppStorage("autoSpeak") private var autoSpeak = true

    /// Which already-answered card the look-back is showing; `nil` while closed.
    @State private var peekIndex: Int?
    /// True while this screen holds the audio session, so hold / release stay balanced
    /// however many times SwiftUI decides to call `onAppear`.
    @State private var holding = false

    private enum Phase { case typing, correct, missed }

    /// True while the keyboard is claiming the bottom of the screen.
    private var tight: Bool { fieldFocused && phase == .typing }

    var body: some View {
        ZStack {
            Theme.background(scheme).ignoresSafeArea()

            if session.isFinished {
                StudyCompleteView(mode: .spell, total: session.total,
                                  nextTitle: nextTitle, onNext: onNext,
                                  onRestart: restart, onClose: close)
            } else {
                StudyScaffold(
                    mode: .spell,
                    // Counts the card on screen, so the pill runs 1/10 … 10/10.
                    cleared: min(session.clearedCount + 1, session.total),
                    total: session.total,
                    progress: session.progress,
                    compactPill: tight,
                    onClose: close
                ) {
                    switch phase {
                    case .typing:
                        WordStage(
                            kicker: session.direction == .meaningToTerm
                                ? "뜻을 보고 단어를 입력하세요" : "단어를 보고 뜻을 입력하세요",
                            word: session.prompt,
                            note: session.promptNote,
                            accent: Theme.spell,
                            // The prompt keeps only the word once the keyboard is up.
                            showsChrome: !tight,
                            size: tight ? 30 : 34
                        )
                    case .correct:
                        resultStage(kicker: "정답!", tint: Theme.correct)
                    case .missed:
                        resultStage(kicker: "정답은", tint: Theme.wrong)
                    }
                } panel: {
                    FloatingPanel(tint: Theme.spell) {
                        // The stage carries the answer now. The panel only echoes what
                        // was typed, and only when there is something to compare against
                        // — after a hint there is nothing to show.
                        if phase == .typing || (phase == .missed && !typed.trimmed.isEmpty) {
                            answerField
                        }
                        controls
                    }
                }
                // Swipe left anywhere on the stage to look back at what just went by.
                .backSwipe(enabled: !session.history.isEmpty) { openPeek() }
            }

            HistoryPeek(cards: session.history, index: $peekIndex, accent: Theme.spell)
        }
        .onAppear {
            fieldFocused = true
            takeAudio()
        }
        .onChange(of: peekIndex) { _, now in
            guard now == nil else { return }
            // Back to the question: the keyboard returns only if there is still
            // something to type, and a held auto-advance picks up where it left off.
            if phase == .typing { fieldFocused = true }
            if phase == .correct { autoProceed() }
        }
        .onDisappear {
            Speaker.shared.stop()
            releaseAudio()
        }
    }

    // MARK: Stage

    private var currentTerm: String { session.current?.term ?? "" }
    private var currentMeaning: String { session.current?.meaning ?? "" }

    private func resultStage(kicker: String, tint: Color) -> some View {
        AnswerReveal(
            kicker: kicker,
            tint: tint,
            term: currentTerm,
            meaning: currentMeaning,
            note: session.promptNote,
            accent: Theme.spell
        )
    }

    // MARK: Panel contents

    private var answerField: some View {
        TextField("정답 입력", text: $typed)
            .focused($fieldFocused)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .font(.title3.weight(.medium))
            .multilineTextAlignment(.center)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.innerCorner, style: .continuous)
                    .fill(fieldFill)
            )
            .disabled(phase != .typing)
            .onSubmit { if phase == .typing { check() } }
            .animation(.easeInOut(duration: 0.2), value: phase)
    }

    private var fieldFill: Color {
        switch phase {
        case .typing:  Color.primary.opacity(0.06)
        case .correct: Theme.correct.opacity(0.25)
        case .missed:  Theme.wrong.opacity(0.16)   // a soft red says "not quite"
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch phase {
        case .typing:
            HStack(spacing: 8) {
                PanelButton(title: "힌트", action: hint)
                    .frame(width: 92)
                PanelButton(title: "확인", fill: Theme.spell, solid: true, action: check)
                    .disabled(typed.trimmed.isEmpty)
                    .opacity(typed.trimmed.isEmpty ? 0.5 : 1)
            }
        case .correct, .missed:
            PanelButton(
                title: "다음",
                fill: phase == .correct ? Theme.correct : Theme.spell,
                solid: true,
                action: proceed
            )
        }
    }

    // MARK: Actions

    private func check() {
        guard phase == .typing else { return }
        let ok = SpellNormalizer.matches(answer: typed, expected: session.expectedAnswer)
        withAnimation(.easeInOut(duration: 0.2)) { phase = ok ? .correct : .missed }
        // 따닥 on a hit, 따다닥 (FaceID-fail) on a miss.
        ok ? Haptics.success() : Haptics.intenseError()

        reveal()

        // A hit moves on by itself; a miss waits for 다음, so the learner decides
        // how long to sit with the word they just got wrong.
        if ok { autoProceed() }
    }

    private func hint() {
        usedHint = true
        withAnimation(.easeInOut(duration: 0.2)) { phase = .missed }
        Haptics.nudge()
        reveal()
    }

    /// Step the keyboard aside so the stage gets the full screen, and say the word.
    private func reveal() {
        fieldFocused = false
        if autoSpeak { Speaker.shared.speak(currentTerm) }
    }

    private func proceed() {
        if phase == .correct && !usedHint {
            session.submitSpelling(typed)
        } else {
            // A miss or a hint — the card comes back around later.
            session.revealAsHint()
        }
        try? context.save()

        typed = ""
        usedHint = false
        phase = .typing
        session.advance()
        fieldFocused = true
        persistProgress()
    }

    /// Save the round after every answer; clear it once the round is finished.
    private func persistProgress() {
        if session.isFinished {
            StudyProgressStore.clear(progressKey)
        } else {
            StudyProgressStore.save(session.savedState, key: progressKey)
        }
    }

    private func restart() {
        StudyProgressStore.clear(progressKey)
        session = StudySession(cards: session.snapshotCards, mode: .spell,
                               direction: session.direction, shuffle: session.shuffle)
        typed = ""
        phase = .typing
        usedHint = false
        fieldFocused = true
    }

    /// Move on by itself after a hit. Held while the look-back is open, so closing it
    /// returns the learner to the card they answered rather than the one after it.
    private func autoProceed() {
        Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard phase == .correct, peekIndex == nil else { return }
            proceed()
        }
    }

    /// Open the look-back on the most recent card. The keyboard steps aside so the
    /// card has the screen, and comes back when the look-back closes.
    private func openPeek() {
        guard !session.history.isEmpty else { return }
        fieldFocused = false
        withAnimation(.easeInOut(duration: 0.2)) { peekIndex = session.history.count - 1 }
    }

    /// Hold the audio session for as long as this screen is up — see `Speaker.hold()`.
    private func takeAudio() {
        guard !holding else { return }
        holding = true
        Speaker.shared.hold()
    }

    private func releaseAudio() {
        guard holding else { return }
        holding = false
        Speaker.shared.release()
    }

    private func close() { dismiss() }
}
