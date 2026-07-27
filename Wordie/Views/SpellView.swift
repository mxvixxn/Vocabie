import SwiftUI

/// 스펠 (Spell): type the word from its meaning. Grading is lenient (case/space/punctuation
/// insensitive). A hint reveals the answer but counts the card as missed, so it returns later.
struct SpellView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var context
    @FocusState private var fieldFocused: Bool

    @State var session: StudySession
    @State private var typed = ""
    @State private var phase: Phase = .typing
    @State private var usedHint = false

    private enum Phase { case typing, correct, wrong }

    var body: some View {
        ZStack {
            Theme.background(scheme).ignoresSafeArea()

            if session.isFinished {
                StudyCompleteView(
                    mode: .spell,
                    total: session.total,
                    onRestart: restart,
                    onClose: close
                )
            } else {
                VStack(spacing: 0) {
                    StudyTopBar(
                        title: "스펠 \(session.clearedCount)/\(session.total)",
                        progress: session.progress,
                        accent: Theme.spell,
                        onClose: close
                    )
                    Spacer()
                    promptCard
                    inputArea
                    Spacer()
                    actionButton
                }
            }
        }
        .onAppear { fieldFocused = true }
    }

    private var promptCard: some View {
        VStack(spacing: 10) {
            Text(session.direction == .meaningToTerm ? "뜻을 보고 단어를 입력하세요" : "단어를 보고 뜻을 입력하세요")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.spell)
            Text(session.prompt)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
            if !session.promptNote.isEmpty && phase == .typing {
                Text(session.promptNote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 170)
        .cardSurface(padding: 24)
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var inputArea: some View {
        VStack(spacing: 12) {
            TextField("정답 입력", text: $typed)
                .focused($fieldFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)
                .padding(.vertical, 14)
                .background(fieldBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .disabled(phase != .typing)
                .onSubmit { if phase == .typing { check() } }

            if phase == .wrong {
                VStack(spacing: 4) {
                    Text("정답")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(session.expectedAnswer)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.spell)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .animation(.easeInOut(duration: 0.2), value: phase)
    }

    private var fieldBackground: some ShapeStyle {
        switch phase {
        case .typing:  return AnyShapeStyle(.ultraThinMaterial)
        case .correct: return AnyShapeStyle(Theme.correct.opacity(0.25))
        case .wrong:   return AnyShapeStyle(Color.orange.opacity(0.2))
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch phase {
        case .typing:
            HStack(spacing: 12) {
                Button(action: hint) {
                    Text("힌트")
                        .font(.headline)
                        .frame(width: 90)
                        .padding(.vertical, 16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                Button(action: check) {
                    Text("확인")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.spell, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.white)
                }
                .disabled(typed.trimmed.isEmpty)
                .opacity(typed.trimmed.isEmpty ? 0.5 : 1)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        case .correct, .wrong:
            Button(action: proceed) {
                Text("다음")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background((phase == .correct ? Theme.correct : Theme.spell),
                               in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: Actions

    private func check() {
        guard phase == .typing else { return }
        let ok = SpellNormalizer.matches(answer: typed, expected: session.expectedAnswer)
        phase = ok ? .correct : .wrong
        ok ? Haptics.success() : Haptics.rigid()
        if ok {
            Task {
                try? await Task.sleep(nanoseconds: 550_000_000)
                if phase == .correct { proceed() }
            }
        }
    }

    private func hint() {
        usedHint = true
        phase = .wrong
        Haptics.rigid()
    }

    private func proceed() {
        if phase == .correct && !usedHint {
            session.submitSpelling(typed)
        } else {
            // Wrong answer or hint used — counts as missed, card returns later.
            session.revealAsHint()
        }
        try? context.save()
        typed = ""
        usedHint = false
        phase = .typing
        session.advance()
        fieldFocused = true
    }

    private func restart() {
        session = StudySession(cards: session.snapshotCards, mode: .spell, direction: session.direction)
        typed = ""
        phase = .typing
        usedHint = false
        fieldFocused = true
    }

    private func close() { dismiss() }
}
