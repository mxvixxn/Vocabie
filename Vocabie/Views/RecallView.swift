import SwiftUI

/// 리콜 (Recall): pick the correct answer from four choices.
///
/// On a miss the tapped choice turns red and the correct one still lights green, so the
/// learner sees both. The missed card slides to the back of the queue and comes around again.
struct RecallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var context

    @State var session: StudySession
    /// Key under which this round's progress is saved, so leaving mid-way resumes.
    let progressKey: String
    /// What to offer at the finish line, when more material follows this round.
    var nextTitle: String? = nil
    var onNext: (() -> Void)? = nil
    /// The option the learner answered with, held while feedback shows.
    @State private var selected: String?
    /// The row currently under the finger, before it lifts.
    @State private var pressed: String?
    /// Where each option sits, so a lift can be matched to a row.
    @State private var optionFrames: [String: CGRect] = [:]
    private let optionSpace = "recallOptions"

    private var locked: Bool { selected != nil }
    private var wasCorrect: Bool { selected == session.expectedAnswer }

    @AppStorage("autoSpeak") private var autoSpeak = true

    var body: some View {
        ZStack {
            Theme.background(scheme).ignoresSafeArea()

            if session.isFinished {
                StudyCompleteView(mode: .recall, total: session.total,
                                  nextTitle: nextTitle, onNext: onNext,
                                  onRestart: restart, onClose: close)
            } else {
                StudyScaffold(
                    mode: .recall,
                    cleared: session.clearedCount,
                    total: session.total,
                    progress: session.progress,
                    onClose: close
                ) {
                    if locked {
                        AnswerReveal(
                            kicker: wasCorrect ? "정답!" : "정답은",
                            tint: wasCorrect ? Theme.correct : Theme.wrong,
                            term: session.current?.term ?? "",
                            meaning: session.current?.meaning ?? "",
                            note: session.promptNote,
                            accent: Theme.recall
                        )
                    } else {
                        WordStage(
                            kicker: session.direction == .termToMeaning
                                ? "알맞은 뜻을 고르세요" : "알맞은 단어를 고르세요",
                            word: session.prompt,
                            accent: Theme.recall,
                            size: 36
                        )
                    }
                } panel: {
                    FloatingPanel(tint: Theme.recall) {
                        options
                        // A hit moves on by itself. A miss waits, so the learner decides
                        // how long to sit with the word they just got wrong.
                        if locked && !wasCorrect {
                            PanelButton(title: "다음", fill: Theme.recall,
                                        solid: true, action: proceed)
                        }
                    }
                }
            }
        }
        .onDisappear { Speaker.shared.stop() }
    }

    /// The four choices, answered on lift rather than on touch.
    ///
    /// A finger that lands on the wrong row can slide to the right one and let go
    /// there — the answer is whatever is under the finger at the end, the way a
    /// keyboard key or a picker behaves. Committing on touch-down meant a misplaced
    /// thumb was already a miss, with no way to take it back.
    private var options: some View {
        VStack(spacing: 8) {
            ForEach(session.options, id: \.self) { option in
                optionRow(option)
            }
        }
        .coordinateSpace(.named(optionSpace))
        .onPreferenceChange(OptionFramesKey.self) { optionFrames = $0 }
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named(optionSpace))
                .onChanged { value in
                    guard !locked else { return }
                    let over = option(at: value.location)
                    // Tick as the finger crosses into a new row, like a picker.
                    if over != pressed, over != nil { Haptics.selection() }
                    pressed = over
                }
                .onEnded { value in
                    guard !locked else { return }
                    let landed = option(at: value.location)
                    pressed = nil
                    if let landed { choose(landed) }
                }
        )
        // Not `.disabled` — that greys out the rows, washing the green and red
        // feedback into pastel just when it matters most. The gesture already guards.
        .allowsHitTesting(true)
    }

    private func optionRow(_ option: String) -> some View {
        PanelRow(fill: fill(for: option), foreground: foreground(for: option)) {
            Text(option)
                .font(.callout.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.leading)
        }
        .scaleEffect(pressed == option && !locked ? 0.97 : 1)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: OptionFramesKey.self,
                    value: [option: geo.frame(in: .named(optionSpace))]
                )
            }
        )
        .animation(.easeInOut(duration: 0.22), value: selected)
        .animation(.easeOut(duration: 0.12), value: pressed)
    }

    /// Which row sits under a point in the options stack, if any.
    private func option(at point: CGPoint) -> String? {
        optionFrames.first { $0.value.contains(point) }?.key
    }

    // MARK: Feedback

    private func fill(for option: String) -> Color? {
        guard let selected else {
            // Before an answer lands, the row under the finger lights up so the
            // learner can see what letting go would pick.
            return pressed == option ? Theme.recall.opacity(0.16) : nil
        }
        if option == session.expectedAnswer { return Theme.correctFill }
        // The wrong choice the learner actually tapped turns red.
        if option == selected { return Theme.wrongFill }
        return Color.primary.opacity(0.03)
    }

    private func foreground(for option: String) -> Color? {
        guard let selected else { return nil }
        if option == session.expectedAnswer { return .white }
        if option == selected { return .white }
        return .secondary
    }

    // MARK: Actions

    private func choose(_ option: String) {
        guard !locked else { return }
        let isCorrect = option == session.expectedAnswer
        withAnimation(.easeInOut(duration: 0.22)) { selected = option }
        // 따닥 on a hit, 따다닥 (FaceID-fail) on a miss.
        isCorrect ? Haptics.success() : Haptics.intenseError()
        if autoSpeak, let term = session.current?.term {
            Speaker.shared.speak(term)
        }

        guard isCorrect else { return }   // a miss waits for 다음
        // Long enough for the utterance to land before the next card.
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if selected != nil { proceed() }
        }
    }

    private func proceed() {
        guard let choice = selected else { return }
        session.submitChoice(choice)
        try? context.save()
        selected = nil
        session.advance()
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
        session = StudySession(cards: session.snapshotCards, mode: .recall,
                               direction: session.direction, shuffle: session.shuffle)
        selected = nil
    }

    private func close() { dismiss() }
}

/// Where each option row sits inside the options stack, keyed by its text.
private struct OptionFramesKey: PreferenceKey {
    static var defaultValue: [String: CGRect] { [:] }

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
