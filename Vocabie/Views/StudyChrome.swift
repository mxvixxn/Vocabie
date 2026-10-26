import SwiftUI

/// Layout shared by 암기 / 리콜 / 스펠.
///
/// Three bands, and the middle one is deliberately empty of material:
/// 1. a floating glass pill (close · progress · count)
/// 2. the stage — the word, sitting directly on the background
/// 3. a floating glass panel holding whatever the learner touches
///
/// Both glass objects live inside one `GlassEffectContainer` so iOS can blend and
/// morph them together when their contents change.
struct StudyScaffold<Stage: View, Panel: View>: View {
    let mode: StudyMode
    let cleared: Int
    let total: Int
    let progress: Double
    /// Spell shrinks the pill once the keyboard is up to buy back vertical space.
    var compactPill: Bool = false
    let onClose: () -> Void

    @ViewBuilder var stage: Stage
    @ViewBuilder var panel: Panel

    var body: some View {
        GlassEffectContainer(spacing: 20) {
            VStack(spacing: 0) {
                StudyTopPill(
                    cleared: cleared,
                    total: total,
                    progress: progress,
                    accent: mode.color,
                    compact: compactPill,
                    onClose: onClose
                )

                stage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                panel
            }
        }
    }
}

/// The floating pill: close button, progress track, position count.
///
/// `cleared` is the *position* of the card on screen, counting from 1 — not the number
/// finished. A learner reads "3/10" as "I'm on the third word", and a pass that ended
/// on 9/10 felt like it stopped one short. The bar beside it still tracks work done,
/// so it stays empty at the first card and only fills as words are cleared.
struct StudyTopPill: View {
    let cleared: Int
    let total: Int
    let progress: Double
    let accent: Color
    var compact: Bool = false
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: compact ? 10 : 12) {
            Button {
                Haptics.soft()
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: compact ? 12 : 13, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)

            ProgressView(value: progress)
                .tint(accent)
                .animation(.easeInOut(duration: 0.35), value: progress)

            Text("\(cleared)/\(total)")
                .font(.system(size: compact ? 12 : 13, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, compact ? 7 : 10)
        .glassCapsule(tint: accent)
        .padding(.horizontal, Theme.floatInset)
        .padding(.top, compact ? 4 : 8)
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: compact)
    }
}

/// The floating glass tray at the bottom. Everything tappable goes in here.
struct FloatingPanel<Content: View>: View {
    var tint: Color?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 8) {
            content
        }
        .padding(8)
        .glassPanel(tint: tint)
        .padding(.horizontal, Theme.floatInset)
        .padding(.bottom, 10)
    }
}

/// A row inside the floating panel. Translucent rather than glassy — glass inside
/// glass reads as mud.
struct PanelRow<Content: View>: View {
    var fill: Color?
    var foreground: Color?
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.innerCorner, style: .continuous)
                    .fill(fill ?? Color.primary.opacity(0.06))
            )
            .foregroundStyle(foreground ?? .primary)
    }
}

/// A tappable button styled for the floating panel.
struct PanelButton: View {
    let title: String
    var systemImage: String?
    var fill: Color?
    var solid: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                }
                if !title.isEmpty {
                    Text(title).font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.innerCorner, style: .continuous)
                    .fill(fill ?? Color.primary.opacity(0.06))
            )
            .foregroundStyle(solid ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stage

/// The quiet middle band: the prompt word with no material behind it.
struct WordStage: View {
    let kicker: String
    let word: String
    var note: String = ""
    let accent: Color
    /// Hidden when space is tight (spell, keyboard up).
    var showsChrome: Bool = true
    var size: CGFloat = 38
    /// Draws a hint of a card stack behind the word so 암기 still reads as flippable.
    var stacked: Bool = false
    /// The term to pronounce. `nil` hides the speaker button.
    var speaks: String?
    /// Which voice reads it. A plain string, not the set — the study views hand
    /// down values rather than model objects so a drag frame stays cheap.
    var speaksVoice: String = StudyLanguage.english.voiceCode

    var body: some View {
        ZStack {
            if stacked { stackHint }

            VStack(spacing: 10) {
                if showsChrome {
                    Text(kicker)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                        .transition(.opacity)
                }

                Text(word)
                    .font(.system(size: size, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.45)
                    .lineLimit(3)

                if let speaks, !speaks.trimmed.isEmpty {
                    SpeakButton(text: speaks, accent: accent, voice: speaksVoice)
                }

                if showsChrome && !note.isEmpty {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 26)
        }
        .animation(.easeInOut(duration: 0.2), value: showsChrome)
    }

    /// Two faint cards peeking out behind the word.
    private var stackHint: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.primary.opacity(0.04))
                .frame(width: 210, height: 150)
                .offset(y: 26)
                .scaleEffect(0.88)
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.primary.opacity(0.05))
                .frame(width: 240, height: 170)
                .offset(y: 14)
                .scaleEffect(0.94)
        }
        .allowsHitTesting(false)
    }
}

/// The beat after an answer in 리콜 / 스펠: the meaning lands large with the English
/// term and its pronunciation underneath.
///
/// Both modes only ever show one half of the pair while the question is open. This is
/// where the other half arrives — and a miss needs it more than a hit, so the two land
/// on the same screen with only the kicker telling them apart.
struct AnswerReveal: View {
    let kicker: String
    /// Green for a hit, red for a miss — the kicker alone carries the verdict.
    let tint: Color
    let term: String
    let meaning: String
    var note: String = ""
    /// The mode's colour, for the term line and its speaker.
    let accent: Color
    var voice: String = StudyLanguage.english.voiceCode

    var body: some View {
        VStack(spacing: 10) {
            Text(kicker)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)

            Text(meaning)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.45)
                .lineLimit(3)

            HStack(spacing: 4) {
                Text(term)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                SpeakButton(text: term, accent: accent, voice: voice)
            }

            if !note.isEmpty {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 26)
        .transition(.opacity)
    }
}

/// Small inline button that pronounces a word, like the speaker in Translate.
struct SpeakButton: View {
    let text: String
    let accent: Color
    /// BCP-47 tag of the voice — a card is read in its own set's language.
    var voice: String = StudyLanguage.english.voiceCode

    // Read directly — @Observable tracks the property access inside `body`.
    private var speaker: Speaker { Speaker.shared }

    var body: some View {
        Button {
            Haptics.soft()
            speaker.speak(text, language: voice)
        } label: {
            Image(systemName: speaker.isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(accent)
                .symbolEffect(.variableColor.iterative, isActive: speaker.isSpeaking)
                .frame(width: 42, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("발음 듣기")
    }
}

// MARK: - Completion

/// Shown when a session clears every card.
///
/// When there is more of the same material waiting — the next 묶음, or the next 세트
/// on the same 단어장 — the offer to keep going is the primary button. Momentum at the
/// finish line is the whole point: the learner is already here, already warmed up.
struct StudyCompleteView: View {
    let mode: StudyMode
    let total: Int
    /// What comes next, e.g. "묶음 3 · 21–30" or "36-40". `nil` when nothing follows,
    /// or when the learner has asked not to be offered it.
    var nextTitle: String? = nil
    var onNext: (() -> Void)? = nil
    let onRestart: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 68))
                .foregroundStyle(mode.color.gradient)
                .symbolEffect(.bounce, options: .nonRepeating)
                .padding(.bottom, 20)
            Text("\(mode.korean) 학습 완료!")
                .font(.title2.weight(.bold))
            Text("\(total)개 단어를 모두 맞혔어요 🎉")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            if let nextTitle {
                Text("다음: \(nextTitle)")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(mode.color)
                    .padding(.top, 14)
            }
            Spacer()

            FloatingPanel(tint: mode.color) {
                if let nextTitle, let onNext {
                    PanelButton(title: "‘\(nextTitle)’ 이어서", systemImage: "arrow.right",
                                fill: mode.color, solid: true, action: onNext)
                    PanelButton(title: "한 번 더", systemImage: "arrow.clockwise",
                                action: onRestart)
                } else {
                    PanelButton(title: "한 번 더", systemImage: "arrow.clockwise",
                                fill: mode.color, solid: true, action: onRestart)
                }
                PanelButton(title: "끝내기", action: onClose)
            }
        }
    }
}

// MARK: - Looking back

/// Swipe-left-to-look-back, for the modes that don't have 암기's card deck.
///
/// 리콜 / 스펠 answer one card at a time and drop it — the word that just went by is
/// gone, which is exactly when a learner wants another look at it. This adds the same
/// affordance the deck has, as a gesture on the stage rather than a button, so nothing
/// new sits on screen while the question is open.
extension View {
    func backSwipe(enabled: Bool, action: @escaping () -> Void) -> some View {
        contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        guard enabled,
                              value.translation.width < -60,
                              abs(value.translation.height) < 90 else { return }
                        Haptics.soft()
                        action()
                    }
            )
    }
}

/// The look-back sheet itself: the cards already answered, newest first.
///
/// Read-only on purpose. Re-answering a card from here would have to unpick the tallies,
/// the streaks and the queue position it already earned; the learner asked to *see* the
/// previous word, not to redo it.
struct HistoryPeek: View {
    /// Answered cards, oldest → newest.
    let cards: [Vocab]
    /// Which one is on screen; `nil` while closed.
    @Binding var index: Int?
    let accent: Color

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if let i = index, cards.indices.contains(i) {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .onTapGesture { close() }

                VStack(spacing: 0) {
                    header(i)
                    Spacer()
                    card(cards[i])
                        .id(cards[i].id)
                        .transition(.opacity)
                    Spacer()
                    footer(i)
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 1.03)))
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        let dx = value.translation.width
                        guard abs(dx) > 50 else { return }
                        dx < 0 ? older() : newer()
                    }
            )
        }
    }

    private func header(_ i: Int) -> some View {
        HStack {
            Text(stepLabel(i))
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent)
            Spacer()
            Button {
                Haptics.soft()
                close()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("닫기")
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    private func card(_ word: Vocab) -> some View {
        VStack(spacing: 12) {
            Text("이전 단어")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(word.term)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.45)
                .lineLimit(3)
            SpeakButton(text: word.term, accent: accent, voice: word.voiceCode)
            Text(word.meaning)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .lineLimit(3)
            if !word.note.isEmpty {
                Text(word.note)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 26)
    }

    private func footer(_ i: Int) -> some View {
        HStack(spacing: 10) {
            PanelButton(title: "더 이전", systemImage: "chevron.left", action: older)
                .disabled(i == 0)
                .opacity(i == 0 ? 0.4 : 1)
            PanelButton(title: i == cards.count - 1 ? "돌아가기" : "다음",
                        systemImage: "chevron.right",
                        fill: accent, solid: true, action: newer)
        }
        .padding(.horizontal, Theme.floatInset)
        .padding(.bottom, 16)
    }

    /// "바로 전 단어" for the newest, then how many steps back it sits.
    private func stepLabel(_ i: Int) -> String {
        let back = cards.count - i
        return back <= 1 ? "바로 전 단어" : "\(back)번째 전 단어"
    }

    private func older() {
        guard let i = index, i > 0 else { return }
        Haptics.selection()
        withAnimation(.easeInOut(duration: 0.2)) { index = i - 1 }
    }

    /// Stepping forward past the newest card returns to the question.
    private func newer() {
        guard let i = index else { return }
        Haptics.selection()
        withAnimation(.easeInOut(duration: 0.2)) {
            index = i + 1 < cards.count ? i + 1 : nil
        }
    }

    private func close() {
        withAnimation(.easeInOut(duration: 0.2)) { index = nil }
    }
}
