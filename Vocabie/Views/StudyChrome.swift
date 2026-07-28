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

/// The floating pill: close button, progress track, cleared count.
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
    /// English text to pronounce. `nil` hides the speaker button.
    var speaks: String?

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
                    SpeakButton(text: speaks, accent: accent)
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

/// Small inline button that pronounces a word, like the speaker in Translate.
struct SpeakButton: View {
    let text: String
    let accent: Color

    // Read directly — @Observable tracks the property access inside `body`.
    private var speaker: Speaker { Speaker.shared }

    var body: some View {
        Button {
            Haptics.soft()
            speaker.speak(text)
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
struct StudyCompleteView: View {
    let mode: StudyMode
    let total: Int
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
            Spacer()

            FloatingPanel(tint: mode.color) {
                PanelButton(title: "한 번 더", systemImage: "arrow.clockwise",
                            fill: mode.color, solid: true, action: onRestart)
                PanelButton(title: "끝내기", action: onClose)
            }
        }
    }
}
