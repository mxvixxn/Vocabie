import SwiftUI

/// 리콜 (Recall): pick the correct answer from four choices.
///
/// Missing is not punished — there is no ✗ and no red. The right answer simply lights up,
/// the card slides to the back of the queue, and it comes around again later.
struct RecallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var context

    @State var session: StudySession
    /// The option the learner tapped, held while feedback shows.
    @State private var selected: String?
    private var locked: Bool { selected != nil }

    var body: some View {
        ZStack {
            Theme.background(scheme).ignoresSafeArea()

            if session.isFinished {
                StudyCompleteView(mode: .recall, total: session.total,
                                  onRestart: restart, onClose: close)
            } else {
                StudyScaffold(
                    mode: .recall,
                    cleared: session.clearedCount,
                    total: session.total,
                    progress: session.progress,
                    onClose: close
                ) {
                    WordStage(
                        kicker: session.direction == .termToMeaning
                            ? "알맞은 뜻을 고르세요" : "알맞은 단어를 고르세요",
                        word: session.prompt,
                        accent: Theme.recall,
                        size: 36
                    )
                } panel: {
                    FloatingPanel(tint: Theme.recall) {
                        ForEach(session.options, id: \.self) { option in
                            optionRow(option)
                        }
                    }
                }
            }
        }
    }

    private func optionRow(_ option: String) -> some View {
        Button {
            choose(option)
        } label: {
            PanelRow(fill: fill(for: option), foreground: foreground(for: option)) {
                Text(option)
                    .font(.callout.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.leading)
            }
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .animation(.easeInOut(duration: 0.22), value: selected)
    }

    // MARK: Feedback

    private func fill(for option: String) -> Color? {
        guard selected != nil else { return nil }
        if option == session.expectedAnswer { return Theme.correct.opacity(0.9) }
        // The miss just fades back rather than turning red.
        return Color.primary.opacity(0.03)
    }

    private func foreground(for option: String) -> Color? {
        guard selected != nil else { return nil }
        if option == session.expectedAnswer { return .white }
        return .secondary
    }

    // MARK: Actions

    private func choose(_ option: String) {
        guard !locked else { return }
        let isCorrect = option == session.expectedAnswer
        selected = option
        isCorrect ? Haptics.success() : Haptics.nudge()

        // Hold the highlight so the answer registers, then let the session move on.
        let delay: UInt64 = isCorrect ? 450_000_000 : 950_000_000
        Task {
            try? await Task.sleep(nanoseconds: delay)
            session.submitChoice(option)
            try? context.save()
            selected = nil
            session.advance()
        }
    }

    private func restart() {
        session = StudySession(cards: session.snapshotCards, mode: .recall, direction: session.direction)
    }

    private func close() { dismiss() }
}
