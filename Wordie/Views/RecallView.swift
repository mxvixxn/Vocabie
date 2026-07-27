import SwiftUI

/// 리콜 (Recall): pick the correct answer from four choices.
/// Wrong picks aren't punished harshly — the card simply comes back later.
struct RecallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var context

    @State var session: StudySession
    /// The option the user tapped, held briefly to show feedback.
    @State private var selected: String?
    private var locked: Bool { selected != nil }

    var body: some View {
        ZStack {
            Theme.background(scheme).ignoresSafeArea()

            if session.isFinished {
                StudyCompleteView(
                    mode: .recall,
                    total: session.total,
                    onRestart: restart,
                    onClose: close
                )
            } else {
                VStack(spacing: 0) {
                    StudyTopBar(
                        title: "리콜 \(session.clearedCount)/\(session.total)",
                        progress: session.progress,
                        accent: Theme.recall,
                        onClose: close
                    )
                    Spacer()
                    promptCard
                    Spacer()
                    options
                }
            }
        }
    }

    private var promptCard: some View {
        VStack(spacing: 10) {
            Text(session.direction == .termToMeaning ? "알맞은 뜻을 고르세요" : "알맞은 단어를 고르세요")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.recall)
            Text(session.prompt)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .cardSurface(padding: 26)
        .padding(.horizontal, 24)
    }

    private var options: some View {
        VStack(spacing: 12) {
            ForEach(session.options, id: \.self) { option in
                Button {
                    choose(option)
                } label: {
                    Text(option)
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 18)
                        .background(background(for: option), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(foreground(for: option))
                }
                .disabled(locked)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 30)
        .animation(.easeInOut(duration: 0.2), value: selected)
    }

    // MARK: Feedback colours

    private func background(for option: String) -> some ShapeStyle {
        guard let selected else { return AnyShapeStyle(.ultraThinMaterial) }
        if option == session.expectedAnswer {
            return AnyShapeStyle(Theme.correct.opacity(0.85))
        }
        if option == selected {
            return AnyShapeStyle(Color.orange.opacity(0.7))
        }
        return AnyShapeStyle(Color.secondary.opacity(0.12))
    }

    private func foreground(for option: String) -> Color {
        guard let selected else { return .primary }
        if option == session.expectedAnswer || option == selected { return .white }
        return .secondary
    }

    // MARK: Actions

    private func choose(_ option: String) {
        guard !locked else { return }
        let isCorrect = option == session.expectedAnswer
        selected = option
        isCorrect ? Haptics.success() : Haptics.rigid()
        // Brief pause so the learner sees the correct answer highlighted before
        // the session mutates the queue and moves on.
        let delay: UInt64 = isCorrect ? 450_000_000 : 900_000_000
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
